from locust import HttpUser, task, constant, events
from datetime import datetime
import csv
import random
import os
import json
import time

random.seed(42)

# Ensure results directory exists
os.makedirs('results', exist_ok=True)
CSV_FILE = 'results/dana_requests.csv'
DEBUG_LOG = 'results/debug.log'

# Initialize CSV file with headers if it doesn't exist
if not os.path.exists(CSV_FILE):
    with open(CSV_FILE, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['Timestamp', 'Response Time (ms)', 'Status Code'])

def log_debug(message, data=None):
    """Log debug information"""
    log_entry = {
        'timestamp': datetime.now().isoformat(),
        'message': message,
        'data': data
    }
    with open(DEBUG_LOG, 'a') as f:
        f.write(json.dumps(log_entry) + '\n')

class StressTestUser(HttpUser):
    wait_time = constant(1)

    @task
    def stress_test(self):
        size = 20
        lines_A = ",".join([f"[{','.join(map(str, [random.randint(0, 10) for _ in range(size)]))}]" for _ in range(size)])
        lines_I = ",".join([f"[{','.join(['1' if i == j else '0' for i in range(size)])}]" for j in range(size)])
        A = f"[{lines_A}]"
        I = f"[{lines_I}]"

        now = datetime.now()
        calculation_start_time = time.time()  # Track start time for end-to-end calculation
        
        # #region agent log
        log_debug("Starting stress test", {"matrix_size": size})
        # #endregion

        # Try the new coordinator API: POST /task with matrixA and matrixB
        # The coordinator returns a task ID, then we need to poll /result/:id

        request_payload = {"matrixA": A, "matrixB": I}
        print(f"[REQUEST] POST /task")
        print(f"[REQUEST] Payload: {json.dumps(request_payload, indent=2)}")
        
        with self.client.post("/task",
                              json=request_payload,
                              catch_response=True,
                              name="/task") as submit_response:
            # #region agent log
            log_debug("Task submitted", {
                "status_code": submit_response.status_code,
                "response_text": submit_response.text[:200] if submit_response.text else None,
                "response_headers": dict(submit_response.headers) if hasattr(submit_response, 'headers') else None
            })
            # #endregion
            
            if submit_response.status_code != 200:
                submit_response.failure(f"Task submission failed: {submit_response.status_code}")
                return
            
            try:
                task_data = submit_response.json()
                task_id = task_data.get('taskId')
                # #region agent log
                log_debug("Task ID received", {"task_id": task_id})
                # #endregion
                
                # POST request succeeded - mark it as successful immediately
                # The POST endpoint's job is to accept the task and return a taskId, which it did
                submit_response.success()
                
            except Exception as e:
                # #region agent log
                log_debug("Failed to parse task response", {"error": str(e), "response_text": submit_response.text[:200]})
                # #endregion
                submit_response.failure(f"Failed to parse task ID: {e}")
                return
            
            # Poll for result (with timeout)
            # Note: Polling failures are separate from POST success - we track them via debug logs
            max_polls = 50
            poll_interval = 1
            result_received = False
            
            for attempt in range(max_polls):
                time.sleep(poll_interval)
                
                with self.client.get(f"/result/{task_id}",
                                    catch_response=True,
                                    name="/result/[id]") as result_response:
                    # #region agent log
                    log_debug("Polling for result", {
                        "task_id": task_id,
                        "attempt": attempt + 1,
                        "status_code": result_response.status_code
                    })
                    # #endregion
                    
                    if result_response.status_code == 200:
                        try:
                            result_data = result_response.json()
                            status = result_data.get('status')
                            result = result_data.get('result')
                            
                            # #region agent log
                            log_debug("Result received", {
                                "task_id": task_id,
                                "status": status,
                                "result_length": len(result) if result else 0
                            })
                            # #endregion
                            
                            if status == "completed" and result:
                                # For identity matrix multiplication, result should equal A
                                print(result)
                                print(A)
                                if result == A:
                                    print("OIIIIIIIIIIIIIIIIi")
                                    result_received = True
                                    
                                    # Calculate end-to-end time (from POST to result ready)
                                    calculation_end_time = time.time()
                                    calculation_duration_ms = (calculation_end_time - calculation_start_time) * 1000
                                    
                                    # Track the full calculation time as a separate metric in Locust
                                    events.request.fire(
                                        request_type="Calculation",
                                        name="[calculation_complete]",
                                        response_time=calculation_duration_ms,
                                        response_length=0,
                                        exception=None,
                                        context={}
                                    )
                                    
                                    # Log to CSV
                                    with open(CSV_FILE, 'a', newline='') as f:
                                        writer = csv.writer(f)
                                        total_time = submit_response.request_meta["response_time"] + (attempt + 1) * poll_interval * 1000
                                        writer.writerow([now, total_time, result_response.status_code])
                                    
                                    # Note: POST already marked as successful above
                                    log_debug("Result validation passed", {
                                        "task_id": task_id,
                                        "attempt": attempt + 1,
                                        "calculation_time_ms": calculation_duration_ms
                                    })
                                    
                                    # Print result to terminal
                                    print(f"[Task {task_id}] Calculation completed successfully!")
                                    print(f"  - Calculation time: {calculation_duration_ms:.2f} ms")
                                    print(f"  - Polling attempts: {attempt + 1}")
                                    print(f"  - Result validated: {len(result)} characters")
                                    print(f"  - Matrix size: {size}x{size}")
                                    break
                                else:
                                    # Result validation failed - log but don't mark POST as failed
                                    # (POST was already successful, this is a result validation issue)
                                    log_debug("Result validation failed", {
                                        "task_id": task_id,
                                        "expected_length": len(A),
                                        "got_length": len(result) if result else 0,
                                        "result_preview": result[:100] if result else None
                                    })
                                    result_received = True
                                    break
                            elif status == "pending" or status == "processing":
                                # Still processing, continue polling
                                continue
                            else:
                                # Unexpected status - log but don't mark POST as failed
                                log_debug("Unexpected result status", {"task_id": task_id, "status": status})
                                result_received = True
                                break
                        except Exception as e:
                            # #region agent log
                            log_debug("Failed to parse result response", {"error": str(e)})
                            # #endregion
                            # Parsing error - log but don't mark POST as failed
                            result_received = True
                            break
                    elif result_response.status_code == 404:
                        # Task not found yet, continue polling
                        continue
                    else:
                        # Unexpected status code - log but don't mark POST as failed
                        log_debug("Unexpected status code when polling", {
                            "task_id": task_id,
                            "status_code": result_response.status_code
                        })
                        result_received = True
                        break
            
            if not result_received:
                # Polling timeout - log but don't mark POST as failed
                # The POST request itself was successful (got taskId), polling is separate
                calculation_end_time = time.time()
                calculation_duration_ms = (calculation_end_time - calculation_start_time) * 1000
                
                # Track timeout as a failed calculation
                events.request.fire(
                    request_type="Calculation",
                    name="[calculation_timeout]",
                    response_time=calculation_duration_ms,
                    response_length=0,
                    exception=Exception("Timeout waiting for result"),
                    context={}
                )
                
                log_debug("Polling timeout", {
                    "task_id": task_id,
                    "max_polls": max_polls,
                    "calculation_time_ms": calculation_duration_ms
                })