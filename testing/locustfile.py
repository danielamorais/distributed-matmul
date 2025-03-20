from locust import HttpUser, task, between
import csv
import random

class StressTestUser(HttpUser):
    wait_time = between(1, 3)

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
            # Log to CSV
            with open('results/dana_requests.csv', 'a', newline='') as f:
                writer = csv.writer(f)
                writer.writerow([
                    response.request_meta["name"],
                    response.request_meta["response_time"],
                    response.status_code
                ])

            if response.text == A:
                response.success()
            else:
                response.failure("Wrong response")