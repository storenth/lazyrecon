#!/bin/bash
# Comprehensive test suite for lazyrecon.sh

set -e

echo "=========================================="
echo "  LazyRecon Test Suite"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "[$TESTS_RUN] Testing: $test_name ... "
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test 1: Script syntax
echo "=== 1. Script Syntax and Structure ==="
run_test "Bash syntax check" "bash -n lazyrecon.sh"
run_test "Script is executable" "test -x lazyrecon.sh"
run_test "lazyconfig exists" "test -f lazyconfig"
run_test "resolvers file exists" "test -f resolvers/mini_resolvers.txt"
echo ""

# Test 2: Tool dependencies
echo "=== 2. Tool Dependencies ==="
run_test "mapcidr is available" "which mapcidr"
run_test "massdns is available" "which massdns"
run_test "naabu is available" "which naabu"
run_test "nuclei is available" "which nuclei"
run_test "jq is available" "which jq"
run_test "bc is available" "which bc"
echo ""

# Test 3: Input type detection
echo "=== 3. Input Type Detection ==="
run_test "Detect IP address" "bash -c 'source lazyrecon.sh 2>/dev/null; [[ \$(detect_type \"8.8.8.8\") == \"ip\" ]]'"
run_test "Detect CIDR block" "bash -c 'source lazyrecon.sh 2>/dev/null; [[ \$(detect_type \"192.168.1.0/24\") == \"cidr\" ]]'"
run_test "Detect hostname" "bash -c 'source lazyrecon.sh 2>/dev/null; [[ \$(detect_type \"example.com\") == \"hostname\" ]]'"
echo ""

# Test 4: Configuration loading
echo "=== 4. Configuration Loading ==="
run_test "lazyconfig is valid bash" "bash -n lazyconfig"
run_test "HOMEDIR variable set" "bash -c 'source lazyconfig 2>/dev/null; [[ -n \"\$HOMEDIR\" || -n \"\$HOME\" ]]'"
run_test "STORAGEDIR variable set" "bash -c 'source lazyconfig 2>/dev/null; [[ -n \"\$STORAGEDIR\" ]]'"
run_test "GOPATH variable set" "bash -c 'source lazyconfig 2>/dev/null; [[ -n \"\$GOPATH\" ]]'"
echo ""

# Test 5: Function definitions
echo "=== 5. Function Definitions ==="
run_test "detect_type function defined" "bash -c 'source lazyrecon.sh 2>/dev/null; declare -f detect_type'"
run_test "prepare_targets function defined" "bash -c 'source lazyrecon.sh 2>/dev/null; declare -f prepare_targets'"
run_test "check_resource_usage function defined" "bash -c 'source lazyrecon.sh 2>/dev/null; declare -f check_resource_usage'"
run_test "check_live_hosts function defined" "bash -c 'source lazyrecon.sh 2>/dev/null; declare -f check_live_hosts'"
run_test "run_nuclei_scan function defined" "bash -c 'source lazyrecon.sh 2>/dev/null; declare -f run_nuclei_scan'"
run_test "generate_json_report function defined" "bash -c 'source lazyrecon.sh 2>/dev/null; declare -f generate_json_report'"
run_test "generate_txt_report function defined" "bash -c 'source lazyrecon.sh 2>/dev/null; declare -f generate_txt_report'"
run_test "error_handler function defined" "bash -c 'source lazyrecon.sh 2>/dev/null; declare -f error_handler'"
run_test "cleanup function defined" "bash -c 'source lazyrecon.sh 2>/dev/null; declare -f cleanup'"
echo ""

# Test 6: Error handling setup
echo "=== 6. Error Handling Setup ==="
run_test "set -eE is set" "grep -q 'set -eE' lazyrecon.sh"
run_test "set -m is set" "grep -q 'set -m' lazyrecon.sh"
run_test "trap error_handler ERR" "grep -q 'trap error_handler ERR' lazyrecon.sh"
run_test "trap cleanup EXIT" "grep -q 'trap cleanup EXIT' lazyrecon.sh"
echo ""

# Test 7: Variable initialization
echo "=== 7. Variable Initialization ==="
run_test "MINIRESOLVERS variable set" "grep -q 'MINIRESOLVERS=' lazyrecon.sh"
run_test "PID_NUCLEI variable initialized" "grep -q 'PID_NUCLEI=' lazyrecon.sh"
run_test "TARGETDIR variable initialized" "grep -q 'TARGETDIR=' lazyrecon.sh"
run_test "target_type variable initialized" "grep -q 'target_type=' lazyrecon.sh"
run_test "target_value variable initialized" "grep -q 'target_value=' lazyrecon.sh"
echo ""

# Test 8: Report generation structure
echo "=== 8. Report Generation Structure ==="
run_test "JSON report uses jq" "grep -q 'jq -n' lazyrecon.sh"
run_test "JSON report includes metadata" "grep -q 'metadata:' lazyrecon.sh"
run_test "JSON report includes results" "grep -q 'results:' lazyrecon.sh"
run_test "JSON report includes errors" "grep -q 'errors:' lazyrecon.sh"
run_test "TXT report includes header" "grep -q 'LazyRecon Scan Report' lazyrecon.sh"
echo ""

# Test 9: Tool command validation
echo "=== 9. Tool Command Validation ==="
run_test "mapcidr uses -silent flag" "grep -q 'mapcidr -silent' lazyrecon.sh"
run_test "massdns uses -r flag" "grep -q 'massdns -r' lazyrecon.sh"
run_test "naabu uses -silent flag" "grep -q 'naabu -silent' lazyrecon.sh"
run_test "nuclei uses -silent flag" "grep -q 'nuclei -silent' lazyrecon.sh"
run_test "nuclei uses -je flag" "grep -q 'nuclei.*-je' lazyrecon.sh"
echo ""

# Test 10: Resource monitoring
echo "=== 10. Resource Monitoring ==="
run_test "check_resource_usage checks CPU" "grep -q 'ps -A -o %cpu' lazyrecon.sh"
run_test "check_resource_usage checks RAM" "grep -q 'ps -A -o %mem' lazyrecon.sh"
run_test "Resource warning threshold set" "grep -q '80' lazyrecon.sh"
echo ""

# Summary
echo "=========================================="
echo "  Test Summary"
echo "=========================================="
echo "Total tests run: $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please review the output above.${NC}"
    exit 1
fi
