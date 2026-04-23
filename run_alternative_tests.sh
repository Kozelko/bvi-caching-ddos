#!/bin/bash

echo "=========================================================="
echo "ALTERNATÍVNE ZÁŤAŽOVÉ TESTY (Cross-Validation)"
echo "Nástroje: Apache Benchmark (ab) a wrk"
echo "=========================================================="

mkdir -p results/alternative_tests

# 1. Testujeme Varnish (port 8080) pomocou wrk (extrémne rýchly nástroj v jazyku C)
echo ""
echo "--- 1. WRK: Testujeme S CACHE (Varnish:8080) na 30 sekúnd ---"
docker run --rm --network host williamyeh/wrk -t4 -c200 -d30s http://localhost:8080/ > results/alternative_tests/wrk_varnish.txt
cat results/alternative_tests/wrk_varnish.txt | grep "Requests/sec"

# 2. Testujeme Nginx (port 8081) pomocou wrk
echo ""
echo "--- 2. WRK: Testujeme BEZ CACHE (Nginx:8081) na 30 sekúnd ---"
docker run --rm --network host williamyeh/wrk -t4 -c200 -d30s http://localhost:8081/ > results/alternative_tests/wrk_nginx.txt
cat results/alternative_tests/wrk_nginx.txt | grep "Requests/sec"

# 3. Testujeme Varnish pomocou Apache Benchmark (ab)
echo ""
echo "--- 3. AB: Testujeme S CACHE (Varnish:8080) - 5000 požiadaviek ---"
docker run --rm --network host jordi/ab -n 5000 -c 100 http://localhost:8080/ > results/alternative_tests/ab_varnish.txt
cat results/alternative_tests/ab_varnish.txt | grep "Requests per second"

# 4. Testujeme Nginx pomocou Apache Benchmark (ab)
echo ""
echo "--- 4. AB: Testujeme BEZ CACHE (Nginx:8081) - 500 požiadaviek ---"
docker run --rm --network host jordi/ab -n 500 -c 100 http://localhost:8081/ > results/alternative_tests/ab_nginx.txt
cat results/alternative_tests/ab_nginx.txt | grep "Requests per second"

echo ""
echo "=========================================================="
echo "Hotovo. Detailné logy sú uložené v zložke results/alternative_tests/"
echo "Tieto dáta použi do záverečnej správy na verifikáciu výsledkov z Locustu."
echo "=========================================================="
