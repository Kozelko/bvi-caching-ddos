import subprocess
import os
import csv
import datetime
import matplotlib.pyplot as plt
import re
import argparse
import time
import sys

def validate_vmem(value):
    """Overí, či je zadaná pamäť v realistickom rozsahu (128M - 2G)."""
    match = re.match(r"^(\d+)([MG])$", value.upper())
    if not match:
        raise argparse.ArgumentTypeError("Formát pamäte musí byť napr. 512M alebo 1G.")
    num, unit = int(match.group(1)), match.group(2)
    size_in_mb = num if unit == 'M' else num * 1024
    if size_in_mb < 128 or size_in_mb > 2048:
        raise argparse.ArgumentTypeError(f"Nereálna hodnota pamäte ({value}). Pre e-shop použite rozsah 128M až 2G.")
    return value.upper()

def validate_php(value):
    """Overí, či je počet PHP workerov v realistickom rozsahu (5 - 100)."""
    ivalue = int(value)
    if ivalue < 5 or ivalue > 100:
        raise argparse.ArgumentTypeError(f"Nereálny počet PHP workerov ({value}). Štandard pre produkciu je 5 až 100.")
    return ivalue

def get_container_stats(service, command):
    try:
        cmd = ["docker", "compose", "exec", "-T", service] + command.split()
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        return result.stdout.strip()
    except: return "N/A"

def get_varnish_metrics():
    output = get_container_stats("varnish", "varnishstat -1")
    hits = re.search(r"MAIN\.cache_hit\s+(\d+)", output)
    misses = re.search(r"MAIN\.cache_miss\s+(\d+)", output)
    h = int(hits.group(1)) if hits else 0
    m = int(misses.group(1)) if misses else 0
    ratio = round((h / (h + m)) * 100, 2) if (h + m) > 0 else 0
    return {"hits": h, "misses": m, "ratio": f"{ratio}%"}

def get_redis_metrics():
    output = get_container_stats("redis", "redis-cli info stats")
    hits = re.search(r"keyspace_hits:(\d+)", output)
    misses = re.search(r"keyspace_misses:(\d+)", output)
    h = int(hits.group(1)) if hits else 0
    m = int(misses.group(1)) if misses else 0
    return {"hits": h, "misses": m}

