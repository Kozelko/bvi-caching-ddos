# 1. Analýza hrozieb preťaženia systému (Task 2a)

V súlade so špecifikáciou projektu (sekcia 3.1) bola vykonaná analýza hrozieb zameraná na identifikáciu slabých miest.

## 1.1 Metodológia testovania
*   **Blackbox testovanie:** Simulácia útočníka zvonku pomocou nástrojov `ab` (Apache Benchmark) a `Locust`. Cieľom je zahltiť server HTTP požiadavkami bez znalosti vnútornej štruktúry.
*   **Whitebox testovanie:** Analýza konfigurácie Nginx a MySQL pre identifikáciu limitov (max_connections, worker_processes).

## 1.2 Identifikované hrozby (Úzke hrdlá)
Na základe architektúry (LEMP stack bez cache) boli identifikované tieto kritické miesta:

1.  **Databázová vrstva (MySQL/MariaDB):**
    *   Každá požiadavka na dynamický obsah (WordPress) generuje dotazy do DB.
    *   Pri vysokom počte konkurentných požiadaviek (DDoS) dochádza k vyčerpaniu `max_connections` a vysokému I/Owait.
    *   Pomalé JOIN operácie pri filtrovaní produktov (WooCommerce) môžu spôsobiť "stacking" požiadaviek.

2.  **Aplikačná vrstva (PHP-FPM):**
    *   PHP je interpretovaný jazyk; každá požiadavka spúšťa nový proces/vlákno.
    *   Limitovaný počet `pm.max_children` v PHP-FPM konfigurácii. Ak sa vyčerpá, Nginx vráti 502 Bad Gateway.
    *   Generovanie HTML stránky je CPU náročné.

3.  **Webserver (Nginx):**
    *   Hoci Nginx zvláda veľa konkurentných spojení (event-driven), bez cache musí každú dynamickú požiadavku poslať na PHP backend.
    *   Limity `worker_connections` môžu byť dosiahnuté pri masívnom DDoS.

4.  **Sieťová vrstva:**
    *   Saturácia šírky pásma (Bandwidth exhaustion).
    *   Vyčerpanie tabuľky spojení (state table exhaustion) na firewalle.

## 1.3 Záver
Bez nasadenia cache je systém zraniteľný aj voči malému DDoS útoku (Layer 7 HTTP Flood), pretože náklady na vygenerovanie jednej stránky (CPU/RAM) sú neúmerne vyššie ako náklady útočníka na odoslanie požiadavky.
