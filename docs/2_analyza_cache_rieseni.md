# 2. Komparatívna analýza cache riešení (Task 2b)

Na základe sekcie 3.4 špecifikácie boli analyzované dostupné cache technológie pre zvolený stack (WordPress + WooCommerce).

| Riešenie | Typ | Výhody | Nevýhody | Vhodnosť pre projekt |
| :--- | :--- | :--- | :--- | :--- |
| **Varnish Cache** | HTTP Reverse Proxy Cache | - Extrémne rýchly (ukladá skompilované stránky do RAM).<br>- Flexibilná konfigurácia cez VCL (Varnish Configuration Language).<br>- Efektívna ochrana pred DDoS (request coalescing). | - Nepodporuje SSL/TLS natívne (vyžaduje SSL termináciu pred ním, napr. Nginx).<br>- Zložitejšia konfigurácia invalidácie pre dynamický obsah (košík, login). | **Vysoká** (Primárna voľba pre Full Page Cache). |
| **Redis** | In-memory Key-Value Store | - Ideálny pre **Object Cache** (výsledky DB dotazov).<br>- Podpora perzistencie dát.<br>- Ľahká integrácia s WP cez plugin. | - Nie je určený ako full-page cache pre neprihlásených (hoci to dokáže, Varnish je špecializovanejší).<br>- Limitovaný veľkosťou RAM. | **Vysoká** (Pre Object Cache a Session storage). |
| **Nginx FastCGI Cache** | Webserver Native Cache | - Jednoduché nasadenie (priamo v Nginx configu).<br>- Nevyžaduje ďalšiu službu.<br>- Dobrý výkon. | - Menej flexibilná invalidácia (PURGE) oproti Varnish.<br>- Chýba pokročilá logika (VCL) pre zložité podmienky cachovania. | **Stredná** (Alternatíva, ak by Varnish bol príliš zložitý). |
| **Memcached** | Distributed Memory Object Caching | - Veľmi jednoduchý, rýchly multithreaded systém.<br>- Osvedčený pre jednoduché key-value ukladanie. | - Nemá pokročilé dátové typy ako Redis.<br>- Žiadna perzistencia (po reštarte je cache prázdna).<br>- Redis ho v moderných stackoch často nahrádza. | **Nízka** (Redis ponúka viac funkcií pri rovnakej rýchlosti). |
| **CDN (Cloudflare, Fastly)** | Content Delivery Network | - Filtruje zlý traffic ešte pred tým, než dorazí na server.<br>- Cachuje statiku po celom svete na edge serveroch. | - Neochráni backend, ak útočník zistí priamu IP adresu servera (tzv. origin bypass).<br>- Bez platených pravidiel limitovaná ochrana dynamiky. | **Doplnková** (Vhodné ako 1. vrstva obrany, ale nenahrádza lokálnu cache). |
| **Natívne CMS Pluginy (W3 Total Cache)** | Aplikačná Cache | - Jednoduchá inštalácia priamo z prostredia WordPressu.<br>- Šikovné funkcie ako minifikácia JS/CSS. | - Cachovanie prebieha až na aplikačnej vrstve (PHP).<br>- Pri DDoS útoku sa rýchlo minú PHP workery a server spadne. | **Nízka** (Nginx a Varnish sú na L7 vrstve oveľa rýchlejšie). |

## Odporúčané riešenie pre implementáciu
Pre tento projekt zvolíme kombináciu:
1.  **Varnish Cache** pre **Full Page Cache** (statický a pseudo-statický obsah) - zabezpečí odolnosť voči HTTP Flood DDoS.
2.  **Redis** pre **Object Cache** - zníži záťaž na databázu pri dynamických požiadavkách (napr. prihlásený užívateľ).