def set_tuning_params(v_mem="512M", php_max=25):
    """Aktualizuje .env súbor a reštartuje kontajnery s realistickým tuningom."""
    print(f"\n[*] Aplikujem produkčný tuning: Varnish={v_mem}, PHP-FPM={php_max}...")
    with open(".env", "w") as f:
        f.write(f"VARNISH_SIZE={v_mem}\n")
        f.write(f"PHP_MAX_CHILDREN={php_max}\n")
        f.write(f"PHP_START_SERVERS={max(2, int(php_max/5))}\n")
        f.write(f"PHP_MIN_SPARE={max(1, int(php_max/10))}\n")
        f.write(f"PHP_MAX_SPARE={max(3, int(php_max/2.5))}\n")
    subprocess.run(["docker", "compose", "up", "-d"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(3)

def run_locust_test(target_url, csv_name, results_dir, duration, users, spawn_rate):
    mode = "S CACHE (Varnish)" if ":8080" in target_url else "BEZ CACHE (Nginx)"
    print(f"\n[>>>] ZAČÍNAM TEST: {mode}")
    csv_dir = os.path.join(results_dir, "csv"); os.makedirs(csv_dir, exist_ok=True)
    csv_path = os.path.join(csv_dir, csv_name)
    cmd = ["locust", "-f", "locustfile.py", "--headless", "-u", str(users), "-r", str(spawn_rate),
           "--run-time", duration, "--host", target_url, "--csv", csv_path, "--only-summary"]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return f"{csv_path}_stats.csv", f"{csv_path}_stats_history.csv"

def parse_aggregated_data(csv_file):
    if not csv_file or not os.path.exists(csv_file): return None
    try:
        with open(csv_file, mode='r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                if row["Name"] == "Aggregated":
                    return {"rps": float(row["Requests/s"]), "avg_latency": float(row["Average Response Time"]),
                            "p95": float(row["95%"]), "fails": int(row["Failure Count"])}
    except: pass
    return None

def parse_history(csv_file):
    """Vytiahne časový priebeh RPS a P95 z history CSV (robustnejšie)."""
    times, rps, p95 = [], [], []
    if not os.path.exists(csv_file): return times, rps, p95
    try:
        with open(csv_file, mode='r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            start_time = None
            for row in reader:
                if row["Name"] == "Aggregated":
                    try:
                        ts = int(row["Timestamp"])
                        curr_rps = float(row["Requests/s"]) if row["Requests/s"] else 0.0
                        curr_p95 = float(row["95%"]) if row["95%"] else 0.0
                        if start_time is None: start_time = ts
                        times.append(ts - start_time)
                        rps.append(curr_rps)
                        p95.append(curr_p95)
                    except (ValueError, KeyError): continue
    except: pass
    return times, rps, p95

def generate_line_charts(cache_hist, nocache_hist, results_dir, suffix):
    """Vykreslí čiarové grafy vývoja v čase."""
    t_c, r_c, p_c = parse_history(cache_hist)
    t_n, r_n, p_n = parse_history(nocache_hist)
    
    # RPS
    plt.figure(figsize=(10, 5))
    if t_c and r_c: plt.plot(t_c, r_c, label='S Cache', color='green')
    if t_n and r_n: plt.plot(t_n, r_n, label='Bez Cache', color='red', linestyle='--')
    plt.title(f'Priebeh RPS - {suffix}'); plt.ylabel('RPS'); plt.legend(); plt.grid(True)
    plt.savefig(os.path.join(results_dir, 'line_rps.png')); plt.close()

    # Latency
    plt.figure(figsize=(10, 5))
    if t_c and p_c: plt.plot(t_c, p_c, label='S Cache', color='green')
    if t_n and p_n: plt.plot(t_n, p_n, label='Bez Cache', color='red', linestyle='--')
    plt.title(f'Priebeh P95 Odozvy - {suffix}'); plt.ylabel('ms'); plt.yscale('log'); plt.legend(); plt.grid(True)
    plt.savefig(os.path.join(results_dir, 'line_lat.png')); plt.close()

def generate_final_report(cache_data, nocache_data, results_dir, suffix, v_metrics, r_metrics, v_mem, php_max):
    report_path = os.path.join(results_dir, f"report_{suffix}.md")
    report = f"""# Report z experimentu: {suffix}

## 1. Produkčná Konfigurácia (Realistický Tuning)
Tento experiment simuluje stredne veľký e-shop na serveri s cca 4GB RAM:
*   **Varnish Cache Memory:** {v_mem}
*   **PHP-FPM Max Workers:** {php_max}

## 2. Monitoring Infraštruktúry
*   **Varnish Hit Ratio:** {v_metrics['ratio']}
*   **Redis Keyspace Hits:** {r_metrics['hits']}

## 3. Celkové výsledky
| Metrika | S Cache (Varnish) | Bez Cache (Nginx) |
| :--- | :--- | :--- |
| **Priemerné RPS** | **{cache_data['rps']:.1f}** | {nocache_data['rps']:.1f} |
| **Max P95 Latency** | **{cache_data['p95']:.0f} ms** | {nocache_data['p95']:.0f} ms |

## 4. Grafy priebehu
![RPS Timeline](line_rps.png)
![Latency Timeline](line_lat.png)
"""
    with open(report_path, "w", encoding="utf-8") as f: f.write(report)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Automatizovaný Locust benchmark s realistickým tuningom.")
    parser.add_argument("-u", "--users", type=int, default=200)
    parser.add_argument("-r", "--rate", type=int, default=20)
    parser.add_argument("-t", "--time", type=str, default="1m")
    parser.add_argument("--vmem", type=validate_vmem, default="512M")
    parser.add_argument("--php", type=validate_php, default=25)
    parser.add_argument("-l", "--locustfile", type=str, default="locustfile.py", help="Cesta k Locust skriptu")
    parser.add_argument("--name", type=str, default="", help="Vlastný názov reportu (suffix)")
    args = parser.parse_args()

    set_tuning_params(args.vmem, args.php)
    
    suffix = args.name if args.name else f"u{args.users}_v{args.vmem}_p{args.php}"
    results_dir = os.path.join("results", suffix); os.makedirs(results_dir, exist_ok=True)

    s_c, h_c = run_locust_test("http://localhost:8080", "l_cache", results_dir, args.time, args.users, args.rate, args.locustfile)
    v_m = get_varnish_metrics(); r_m = get_redis_metrics()
    d_c = parse_aggregated_data(s_c)

    s_n, h_n = run_locust_test("http://localhost:8081", "l_nocache", results_dir, args.time, args.users, args.rate, args.locustfile)
    d_n = parse_aggregated_data(s_n)

    if d_c and d_n:
        generate_line_charts(h_c, h_n, results_dir, suffix)
        generate_final_report(d_c, d_n, results_dir, suffix, v_m, r_m, args.vmem, args.php)
        print(f"\n[!] HOTOVÉ. Výsledky: {results_dir}")
