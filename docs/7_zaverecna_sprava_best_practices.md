# Záverečná správa a Best Practices pre nasadenie Cache

Tento dokument slúži ako finálny výstup projektu zameraného na zvýšenie odolnosti e-shopu (WordPress/WooCommerce) voči DDoS útokom a extrémnemu preťaženiu pomocou caching vrstiev.

## 1. Komparatívna analýza cache riešení

Na základe teoretickej analýzy a praktických testov sme zhodnotili nasledujúce technológie:

*   **Varnish Cache (Víťaz pre Full-Page Cache):** Extrémne rýchly reverzný proxy server. Jeho najväčšou výhodou je jazyk VCL, ktorý umožňuje absolútnu kontrolu nad tým, čo sa cachuje (odstraňovanie marketingových cookies, ignorovanie košíka). Poskytuje najvyššiu priepustnosť a najlepšie chráni aplikačný server pred statickým DDoS útokom.
*   **Nginx FastCGI Cache:** Dobrá a jednoduchá alternatíva integrovaná priamo v Nginxe. Nevýhodou je nižšia flexibilita pri zložitých e-shopových pravidlách v porovnaní s Varnish VCL.
*   **Redis (Víťaz pre Object/Database Cache):** In-memory key-value store, ideálny pre ukladanie výsledkov databázových dopytov (Object Cache). Redukuje záťaž na databázu pri dynamických požiadavkách (napríklad keď používateľ pridáva tovar do košíka a obchádza Varnish).
*   **Memcached:** Staršia alternatíva k Redisu. Redis bol uprednostnený kvôli podpore trvalého uloženia na disk a lepším dátovým štruktúram, ktoré WordPress pluginy využívajú efektívnejšie.

## 2. Identifikované úzke hrdlá (Bottlenecks) a Limitácie

Záťažové testy (Locust, Apache Benchmark, wrk) odhalili nasledujúce limity architektúry:

1.  **Aplikačná vrstva (PHP-FPM Limit):** Najvýraznejšie úzke hrdlo. Pri limitácii na 25 workerov systém bez cache skolaboval už pri 80-100 požiadavkách za sekundu. PHP procesy sú náročné na pamäť a CPU.
2.  **Dynamický obsah (Neriešiteľný problém pre Varnish):** Operácie ako `/?add-to-cart=1` alebo `/checkout/` **nesmú** byť cachované z dôvodu ochrany osobných údajov. Varnish pri nich prepúšťa prevádzku na backend.
3.  **Sieťová a stavová vrstva:** Pri zapnutom Varnish cache systém bez problémov obslúžil 500+ požiadaviek za sekundu (RPS) so stabilnou latenciou pod 300 ms, čím sa úzke hrdlo presunulo z PHP procesora na maximálnu sieťovú priepustnosť Docker bridge siete a Nginxu.

## 3. Zhodnotenie prínosu

Implementácia architektúry Varnish + Redis priniesla **viac ako 7-násobné zvýšenie priepustnosti** pri statickom a pseudo-statickom prezeraní katalógu. Odozva systému (P95 latencia) klesla z kritických 4500 ms na menej ako 300 ms. Zabezpečenie na úrovni Nginx (Rate Limiting) poskytuje dodatočnú vrstvu ochrany pre dynamické požiadavky, ktoré Varnish nemôže cachovať.

---

## 4. Best Practices Checklist: Manuál pre administrátorov

Pri nasadzovaní cache riešení pre e-commerce aplikácie odporúčame striktne dodržiavať tento postup:

### A. Konfigurácia Varnish (Full-Page Cache)
- [ ] **Ochrana košíka a pokladne:** Všetky URL adresy obsahujúce `/cart`, `/checkout`, `/my-account` musia vo VCL končiť inštrukciou `return (pass);`.
- [ ] **Detekcia stavu zákazníka:** Identifikácia WooCommerce cookies (`woocommerce_items_in_cart`, `wordpress_logged_in`). Ak klient tieto cookies má, nesmie dostať odpoveď z cache.
- [ ] **Sanitizácia Cookies:** Analytické cookies (Google Analytics `_ga`, Facebook Pixel) je nutné pred spracovaním vo VCL odstrániť, inak Varnish identifikuje každú požiadavku ako unikátnu a zničí sa Cache Hit Ratio.

### B. Konfigurácia Backend a Databázy
- [ ] **Implementácia Object Cache:** Pre odľahčenie databázy od dynamických dopytov povinne nasadiť in-memory úložisko (Redis) a prepojiť ho s aplikáciou (cez plugin typu Redis Object Cache).
- [ ] **Tuning databázy:** Zvýšiť `innodb_buffer_pool_size` v MySQL/MariaDB na adekvátnu úroveň (odporúča sa 50-70% dostupnej RAM, ak je databáza na dedikovanom serveri).
- [ ] **Sledovanie úzkych hrdiel:** Zapnúť `slow_query_log` na identifikáciu neoptimalizovaných SQL dopytov počas záťaže.

### C. Ochrana a Bezpečnosť (Anti-DDoS)
- [ ] **Rate Limiting na aplikačnom serveri:** Nasadiť `limit_req_zone` v konfigurácii Nginxu pre obmedzenie počtu požiadaviek z jednej IP adresy (ochrana PHP-FPM pred vyčerpaním workerov pri Layer 7 útokoch).
- [ ] **Real-time Monitoring:** Nasadiť Prometheus exportery (pre Varnish a Redis) a monitorovať `cache_hit` a `cache_miss` v reálnom čase pomocou Grafany na skorú detekciu anomálií a útokov.
