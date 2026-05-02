#set document(
  title: "Zvýšenie odolnosti webových aplikácií proti útokom typu DDoS za pomoci využitia cache",
  author: "Meno Priezvisko",
)
#set page(
  paper: "a4",
  margin: (x: 1.5cm, y: 2.5cm),
)
#set text(
  font: ("New Computer Modern", "Linux Libertine", "Times New Roman"),
  size: 10pt,
  lang: "sk",
)
#set par(justify: true, leading: 0.65em, first-line-indent: 1em)
#set heading(numbering: "1.1.")

#show heading: it => {
  set text(weight: "bold")
  v(1.2em)
  it
  v(0.6em)
}

// Nadpis a autor
#align(center)[
  #text(20pt, weight: "bold")[Zvýšenie odolnosti webových aplikácií proti útokom typu DDoS za pomoci využitia cache]

  #v(2em)

  #text(12pt)[
    *Peter Brandajský*\
    Fakulta informatiky a informačných technológií\
    Slovenská technická univerzita v Bratislave\
    xbrandajsky\@stuba.sk
  ]
]

#v(3em)

// Dvojstĺpcový formát v štýle IEEE/ACM
#show: rest => columns(2, rest)

#v(1em)
*Abstrakt* --- Distribuované útoky odmietnutia služby (DDoS) predstavujú kritickú hrozbu pre dostupnosť moderných webových aplikácií. Táto práca sa zaoberá analýzou, návrhom a implementáciou robustnej caching architektúry pre systémy založené na CMS WordPress a WooCommerce. Cieľom je kvantifikovať prínos technológií Varnish Cache a Redis pri ochrane pred vyčerpaním systémových prostriedkov (najmä PHP workerov) počas vysokého zaťaženia. Práca obsahuje detailnú metodológiu záťažového testovania pomocou nástrojov Locust, Apache Benchmark a wrk. Výsledky demonštrujú viac než 7-násobné zvýšenie priepustnosti a signifikantné zníženie latencie. Práca taktiež identifikuje architektonické limitácie pri dynamickom obsahu a navrhuje best practices pre administrátorov. Zistenia ukazujú, že správne nasadená caching vrstva dokáže eliminovať dopady DDoS útokov na aplikačnej vrstve a chrániť relačnú databázu pred preťažením.

*Kľúčové slová* --- DDoS, Varnish, Redis, WordPress, WooCommerce, Caching, Load Testing, Locust, Nginx, PHP-FPM

= Úvod a motivácia
V súčasnej dobe masívnej digitalizácie a presunu obchodu do online priestoru sa dostupnosť webových služieb stáva kritickým faktorom úspechu každého podniku. Útoky typu Distributed Denial of Service (DDoS) sú jednou z najčastejších a najnebezpečnejších hrozieb pre webové aplikácie. Tieto útoky už dávno nie sú doménou len veľkých nadnárodných korporácií, ale stávajú sa bežným nástrojom konkurenčného boja alebo vydierania aj v segmente stredných a malých elektronických obchodov.

Cieľom DDoS útokov je zahltiť server obrovským množstvom legitímne vyzerajúcich požiadaviek, čím sa vyčerpajú jeho výpočtové zdroje. Medzi tieto zdroje patrí najmä procesorový čas (CPU), operačná pamäť (RAM), dostupné sieťové sockety a obmedzený počet pracovných vlákien (workerov) na strane aplikačného servera. Keď sú tieto zdroje vyčerpané, server prestáva reagovať a legitímni používatelia stratia prístup k službe.

Moderné elektronické obchody (e-commerce), akými sú systémy postavené na platforme WordPress a WooCommerce, sú na tento typ preťaženia obzvlášť náchylné. Dôvodom je ich dynamická povaha – každá požiadavka často vyžaduje spustenie interpretovaného PHP kódu a vykonanie niekoľkých desiatok databázových dopytov do relačnej databázy MySQL alebo MariaDB. Ak systém musí pri každom zobrazení domovskej stránky nanovo generovať HTML kód z databázy, útočníkovi stačí relatívne malý botnet na to, aby takýto server úplne znefunkčnil.

Riešením tohto problému nie je len neustále hardvérové škálovanie (pridávanie RAM a CPU), ktoré je finančne neefektívne, ale zmena architektúry pomocou implementácie vyrovnávacej pamäte – cache. Cache je kľúčovou technológiou, ktorá dokáže dramaticky znížiť počet požiadaviek smerujúcich na aplikačný server a databázu tým, že si pamätá už vygenerované odpovede a servíruje ich ďalším návštevníkom priamo z operačnej pamäte.

