# Projekt: Zvýšenie odolnosti webových aplikácií proti DDoS (BVI)

Tento adresár obsahuje výstupy pre "Prípravnú fázu" a "Analytickú fázu" projektu podľa zadania.

## 1. Prípravná fáza - Inštalácia prostredia
Prostredie je pripravené pomocou Docker Compose.
*   **Súbory:** `docker-compose.yml`, `nginx.conf`
*   **Spustenie:** `docker compose up -d`
*   **Prístup:** Web beží na `http://localhost:8080`

## 2. Analytická fáza - Dokumentácia
Výstupy analýz a testov sa nachádzajú v zložke `docs/`:
1.  [Analýza hrozieb a úzkych hrdiel](docs/1_analyza_hrozieb.md)
2.  [Komparatívna analýza cache riešení](docs/2_analyza_cache_rieseni.md)
3.  [Výsledky testovania bez cache (Baseline)](docs/3_vysledky_testov_bez_cache.md)

## Ako pokračovať
Pre ďalšie fázy projektu (Implementácia cache) bude potrebné upraviť `docker-compose.yml` a pridať služby `varnish` a `redis`.
