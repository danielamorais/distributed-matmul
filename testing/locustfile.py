from locust import HttpUser, task, between

class StressTestUser(HttpUser):
    wait_time = between(1, 2.5)

    @task
    def stress_test(self):
        self.client.post("http://localhost:8080/matmul", {
            "A": "[[1, 2, 3], [4, 5, 6], [7, 8, 9]]",
            "B": "[[1, 0, 0], [0, 1, 0], [0, 0, 1]]"
        })