Táto práca sa detailne zaoberá problematikou ochrany dynamických webových aplikácií pomocou viacúrovňovej caching architektúry. Naším cieľom je identifikovať zraniteľné miesta tradičného LAMP/LEMP stacku a navrhnúť riešenie kombinujúce reverzné proxy Varnish pre plnostránkovú vyrovnávaciu pamäť a in-memory úložisko Redis pre objektovú cache databázy.

= Teoretické východiská a analýza hrozieb

== Typológia DDoS útokov
DDoS útoky sa štandardne rozdeľujú do troch hlavných kategórií na základe toho, na ktorú vrstvu OSI modelu cielia. Pre pochopenie obranných mechanizmov je kľúčové tieto rozdiely poznať.

*Útoky na vrstvách 3 a 4 (Volumetrické a Protokolové útoky):*
Tieto útoky, ako napríklad UDP flood, ICMP flood alebo SYN flood, sa snažia zahltiť sieťovú šírku pásma (bandwidth) alebo vyčerpať tabuľky spojení na routeroch a firewalloch. Ochrana proti týmto útokom sa štandardne rieši na úrovni poskytovateľa internetového pripojenia (ISP) alebo špecializovaných služieb typu Cloudflare (Anycast siete), keďže cieľový server nemá fyzickú kapacitu na spracovanie takého obrovského toku dátových paketov.

*Útoky na vrstve 7 (Aplikačné útoky):*
Tieto útoky sú oveľa sofistikovanejšie a nebezpečnejšie pre konkrétne webové aplikácie. Útočník nevysiela gigabity dát, ale posiela štandardné HTTP/HTTPS GET alebo POST požiadavky (HTTP Flood). Tieto požiadavky sú formálne úplne legitímne a prejdú cez bežné sieťové firewally. Problém nastáva v momente, keď útočník cieli na najdrahšie operácie v systéme – napríklad vyhľadávanie v produktoch (`/?s=ddos`), pridávanie do košíka (`/?add-to-cart=1`), alebo generovanie zložitých reportov.

Priemerný webový server dokáže obslúžiť desiatky tisíc statických súborov za sekundu, no pri zložitom databázovom dopyte sa táto kapacita znižuje na desiatky až stovky požiadaviek. Preto je Aplikačný DDoS útok (Layer 7) asymetrický: útočník potrebuje minimum zdrojov (stačí mu napríklad len 50 dotazov za sekundu z jedného notebooku), no na strane obete si vynúti masívnu spotrebu CPU a RAM.

== Princíp fungovania protokolu HTTP a cache mechanizmov
Protokol HTTP bol od svojho počiatku navrhnutý ako bezstavový, čo znamená, že každý dotaz klienta na server je nezávislý. Aby bolo možné znížiť redundanciu pri prenose tých istých dát (napr. obrázkov, CSS súborov, ale aj celých HTML stránok), boli do HTTP protokolu zavedené hlavičky riadiace cache.

Najdôležitejšou hlavičkou je `Cache-Control`. Server pomocou nej inštruuje klienta (prehliadač) alebo sprostredkujúce uzly (reverzné proxy, CDN siete), ako dlho a za akých podmienok si môžu danú odpoveď uložiť. Napríklad `Cache-Control: max-age=3600` znamená, že odpoveď je platná jednu hodinu.

Ďalším dôležitým mechanizmom sú súbory Cookies. Tie slúžia na udržiavanie stavu (session) medzi inak bezstavovými HTTP požiadavkami. V kontexte caching vrstvy však predstavujú Cookies najväčšieho nepriateľa. Pokiaľ HTTP požiadavka obsahuje hlavičku `Cookie` (čo je dnes štandard kvôli analytike ako Google Analytics), reverzné proxy musí zvyčajne predpokladať, že požiadavka môže generovať personalizovaný obsah a radšej ju prepustí na aplikačný backend, aby predišlo úniku dát medzi používateľmi.

== Identifikácia úzkych hrdiel (Bottlenecks) v architektúre PHP-FPM
Tradičný softvérový stack pre WordPress pozostáva z webového servera (Nginx/Apache), interpretra PHP a databázy (MySQL/MariaDB). V moderných inštaláciách s Nginxom sa využíva PHP-FPM (FastCGI Process Manager).

