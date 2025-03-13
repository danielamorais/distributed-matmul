from locust import HttpUser, task, between
import random

class StressTestUser(HttpUser):
    wait_time = between(1, 2.5)

    @task
    def stress_test(self):
        size = 4
        lines_A = ",".join([f"[{','.join(map(str, [random.randint(0, 10) for _ in range(size)]))}]" for _ in range(size)])
        lines_I = ",".join([f"[{','.join(['1' if i == j else '0' for i in range(size)])}]" for j in range(size)])
        A = f"[{lines_A}]"
        I = f"[{lines_I}]"

        with self.client.post("/matmul",
                              json={"A": A, "B": I},
                              catch_response=True) as response:

            if response.text == A:
                response.success()
            else:
                response.failure("Wrong response")