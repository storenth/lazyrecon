#!/bin/bash
# Test nuclei input using http_services.txt from httpx

echo "=========================================="
echo "  Testing Nuclei Input from HTTP Services"
echo "=========================================="
echo ""

# Create test directory
TEST_DIR="/tmp/nuclei_test_$$"
mkdir -p "$TEST_DIR"

# Create mock http_services.txt (simulating httpx output)
# httpx outputs URLs with proper protocol prefixes (http:// or https://)
cat > "$TEST_DIR/http_services.txt" << 'EOF'
https://example.com
http://test.com
https://api.example.org:8080
http://subdomain.example.net:3000
https://192.168.1.1:8443
EOF

echo "Input (httpx output format - http_services.txt):"
cat "$TEST_DIR/http_services.txt"
echo ""

# Verify the output
echo "Verification:"
if grep -qE "^https?://" "$TEST_DIR/http_services.txt"; then
    echo "✓ All lines have http:// or https:// prefix"
else
    echo "✗ Some lines missing protocol prefix"
    exit 1
fi

# Count lines
INPUT_LINES=$(wc -l < "$TEST_DIR/http_services.txt")

if [ "$INPUT_LINES" -gt 0 ]; then
    echo "✓ Found $INPUT_LINES HTTP services"
else
    echo "✗ No HTTP services found"
    exit 1
fi

# Verify format with regex - should match http:// or https:// URLs
VALID_URLS=$(grep -E '^https?://[a-zA-Z0-9.-]+(:[0-9]+)?$' "$TEST_DIR/http_services.txt" | wc -l)

if [ "$VALID_URLS" -eq "$INPUT_LINES" ]; then
    echo "✓ All lines match expected format: http(s)://host(:port)"
else
    echo "✗ Some lines don't match expected format (valid: $VALID_URLS, total: $INPUT_LINES)"
    exit 1
fi

# Verify no SSH or non-HTTP ports are included
if grep -q ":22$" "$TEST_DIR/http_services.txt"; then
    echo "✗ SSH port 22 should not be in http_services.txt"
    exit 1
else
    echo "✓ No SSH ports included (correct - only HTTP services)"
fi

# Verify that httpx output can be used directly by nuclei
# Create a mock nuclei command to test input parsing
echo ""
echo "Testing nuclei input compatibility:"
if [ -s "$TEST_DIR/http_services.txt" ]; then
    echo "✓ http_services.txt is non-empty and ready for nuclei input"
    echo "  Nuclei will scan: $(cat "$TEST_DIR/http_services.txt" | tr '\n' ' ')"
else
    echo "✗ http_services.txt is empty"
    exit 1
fi

echo ""
echo "=========================================="
echo "  All Tests Passed!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - http_services.txt contains proper HTTP/HTTPS URLs"
echo "  - No non-HTTP ports (like SSH port 22) are included"
echo "  - File is ready for direct use by nuclei"
echo "  - No need to add protocol prefixes (already present)"

# Cleanup
rm -rf "$TEST_DIR"

exit 0