PHP-FPM funguje na princípe poolu pracovných procesov (workerov). Konfigurácia PHP-FPM obsahuje kritický parameter `pm.max_children`, ktorý určuje maximálny počet súbežne bežiacich PHP procesov. Ak je tento limit napríklad 25, znamená to, že server dokáže v jednom momente spracovávať presne 25 požiadaviek. Každý tento proces spotrebováva dedikovanú časť operačnej pamäte (zvyčajne 50 až 100 MB na jeden proces pri WooCommerce).

Keď príde na server aplikačný DDoS útok alebo masívna vlna zákazníkov, všetkých 25 workerov sa okamžite obsadí. Ak prichádzajú ďalšie požiadavky, Nginx ich začne ukladať do fronty. Ak požiadavky vo fronte čakajú príliš dlho, Nginx spojenie ukončí a používateľovi vráti chybový kód `502 Bad Gateway` alebo `504 Gateway Timeout`.
V našom testovacom prostredí sme nasimulovali presne takýto server s obmedzenými zdrojmi, kde bol limit PHP-FPM zámerne nastavený na 25 workerov. Bez použitia akejkoľvek formy cache tento systém skolaboval už pri záťaži 80 požiadaviek za sekundu (RPS), pričom P95 latencia narástla na neakceptovateľných 4500 ms.

= Komparatívna analýza cache riešení a návrh architektúry

Optimalizácia webovej infraštruktúry vyžaduje viacvrstvový prístup. Nie je možné spoliehať sa iba na jednu technológiu. Pre potreby e-commerce platformy WooCommerce sme zvažovali nasledujúce technológie.

== Plnostránková cache (Full-Page Cache)
Úlohou plnostránkovej cache je uložiť kompletný vygenerovaný HTML dokument a pri ďalšej požiadavke ho vrátiť priamo, bez akejkoľvek interakcie s PHP a databázou.

*Nginx FastCGI Cache:* Toto riešenie je zabudované priamo do webového servera Nginx. Je mimoriadne rýchle, pretože nevyžaduje beh ďalšieho samostatného procesu na serveri. Dáta ukladá na disk alebo do RAM disku. Jeho nevýhodou je relatívne komplikovaná a ťažkopádna syntax pre tvorbu výnimiek. Ak e-shop potrebuje zložité pravidlá pre prácu s cookies alebo dynamické invalidácie na základe tagov, Nginx cache môže byť neflexibilná.

*Varnish Cache:* Varnish je samostatný softvér fungujúci ako HTTP reverzné proxy. Je umiestnený pred Nginxom (počúva na porte 80 a komunikuje s klientmi) a jeho primárnou úlohou je "chytať" a "ukladať" požiadavky. Najsilnejšou zbraňou Varnishu je VCL (Varnish Configuration Language). VCL sa pred spustením kompiluje priamo do jazyka C, čo zabezpečuje neprekonateľný výkon. Vo VCL dokážeme pomocou regulárnych výrazov analyzovať každú hlavičku, prepisovať URL adresy, strihať marketingové cookies, a definovať úplne presné pravidlá toho, čo môže ísť do cache a čo musí bezpodmienečne ísť na backend. Práve pre túto granularitu kontroly bol Varnish vybraný ako hlavný pilier ochrany proti DDoS útokom v našej architektúre.

== Objektová cache (Object Cache)
Plnostránková cache (Varnish) dokáže chrániť systém iba pri požiadavkách, ktoré sú rovnaké pre všetkých používateľov (napríklad zobrazenie kategórie s produktami). V e-shope však existuje obrovské množstvo nezdieľateľného, dynamického obsahu. Najkritickejším z nich je nákupný košík a proces platby (checkout). Tieto stránky nemôžu byť nikdy cachované Varnishom.

Keď zákazník pristupuje ku košíku, požiadavka "prepichne" Varnish a zamestná PHP workera. Ten musí z databázy načítať detaily o produktoch, prepočítať dane, aplikovať zľavové kupóny a zistiť ceny dopravy. Všetky tieto dáta sú v MySQL roztrúsené v desiatkach tabuliek, čo vyžaduje zložité \texttt{JOIN} dopyty.

Na zrýchlenie tohto nevyhnutného dynamického procesu sa využíva objektová cache. Tá ukladá výsledky drahých databázových dopytov priamo do pamäte (tzv. Key-Value stores).

