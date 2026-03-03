#!/bin/bash
# Integration tests for lazyrecon.sh
# Tests actual execution with different input types

set -e

echo "=========================================="
echo "  LazyRecon Integration Tests"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Create temporary test directory
TEST_DIR="/tmp/lazyrecon_test_$$"
mkdir -p "$TEST_DIR"
echo "Test directory: $TEST_DIR"
echo ""

# Backup original lazyconfig
cp lazyconfig lazyconfig.test_backup

# Set test storage directory while preserving other config
sed "s|^export STORAGEDIR=.*|export STORAGEDIR=$TEST_DIR|" lazyconfig > lazyconfig.test
mv lazyconfig.test lazyconfig

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
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

# Test 1: Error handling - no arguments
echo "=== 1. Error Handling Tests ==="
run_test "No arguments shows error" "./lazyrecon.sh 2>&1 | grep -q 'expected target argument'"
echo ""

# Test 2: IP address input
echo "=== 2. IP Address Input Test ==="
echo "Testing with IP: 8.8.8.8 (Google DNS)..."
./lazyrecon.sh 8.8.8.8 > /tmp/test_ip.log 2>&1 || true

# Check if scan directory was created
if [ -d "$TEST_DIR/8.8.8.8" ]; then
    echo -e "${GREEN}✓${NC} Scan directory created"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
else
    echo -e "${RED}✗${NC} Scan directory not created"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
fi

# Check for report files
LATEST_DIR=$(ls -td "$TEST_DIR/8.8.8.8"/recon-* 2>/dev/null | head -1)
if [ -n "$LATEST_DIR" ]; then
    echo "Latest scan directory: $LATEST_DIR"
    
    if [ -f "$LATEST_DIR/report.json" ]; then
        echo -e "${GREEN}✓${NC} JSON report generated"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
        
        # Validate JSON structure
        if jq empty "$LATEST_DIR/report.json" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} JSON report is valid"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            TESTS_RUN=$((TESTS_RUN + 1))
        else
            echo -e "${RED}✗${NC} JSON report is invalid"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            TESTS_RUN=$((TESTS_RUN + 1))
        fi
    else
        echo -e "${RED}✗${NC} JSON report not found"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
    
    if [ -f "$LATEST_DIR/report.txt" ]; then
        echo -e "${GREEN}✓${NC} TXT report generated"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    else
        echo -e "${RED}✗${NC} TXT report not found"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
    
    # Check for intermediate files
    if [ -f "$LATEST_DIR/ips.txt" ]; then
        echo -e "${GREEN}✓${NC} IPs file generated"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
    
    if [ -f "$LATEST_DIR/live_ips.txt" ]; then
        echo -e "${GREEN}✓${NC} Live IPs file generated"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
    
    if [ -f "$LATEST_DIR/live_hosts_ports.txt" ]; then
        echo -e "${GREEN}✓${NC} Live hosts ports file generated"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
    
    if [ -f "$LATEST_DIR/nuclei_output.json" ]; then
        echo -e "${GREEN}✓${NC} Nuclei output file generated"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
fi
echo ""

# Test 3: CIDR input (small range)
echo "=== 3. CIDR Input Test ==="
echo "Testing with CIDR: 192.0.2.0/30 (test range)..."
./lazyrecon.sh 192.0.2.0/30 > /tmp/test_cidr.log 2>&1 || true

if [ -d "$TEST_DIR/192.0.2.0/30" ]; then
    echo -e "${GREEN}✓${NC} CIDR scan directory created"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
else
    echo -e "${RED}✗${NC} CIDR scan directory not created"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
fi
echo ""

# Test 4: Hostname input
echo "=== 4. Hostname Input Test ==="
echo "Testing with hostname: example.com..."
./lazyrecon.sh example.com > /tmp/test_hostname.log 2>&1 || true

if [ -d "$TEST_DIR/example.com" ]; then
    echo -e "${GREEN}✓${NC} Hostname scan directory created"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
else
    echo -e "${RED}✗${NC} Hostname scan directory not created"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
fi
echo ""

# Test 5: Report content validation
echo "=== 5. Report Content Validation ==="
LATEST_IP_DIR=$(ls -td "$TEST_DIR/8.8.8.8"/recon-* 2>/dev/null | head -1)
if [ -n "$LATEST_IP_DIR" ] && [ -f "$LATEST_IP_DIR/report.json" ]; then
    echo "Validating JSON report structure..."
    
    # Check for required fields
    if jq -e '.metadata' "$LATEST_IP_DIR/report.json" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} metadata field exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    else
        echo -e "${RED}✗${NC} metadata field missing"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
    
    if jq -e '.results' "$LATEST_IP_DIR/report.json" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} results field exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    else
        echo -e "${RED}✗${NC} results field missing"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
    
    if jq -e '.errors' "$LATEST_IP_DIR/report.json" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} errors field exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    else
        echo -e "${RED}✗${NC} errors field missing"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
    
    # Check metadata fields
    if jq -e '.metadata.target' "$LATEST_IP_DIR/report.json" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} metadata.target exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    else
        echo -e "${RED}✗${NC} metadata.target missing"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
    
    if jq -e '.metadata.start_time' "$LATEST_IP_DIR/report.json" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} metadata.start_time exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    else
        echo -e "${RED}✗${NC} metadata.start_time missing"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
    
    if jq -e '.metadata.end_time' "$LATEST_IP_DIR/report.json" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} metadata.end_time exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    else
        echo -e "${RED}✗${NC} metadata.end_time missing"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
    
    if jq -e '.metadata.status' "$LATEST_IP_DIR/report.json" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} metadata.status exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    else
        echo -e "${RED}✗${NC} metadata.status missing"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
    
    # Check results fields
    if jq -e '.results.nuclei' "$LATEST_IP_DIR/report.json" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} results.nuclei exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    else
        echo -e "${RED}✗${NC} results.nuclei missing"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
    
    if jq -e '.results.ports' "$LATEST_IP_DIR/report.json" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} results.ports exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    else
        echo -e "${RED}✗${NC} results.ports missing"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
fi
echo ""

# Cleanup
echo "=== Cleanup ==="
mv lazyconfig.test_backup lazyconfig
rm -rf "$TEST_DIR"
echo "Test directory cleaned up"
echo ""

# Summary
echo "=========================================="
echo "  Integration Test Summary"
echo "=========================================="
echo "Total tests run: $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All integration tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}Some tests failed. Check logs in /tmp/test_*.log${NC}"
    exit 1
fi
