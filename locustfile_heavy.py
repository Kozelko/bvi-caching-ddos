from locust import HttpUser, task, constant

class DynamicBuyer(HttpUser):
    wait_time = constant(0) # Žiadne čakanie, maximálny tlak na server

    @task(3)
    def add_to_cart(self):
        self.client.get("/?add-to-cart=1", name="[DYNAMICKY] Add to Cart")
        
    @task(2)
    def view_cart(self):
        self.client.get("/cart/", name="[DYNAMICKY] View Cart")

    @task(1)
    def checkout(self):
        self.client.get("/checkout/", name="[DYNAMICKY] Checkout")
