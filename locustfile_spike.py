from locust import HttpUser, task, between, LoadTestShape
import math

class SpikeUser(HttpUser):
    # Extrémne krátke čakanie, simulujeme botov
    wait_time = between(0.1, 0.5)

    @task(10)
    def view_homepage(self):
        self.client.get("/", name="[SPIKE] Homepage Cache")

    @task(1)
    def aggressive_search(self):
        self.client.get("/?s=ddos", name="[SPIKE] Backend Attack")


class SpikeShape(LoadTestShape):
    """
    Tvar záťaže: 
    - 0-10s: Kľud (10 userov)
    - 10-20s: NÁHLY ÚTOK (1000 userov)
    - 20-40s: Držanie útoku (1000 userov)
    - 40-60s: Koniec útoku, návrat do normálu (10 userov)
    """
    time_limit = 60

    def tick(self):
        run_time = self.get_run_time()

        if run_time < 10:
            return (10, 2) # 10 userov, spawn rate 2
        elif run_time < 20:
            return (1000, 100) # Rýchly nárast na 1000 (Spawn rate 100/s)
        elif run_time < 40:
            return (1000, 10) # Udržiavanie 1000
        elif run_time < 60:
            return (10, 50) # Rýchly pád späť na 10
        
        return None # Koniec testu
