# 6. Finálny porovnávací report experimentu

**Dátum:** 2026-04-14 16:29:46
**Metodika:** Automatizovaný Headless test pomocou Python orchestrátora. 200 používateľov, 1 minúta behu.

## 6.1 Súhrnné výsledky

| Metrika | S Cache (Varnish:8080) | Bez Cache (Nginx:8081) | Zlepšenie |
| :--- | :--- | :--- | :--- |
| **Priepustnosť (RPS)** | **70.90** | 54.51 | **1.3x vyššia** |
| **Priemerná odozva** | **28.18 ms** | 756.01 ms | **26.8x rýchlejšia** |
| **95% Percentil (P95)** | **100 ms** | 1600 ms | - |
| **Zlyhané požiadavky** | 0 | 0 | - |

## 6.2 Vizualizácia dát

### Porovnanie priepustnosti (RPS)
![RPS Comparison](comparison_rps.png)

### Porovnanie odozvy (Latency)
![Latency Comparison](comparison_latency.png)

## 6.3 Záverečné vyhodnotenie
Experiment jasne preukázal kritický význam cache vrstvy v architektúre webovej aplikácie. 
Varnish úspešne absorbuje L7 útoky tým, že servíruje statický aj pseudo-statický obsah priamo z RAM. 
Bez cache vrstvy musí každú požiadavku spracovať PHP-FPM a MariaDB, čo pri zvýšenej záťaži vedie k rapídnemu nárastu latencie a následnému pádu servera.
