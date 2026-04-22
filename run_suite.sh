#!/bin/bash

echo "=========================================================="
echo "SPÚŠŤAM SÉRIU ZÁŤAŽOVÝCH TESTOV NA IDENTIFIKÁCIU LIMITÁCIÍ"
echo "=========================================================="

# Test 1: Statická záťaž (Veľká záťaž, ale prevažne z cache) - ukazuje limity samotného Varnishu
echo ""
echo "--- TEST 1: Vysoká statická záťaž (500 používateľov) ---"
python3 run_locust_experiment.py -u 500 -r 50 -t 30s --vmem 512M --php 25 -l locustfile.py --name "t1_static_u500"

# Test 2: Nákupná horúčka (100% dynamická záťaž bez cache) - ukazuje limit 25 PHP workerov
echo ""
echo "--- TEST 2: Útok na nákupný košík (200 používateľov) ---"
python3 run_locust_experiment.py -u 200 -r 20 -t 30s --vmem 512M --php 25 -l locustfile_heavy.py --name "t2_heavy_u200"

# Test 3: Mix (70% staticky, 30% dynamicky) - simulácia bežného dňa s akciou (300 používateľov)
echo ""
echo "--- TEST 3: Zmiešaná záťaž (300 používateľov) ---"
python3 run_locust_experiment.py -u 300 -r 30 -t 30s --vmem 512M --php 25 -l locustfile_mixed.py --name "t3_mixed_u300"

# Test 4: Extrémny Mix (500 používateľov) - testujeme totálny pád pri dynamickom obsahu
echo ""
echo "--- TEST 4: Extrémna Zmiešaná záťaž (500 používateľov) ---"
python3 run_locust_experiment.py -u 500 -r 50 -t 30s --vmem 512M --php 25 -l locustfile_mixed.py --name "t4_mixed_u500"

# Test 5: Spike (Náhly DDoS útok) - Skúma správanie cache pod šokovou záťažou
echo ""
echo "--- TEST 5: Náhly SPIKE / DDoS (10 -> 1000 -> 10 používateľov) ---"
# Poznámka: Pri Custom Shape triede (SpikeShape) Locust ignoruje -u a -r, riadi sa triedou. 
# Pre zachovanie formátu tvojho skriptu tam parametre u/r ale nechávame.
python3 run_locust_experiment.py -u 1000 -r 100 -t 60s --vmem 512M --php 25 -l locustfile_spike.py --name "t5_spike_u1000"

# Test 6: Extrémny objem (Volume Test) len na Varnish (3000 používateľov)
echo ""
echo "--- TEST 6: Hľadanie limitu samotného Varnishu (3000 statických používateľov) ---"
python3 run_locust_experiment.py -u 3000 -r 300 -t 30s --vmem 512M --php 25 -l locustfile.py --name "t6_volume_u3000"

echo ""
echo "=========================================================="
echo "FÁZA 2: TUNING INFRAŠTRUKTÚRY (Zmena Varnish RAM a PHP Workerov)"
echo "=========================================================="

# Test 7: Zvýšenie počtu PHP workerov (Pomôže to pri košíkoch?)
echo ""
echo "--- TEST 7: Tuning - Zvýšenie PHP na 50 workerov (Útok na košík) ---"
python3 run_locust_experiment.py -u 200 -r 20 -t 30s --vmem 512M --php 50 -l locustfile_heavy.py --name "t7_heavy_u200_p50"

# Test 8: Zníženie Varnish pamäte (Začne Varnish nestíhať a vyhadzovať z cache?)
echo ""
echo "--- TEST 8: Tuning - Extrémne zníženie Varnish pamäte na 128M (Mix záťaž) ---"
python3 run_locust_experiment.py -u 300 -r 30 -t 30s --vmem 128M --php 25 -l locustfile_mixed.py --name "t8_mixed_u300_v128M"

# Test 9: Over-provisioning (Veľa pamäte, veľa workerov)
echo ""
echo "--- TEST 9: Tuning - Maximum zdrojov (Varnish 1G, PHP 100 workerov, Mix záťaž) ---"
python3 run_locust_experiment.py -u 500 -r 50 -t 30s --vmem 1G --php 100 -l locustfile_mixed.py --name "t9_mixed_u500_v1G_p100"

echo ""
echo "=========================================================="
echo "VŠETKY TESTY DOKONČENÉ. Pozri priečinok results/"
echo "=========================================================="
