# Report z experimentu: u200_s20_d1m

**Dátum:** 2026-04-14 16:42:04
**Konfigurácia:** u200, s20, d1m
**Metodika:** Automatizovaný Headless test pomocou Python orchestrátora.

## Súhrnné výsledky

| Metrika | S Cache (Varnish:8080) | Bez Cache (Nginx:8081) | Zlepšenie |
| :--- | :--- | :--- | :--- |
| **Priepustnosť (RPS)** | **72.09** | 54.20 | **1.3x vyššia** |
| **Priemerná odozva** | **25.87 ms** | 835.41 ms | **32.3x rýchlejšia** |

## Vizualizácia dát

### Porovnanie priepustnosti (RPS)
![RPS Comparison](comparison_rps_u200_s20_d1m.png)

### Porovnanie odozvy (Latency)
![Latency Comparison](comparison_latency_u200_s20_d1m.png)