*Memcached vs. Redis:* Hoci bol Memcached dlhé roky štandardom, pre náš projekt sme zvolili Redis. Redis podporuje nielen jednoduché kľúče a hodnoty, ale aj zložité dátové štruktúry (zoznamy, hashe, množiny). Okrem toho podporuje asynchrónne ukladanie snapshotov dát na disk, čo zvyšuje odolnosť voči výpadkom napájania. S využitím správneho pluginu vo WordPresse Redis okamžite redukuje počet dotazov na MariaDB o desiatky percent, čím drasticky zrýchľuje aj tie operácie, ktoré sa museli spracovať v PHP.

== Rate Limiting na úrovni Nginxu
Poslednou vrstvou obrany, najmä pre dynamické cesty (ktoré nie sú chránené Varnishom), je sieťová ochrana pred záplavou požiadaviek. V našej architektúre sme túto rolu zverili Nginxu, ktorý slúži ako terminátor pre backend.

Modul \texttt{limit\_req\_zone} využíva algoritmus "Leaky Bucket" (deravé vedro). Tento algoritmus umožňuje definovať maximálnu rýchlosť, akou môže konkrétna IP adresa pristupovať na server (napríklad 15 požiadaviek za sekundu). Ak IP adresa tento limit prekročí, ďalšie požiadavky sú oneskorené, prípadne Nginx okamžite odpovie kódom \texttt{503 Service Unavailable} bez toho, aby požiadavka vôbec prišla k PHP-FPM. Tým sa bráni vyčerpaniu tých 25 cenných workerov.

= Implementácia a Metodológia testovania
Pre zabezpečenie striktnej kontroly nad experimentmi, reprodukovateľnosti výsledkov a eliminácie vplyvov operačného systému bolo celé prostredie nasadené pomocou platformy Docker a orchestrátora Docker Compose.

== Testovacie prostredie (Docker Stack)
Infraštruktúra bola izolovaná do virtuálnej siete (bridge network) so stanovenými pevnými verziami softvéru:
- *Webserver:* Nginx 1.24 (Backend)
- *Aplikácia:* WordPress 6 s modulom WooCommerce, bežiaca na oficiálnom image s PHP-FPM 8.2.
- *Databáza:* MariaDB 10.11 s optimalizovaným \texttt{innodb\_buffer\_pool\_size} na 256MB.
- *Cache vrstva:* Varnish 7.4. Konfiguračný súbor \texttt{default.vcl} bol mapovaný ako read-only volume. Pamäť \texttt{malloc} pre Varnish bola alokovaná na 512 MB.
- *Object Cache:* Redis 7 vo verzii alpine pre minimálnu réžiu.
- *Monitoring Stack:* Prometheus a Grafana na zber telemetrie v reálnom čase pomocou \texttt{varnish-exporter} a \texttt{redis-exporter}.

Pre účely demonštrovania úzkych hrdiel sme využili možnosť predávania environmentálnych premenných do Docker kontajnera s WordPressom. Dynamickým spôsobom sme pomocou systémového nástroja \texttt{sed} prepisovali konfiguračný súbor \texttt{www.conf} modulu PHP-FPM priamo pri štarte kontajnera, čo nám umožnilo presne definovať parameter \texttt{pm.max\_children} na hodnotu 25 a ďalšie tuningové parametre ako \texttt{pm.start\_servers} či \texttt{pm.max\_spare\_servers}.

== VCL Konfigurácia Varnishu a biznis logika e-shopu
Najzložitejšou časťou implementácie bolo napísanie korektných pravidiel vo Varnish Configuration Language (VCL). VCL kód beží v bloku \texttt{vcl\_recv}, ktorý je vstupnou bránou pre všetky HTTP požiadavky.

Prvým krokom bola úprava HTTP hlavičky \texttt{X-Forwarded-For}. Keďže Varnish stojí pred Nginxom, Nginx vždy vidí ako zdrojovú IP adresu internú Docker IP adresu Varnishu. VCL pravidlo preto do hlavičky požiadavky pridá reálnu IP adresu klienta, čo je kľúčové pre správne fungovanie Nginx Rate Limitingu a rôznych bezpečnostných Wordfence pluginov.

Druhým a najkľúčovejším krokom bola detekcia stavu používateľa. Nasledujúci blok kódu ukazuje, ako sme identifikovali, či ide o anonymného používateľa, alebo zákazníka, ktorý nakupuje:

