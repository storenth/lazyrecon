#!/bin/bash
# Test script to verify live hosts count fix

set -e

echo "Testing live hosts count fix..."

# Create a temporary test directory
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Create test data matching the issue scenario
cat > "$TEST_DIR/live_hosts_ports.txt" << 'EOF'
44.238.29.244:53
44.238.29.244:80
EOF

# Test the old method (would return 0)
echo "Testing old method (counting live_ips.txt):"
if [ -f "$TEST_DIR/live_ips.txt" ]; then
    OLD_COUNT=$(wc -l < "$TEST_DIR/live_ips.txt" 2>/dev/null || echo 0)
else
    OLD_COUNT=0
fi
echo "  Old method result: $OLD_COUNT"

# Test the new method (should return 1)
echo "Testing new method (counting unique IPs from live_hosts_ports.txt):"
NEW_COUNT=$(cut -d: -f1 "$TEST_DIR/live_hosts_ports.txt" 2>/dev/null | sort -u | wc -l || echo 0)
echo "  New method result: $NEW_COUNT"

# Verify the fix
if [ "$NEW_COUNT" -eq 1 ]; then
    echo "✓ PASS: Live hosts count is correct (1 unique IP)"
else
    echo "✗ FAIL: Live hosts count is incorrect (expected 1, got $NEW_COUNT)"
    exit 1
fi

# Test with multiple IPs
echo ""
echo "Testing with multiple IPs..."
cat > "$TEST_DIR/live_hosts_ports.txt" << 'EOF'
44.238.29.244:53
44.238.29.244:80
192.168.1.1:22
192.168.1.1:80
10.0.0.1:443
EOF

NEW_COUNT=$(cut -d: -f1 "$TEST_DIR/live_hosts_ports.txt" 2>/dev/null | sort -u | wc -l || echo 0)
echo "  Unique IPs: $NEW_COUNT"

if [ "$NEW_COUNT" -eq 3 ]; then
    echo "✓ PASS: Live hosts count is correct (3 unique IPs)"
else
    echo "✗ FAIL: Live hosts count is incorrect (expected 3, got $NEW_COUNT)"
    exit 1
fi

# Test with empty file
echo ""
echo "Testing with empty file..."
> "$TEST_DIR/live_hosts_ports.txt"
NEW_COUNT=$(cut -d: -f1 "$TEST_DIR/live_hosts_ports.txt" 2>/dev/null | sort -u | wc -l || echo 0)
echo "  Unique IPs: $NEW_COUNT"

if [ "$NEW_COUNT" -eq 0 ]; then
    echo "✓ PASS: Live hosts count is correct (0 unique IPs for empty file)"
else
    echo "✗ FAIL: Live hosts count is incorrect (expected 0, got $NEW_COUNT)"
    exit 1
fi

echo ""
echo "All tests passed! ✓"
