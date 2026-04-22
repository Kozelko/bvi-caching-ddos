from locust import HttpUser, task, constant

class WooCommerceUser(HttpUser):
    # ODSTRÁNENÁ BRZDA: Používatelia nečakajú (simulácia agresívneho DDoS útoku)
    wait_time = constant(0)

    @task(10) # 10x vyššia váha pre cache-able obsah
    def view_homepage(self):
        self.client.get("/")

    @task(5)
    def view_shop(self):
        self.client.get("/shop/")

    @task(1) # Len občasné bypass požiadavky na backend
    def add_to_cart_and_checkout(self):
        with self.client.get("/?add-to-cart=1", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