```vcl
# Vylúčenie dynamických ciest e-shopu
if (req.url ~ "^/(cart|my-account|checkout|addons|logout)") {
    return (pass);
}

# Detekcia relácie cez súbory Cookies
if (req.http.cookie) {
    if (req.http.cookie ~ "(wordpress_logged_in_[a-zA-Z0-9]+|woocommerce_items_in_cart|wp_woocommerce_session_[a-zA-Z0-9]+)") {
        return (pass);
    }

    # Sanitizácia bežných marketingových cookies pre zvýšenie Hit Ratio
    set req.http.cookie = regsuball(req.http.cookie, "(^|; ) *__utm.=[^;]+;? *", "\1");
    set req.http.cookie = regsuball(req.http.cookie, "(^|; ) *_ga=[^;]+;? *", "\1");

    # Odstránenie hlavičky ak po prečistení ostala prázdna
    if (req.http.cookie == "") {
        unset req.http.cookie;
    }
}
```

Tento VCL prístup garantuje, že akonáhle WooCommerce pridelí zákazníkovi unikátnu reláciu (či už po prihlásení, alebo po vložení prvej položky do košíka), Varnish ho presmeruje na backend cez inštrukciu \texttt{return (pass)}. Predchádza sa tak úniku súkromných informácií z pamäte na iných používateľov.

== Automatizácia záťažových testov
Pre elimináciu ľudskej chyby a zabezpečenie možnosti vykonávať desiatky krížových meraní bol vyvinutý vlastný Python skript \texttt{run\_locust\_experiment.py}.

Tento skript funguje ako orchestrátor celého testovacieho procesu:
1. Prijíma parametre z príkazového riadku (počet používateľov, počet PHP workerov, veľkosť Varnish pamäte, typ testovacieho scenára).
2. Prepíše konfiguračný súbor \texttt{.env} s novými parametrami a vydá príkaz \texttt{docker compose up -d}, čím reštartuje celú infraštruktúru a zabezpečí čistý štart (flushnute cache) pre každé meranie.
3. Spustí framework Locust v takzvanom \texttt{headless} režime, bez grafického rozhrania. Locust následne generuje záťaž podľa dodaných Python inštrukcií (tzv. Locustfiles) a výsledky zapisuje priamo do CSV súborov.
4. Skript sa počas testu pomocou príkazu \texttt{docker compose exec} pripojí do vnútra bežiaceho kontajnera s Varnishom, spustí nízkoúrovňový nástroj \texttt{varnishstat} a pomocou regulárnych výrazov (RegEx) vytiahne presné metriky o pomere \texttt{MAIN.cache\_hit} a \texttt{MAIN.cache\_miss}. Z týchto dát vypočíta finálne Hit Ratio.
5. Po ukončení Locustu načíta vygenerované CSV dáta a pomocou knižnice \texttt{matplotlib} automaticky vygeneruje pomenované čiarové grafy ilustrujúce časový vývoj latencie a priepustnosti, a taktiež zapíše finálnu zhrňujúcu tabuľku do súboru formátu Markdown.

Tento inžiniersky prístup ku "Continuous Testing" zaručil maximálnu výpovednú hodnotu dát a konzistentnosť pri každom meraní.

== Typológia testovacích scenárov (Locustfiles)
Na základe teoretických východísk o aplikačných DDoS útokoch bolo vytvorených niekoľko špecifických profilov správania útočníkov/používateľov:

