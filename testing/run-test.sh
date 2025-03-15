#!/bin/bash
locust -f locustfile.py --headless -u 500 -r 50 -H http://localhost:8080 --run-time 5m --csv results