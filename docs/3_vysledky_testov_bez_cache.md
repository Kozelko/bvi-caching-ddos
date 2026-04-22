# 3. Výsledky testovania bez nasadenej cache (Task 2c)

## 3.1 Ciele testu
Cieľom bolo zmerať základný výkon (baseline) systému WordPress + WooCommerce bežiaceho v Docker kontajneri bez akejkoľvek cache vrstvy.

## 3.2 Testovacie prostredie
*   **Klient:** Python script (simulácia `ab` - Apache Benchmark)
*   **Server:** Nginx 1.24 + PHP-FPM 8.2 + MariaDB 10.11 (Docker)
*   **Sieť:** Lokálna sieť (Docker bridge network)

## 3.3 Metodika
*   Počet požiadaviek: 100
*   Súbežnosť (Concurrency): 10 vlákien
*   URL: http://localhost:8080/ (Inštalačná stránka WP / Homepage)

## 3.4 Namerané hodnoty

| Metrika | Hodnota | Poznámka |
| :--- | :--- | :--- |
| **Requests per Second (RPS)** | **9.41** | Veľmi nízka priepustnosť. |
| **Priemerná odozva (Avg Latency)** | **1014.19 ms** | Viac ako 1 sekunda na vygenerovanie stránky. |
| **95. percentil (P95)** | **1790.71 ms** | 5% používateľov čaká takmer 2 sekundy. |
| **Chybovosť** | 0% | Server zatiaľ zvláda záťaž, ale veľmi pomaly. |

## 3.5 Interpretácia výsledkov
*   **Vysoká latencia:** Priemerná odozva ~1s pre jednoduchú stránku indikuje, že PHP-FPM a databáza sú úzkym hrdlom. Každý request musí byť spracovaný PHP interpretom.
*   **Riziko DDoS:** Pri takejto nízkej priepustnosti (9 RPS) stačí veľmi malý útok (napr. 50 requestov za sekundu), aby sa server stal úplne nedostupným (Denial of Service).
*   **Záver:** Nasadenie cache je nevyhnutné. Očakávame, že s Varnish Cache sa RPS zvýši rádovo (na stovky až tisíce) a latencia klesne pod 50ms.