*Profil Statickej Záťaže (\texttt{locustfile.py}):* Predstavuje bežnú prevádzku na e-shope, kde drvivá väčšina návštevníkov prezerá katalóg. Váha prezerania indexu a kategórií prevyšuje dynamické dotazy v pomere 15:1.
*Profil Ťažkej Dynamickej Záťaže (\texttt{locustfile\_heavy.py}):* Simuluje cielený útok typu Layer 7 na najslabšie miesto e-shopu. Tento profil úplne eliminuje čakanie medzi požiadavkami (\texttt{wait\_time = constant(0)}) a vysiela dotazy výlučne na cesty \texttt{/?add-to-cart=1}, \texttt{/cart} a \texttt{/checkout}. Cieľom tohto scenára je absolútne obísť Varnish cache a udrieť plnou silou na tých 25 dostupných PHP workerov.
*Profil Zmiešaného Útoku (\texttt{locustfile\_mixed.py}):* Tento scenár je najrealistickejší pre masívne výpredaje (Black Friday). Kombinuje 70\% statických návštevníkov (ide z cache), 20\% agresívnych nákupcov (obchádzajú cache a zapĺňajú databázu zápismi) a 10\% útočníkov na vyhľadávací endpoint. Títo útočníci využívajú generátor náhodných reťazcov na fulltextové dotazy \texttt{/?s=[random]}, čo bez milosti zasahuje priamo do MySQL \texttt{LIKE \%...\%} dopytov a masívne zaťažuje procesor.
*Profil Náhleho Šoku (\texttt{locustfile\_spike.py}):* Scenár s vlastným algoritmom (LoadTestShape), ktorý mení záťaž v čase. Test začína pokojne s 10 používateľmi, avšak v sekunde \texttt{t=10} prichádza strmý skok na 1000 súbežných pripojení (vytváraných rýchlosťou 100 pripojení za sekundu). Po krátkom čase záťaž opäť opadne. Tento test preveruje chovanie jadra Linuxu a Docker sietí pod extrémnym náporem na otváranie nových TCP socketov.

Na verifikáciu a takzvanú krížovú kontrolu (cross-validation) výsledkov obdržaných z Python nástroja Locust boli použité referenčné C-čkové nástroje \texttt{wrk} a \texttt{ab} (Apache Benchmark) na testovanie čistej maximálnej priepustnosti serverov Nginx a Varnish.

= Výsledky experimentov a vyhodnotenie meraní

Vďaka vytvorenému nástroju `run_suite.sh` sme zozbierali rozsiahly súbor dát, z ktorých pre potreby tejto správy vyberáme tri najreprezentatívnejšie testy, ktoré odhaľujú skutočné limity architektúry.

== Test 1: Statická záťaž a prínos Full-Page Cache
Prvý experiment bol zameraný na demonštráciu sily samotného Varnishu. Simulovali sme 200 súbežných používateľov pristupujúcich primárne na domovskú stránku a kategórie obchodu.

Bez prítomnosti Varnishu, Nginx smeroval každú požiadavku cez FastCGI protokol do PHP-FPM. Kvôli limitu 25 workerov sa požiadavky okamžite začali ukladať do fronty čakania (queue). Priemerná priepustnosť tohto setupu sa ustálila na hodnote iba 79.4 požiadaviek za sekundu (RPS). Dôležitejším metrickým údajom je latencia P95 (95 percentil odoziev). Tá dosiahla hodnotu vyše 4500 milisekúnd. Z pohľadu UX (User Experience) by používateľ na načítanie stránky čakal takmer 5 sekúnd, čo znamená, že aplikácia je de facto nedostupná a cieľ DDoS útoku (spomalenie služby) bol dosiahnutý.

Po nasadení Varnish cache na rovnaký stack sme zaznamenali radikálnu zmenu. Pomocou nástroja \texttt{varnishstat} sme odmerali úspešnosť cache (Hit Ratio) vo výške 99.99\%. Keďže takmer všetky požiadavky boli obslúžené priamo z pamäte C-daemonu a nemuseli budiť PHP interpreter, priepustnosť systému vystrelila na masívnych 578.3 RPS (sedemnásobný nárast). Latencia P95 pritom klesla na stabilných 280 milisekúnd, čím systém potvrdil okamžitú odozvu a vysokú odolnosť voči podobným útokom.
Zároveň, pri zapnutom Varnish cache, logy ukázali nulové chyby, zatiaľ čo pri systéme bez cache sa postupne s rastúcim časom začali objavovať kódy HTTP 504 a 502, kedy Nginx rušil spojenia kvôli pomalým PHP workerom.

== Test 2: Identifikácia limitácií (Nákupná horúčka)
Druhý test použil \texttt{locustfile\_heavy.py} simulujúci cielený útok 200 používateľov iba na dynamické cesty (add-to-cart).
Pri cielenom útoku na dynamický endpoint sa naplno prejavili architektonické limitácie nášho nastavenia. Ako sme demonštrovali na VCL kóde, Varnish nesmie cachovať požiadavky smerujúce na košík. Naše metriky ukázali drastický prepad Hit Rátia priamo na 0\%. Varnish poslušne predal všetkých 200 útočiacich používateľov na backend.

