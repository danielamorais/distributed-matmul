#!/bin/bash

# Test script for Dana Coordinator Server
# Tests all endpoints to ensure they work correctly

COORDINATOR_URL="http://localhost:8080"
COORDINATOR_HOST="localhost:8080"

echo "═══════════════════════════════════════════════════════════"
echo "🧪 Testing Dana Coordinator Server"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Coordinator URL: $COORDINATOR_URL"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to test an endpoint
test_endpoint() {
    local name=$1
    local method=$2
    local path=$3
    local data=$4
    local expected_status=$5
    
    echo -n "Testing $name... "
    
    if [ -z "$data" ]; then
        response=$(echo -e "$method $path HTTP/1.1\r\nHost: $COORDINATOR_HOST\r\n\r\n" | nc -w 2 localhost 8080 2>/dev/null)
    else
        content_length=${#data}
        response=$(echo -e "$method $path HTTP/1.1\r\nHost: $COORDINATOR_HOST\r\nContent-Type: application/json\r\nContent-Length: $content_length\r\n\r\n$data" | nc -w 2 localhost 8080 2>/dev/null)
    fi
    
    if [ -z "$response" ]; then
        echo -e "${RED}FAILED${NC} (no response)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    
    # Check HTTP status
    status_line=$(echo "$response" | head -n 1)
    if echo "$status_line" | grep -q "$expected_status"; then
        echo -e "${GREEN}PASSED${NC}"
        echo "$response" | head -n 5
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAILED${NC} (expected $expected_status, got: $status_line)"
        echo "$response" | head -n 5
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Check if coordinator is running
echo "Checking if coordinator is running..."
if ! echo -e "GET /health HTTP/1.1\r\nHost: $COORDINATOR_HOST\r\n\r\n" | nc -w 2 localhost 8080 > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Coordinator is not running on port 8080${NC}"
    echo ""
    echo "Please start the coordinator first:"
    echo "  dana CoordinatorApp.o 8080"
    exit 1
fi
echo -e "${GREEN}Coordinator is running${NC}"
echo ""

# Run tests
echo "═══════════════════════════════════════════════════════════"
echo "Running Tests"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Test 1: Health check
test_endpoint "Health Check" "GET" "/health" "" "200"

# Test 2: Stats (should work even with no tasks)
test_endpoint "Stats (empty)" "GET" "/stats" "" "200"

# Test 3: Submit a task
TASK_DATA='{"A":"[[1,2],[3,4]]","B":"[[5,6],[7,8]]"}'
test_endpoint "Submit Task" "POST" "/task" "$TASK_DATA" "200"

# Extract task ID from response (if available)
TASK_ID=1  # Default, will be updated if we can parse response

# Test 4: Get next task (should return the task we just submitted)
test_endpoint "Get Next Task" "GET" "/task/next?workerId=test-worker" "" "200"

# Test 5: Submit result
RESULT_DATA='{"result":"[[19,22],[43,50]]"}'
test_endpoint "Submit Result" "POST" "/task/1/result" "$RESULT_DATA" "200"

# Test 6: Get result
test_endpoint "Get Result" "GET" "/result/1" "" "200"

# Test 7: Stats (should show completed task)
test_endpoint "Stats (with tasks)" "GET" "/stats" "" "200"

# Test 8: Get result for non-existent task
test_endpoint "Get Result (404)" "GET" "/result/999" "" "404"

# Test 9: OPTIONS (CORS preflight)
test_endpoint "OPTIONS (CORS)" "OPTIONS" "/task" "" "200"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Test Results"
echo "═══════════════════════════════════════════════════════════"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi

