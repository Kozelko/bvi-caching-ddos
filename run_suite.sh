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

echo ""
echo "=========================================================="
echo "VŠETKY TESTY DOKONČENÉ. Pozri priečinok results/"
echo "=========================================================="
