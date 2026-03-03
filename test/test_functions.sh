#!/bin/bash
# Test individual functions from lazyrecon.sh

echo "Testing detect_type function..."

# Extract and test detect_type function
detect_type() {
  local input="$1"
  if [[ "$input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
    echo "cidr"
  elif [[ "$input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ip"
  else
    echo "hostname"
  fi
}

# Test cases
echo "Test 1: IP address (8.8.8.8)"
result=$(detect_type "8.8.8.8")
if [ "$result" = "ip" ]; then
    echo "  ✓ PASSED: Detected as 'ip'"
else
    echo "  ✗ FAILED: Expected 'ip', got '$result'"
fi

echo "Test 2: CIDR block (192.168.1.0/24)"
result=$(detect_type "192.168.1.0/24")
if [ "$result" = "cidr" ]; then
    echo "  ✓ PASSED: Detected as 'cidr'"
else
    echo "  ✗ FAILED: Expected 'cidr', got '$result'"
fi

echo "Test 3: Hostname (example.com)"
result=$(detect_type "example.com")
if [ "$result" = "hostname" ]; then
    echo "  ✓ PASSED: Detected as 'hostname'"
else
    echo "  ✗ FAILED: Expected 'hostname', got '$result'"
fi

echo "Test 4: Another hostname (subdomain.example.org)"
result=$(detect_type "subdomain.example.org")
if [ "$result" = "hostname" ]; then
    echo "  ✓ PASSED: Detected as 'hostname'"
else
    echo "  ✗ FAILED: Expected 'hostname', got '$result'"
fi

echo "Test 5: CIDR with different mask (10.0.0.0/8)"
result=$(detect_type "10.0.0.0/8")
if [ "$result" = "cidr" ]; then
    echo "  ✓ PASSED: Detected as 'cidr'"
else
    echo "  ✗ FAILED: Expected 'cidr', got '$result'"
fi

echo ""
echo "All detect_type tests completed!"