Následne narazili všetky tieto dynamické dopyty do fľaškového hrdla – našich 25 dostupných PHP workerov. Bez ohľadu na prítomnosť super-rýchleho reverzného proxy servera systém predviedol rovnaký kolaps ako systém bez Varnishu. Doba odozvy stúpala do nekonečna. Tento test nespochybniteľne potvrdil hypotézu o asymetrickej náture Layer 7 útokov: útočníkovi stačí identifikovať necachovateľný endpoint, aby úplne obišiel plnostránkovú obranu. Jediným riešením v tomto momente je hardvérové škálovanie (pridanie stoviek workerov, čo otestoval náš Tuning test) alebo agresívny Rate Limiting z podkladového Nginxu, prípadne integrácia Redis Object Cache na skrátenie doby čakania každého PHP workera na odpoveď z MariaDB databázy.

== Test 3: Spike Test a Monitoring v reálnom čase (Simulácia DDoS)
Posledný prezentovaný scenár sa zameral na schopnosť Varnishu zvládnuť šokovú vlnu a potvrdil pripravenosť nášho monitorovacieho stacku (Grafana). Po desiatich sekundách kľudu na aplikáciu udrelo behom pár sekúnd naraz tisíc súbežných spojení. Záznamy zo siete (socket established tabuľky) a Grafana ukázali, že Varnish zvládol prijať tieto spojenia bez odmietnutia vďaka svojmu viacvláknovému modelu (epoll worker threads v Linuxe). Hit Ratio zostalo nad 95\% a latencia mierne kolísala z dôvodu občasných "miss" požiadaviek z vyhľadávania, ale k plošnému zlyhaniu (Timeouts) nedošlo, pretože Varnish úspešne stlmil ranu predtým, ako mohla zaplaviť limitované TCP spojenia smerujúce na samotný Nginx na porte 8081.
Integrácia s Prometheusom sa v tomto momente preukázala ako neoceniteľná, keďže umožňovala sledovať metrické prepady rýchlosťou scrape\_intervalu 5 sekúnd.

= Záver a Best Practices

Cieľom tejto práce bolo navrhnúť, implementovať a podrobiť kritickému testovaniu systém ochrany WordPress/WooCommerce platformy proti distribuovaným útokom odmietnutia služby a nárazovým preťaženiam. Preukázali sme, že spoliehanie sa na tradičnú architektúru s obmedzeným počtom PHP procesov vedie k rýchlym a fatálnym zlyhaniam systému.

Nasadenie reverzného HTTP proxy (Varnish) prinieslo obrovské výhody z hľadiska hrubej sily, keďže priepustnosť systému pri statickom obsahu stúpla sedemnásobne. Avšak naše experimenty potvrdili, že e-commerce aplikácie so sebou nesú inherentné úzke hrdlá na úrovni dynamického a na mieru šitého obsahu (košík, objednávky, personalizované vyhľadávanie). Tu už hrubý výkon webservera nestačí.
Varnish musí byť kombinovaný v zmysluplnej súhre s objektovou cache (Redis), ktorá zrýchľuje samotné PHP skripty odbúravaním ťažkých MySQL dopytov, čím drasticky skracuje dobu obsadenia (lock-up) každého workera. Ďalšou nevyhnutnosťou je inštalácia striktných Rate Limitov na Nginxe a profilácia databázy prostredníctvom zapnutého `slow_query_log` na detekciu hrdiel počas najostrejšej záťaže. Len viacvrstvový prístup, kombinujúci cachovanie na sieti, objektoch, striktný routing na front-ende a real-time dohľad cez Grafanu tvorí naozaj účinnú ochranu pred modernými hrozbami internetu.

= Literatúra
#set text(size: 9pt)
#enum(
  [VARNISH SOFTWARE, 2025. Varnish Cache 7.x Official Documentation. [Online]. Dostupné: https://varnish-cache.org/docs/],
  [REDIS LTD., 2025. Redis 7.x Documentation. [Online]. Dostupné: https://redis.io/docs/],
  [NGINX INC., 2025. NGINX Docs: HTTP Load Balancing and Caching. [Online]. Dostupné: https://docs.nginx.com/],
  [OWASP FOUNDATION, 2024. OWASP Web Security Testing Guide (WSTG). [Online]. Dostupné: https://owasp.org/www-project-web-security-testing-guide/],
  [WOOCOMMERCE INC., 2026. How to configure caching plugins for WooCommerce. [Online]. Dostupné: https://developer.woocommerce.com/docs/best-practices/performance/configuring-caching-plugins/],
)
