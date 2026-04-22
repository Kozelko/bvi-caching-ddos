from locust import HttpUser, task, between, constant
import random
import string

class StaticBrowser(HttpUser):
    weight = 70
    wait_time = between(1, 3)

    @task(10)
    def view_homepage(self):
        self.client.get("/", name="[STATICKY] Homepage")

    @task(5)
    def view_shop(self):
        self.client.get("/shop/", name="[STATICKY] Shop")

class DynamicBuyer(HttpUser):
    weight = 20
    wait_time = between(2, 5)

    @task(3)
    def add_to_cart(self):
        self.client.get("/?add-to-cart=1", name="[DYNAMICKY] Add to Cart")
        
    @task(2)
    def view_cart(self):
        self.client.get("/cart/", name="[DYNAMICKY] View Cart")

    @task(1)
    def checkout(self):
        self.client.get("/checkout/", name="[DYNAMICKY] Checkout")

class SearchAttacker(HttpUser):
    weight = 10
    wait_time = constant(0)

    @task
    def search(self):
        # Náhodné vyhľadávanie kompletne obchádza cache a priamo útočí na DB a PHP
        q = ''.join(random.choices(string.ascii_lowercase, k=5))
        self.client.get(f"/?s={q}", name="[DYNAMICKY] Random Search")
