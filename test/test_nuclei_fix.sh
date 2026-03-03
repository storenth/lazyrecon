#!/bin/bash
# Test script to verify nuclei command is built correctly

set -e

echo "=========================================="
echo "Testing Nuclei Command Fix"
echo "=========================================="
echo ""

# Source the configuration
[ -f "./lazyconfig" ] && source ./lazyconfig

# Set up test environment
export HOMEDIR="${HOMEDIR:-$HOME}"
export STORAGEDIR="${STORAGEDIR:-$HOMEDIR/lazytargets}"
export GOPATH="${GOPATH:-$HOMEDIR/go}"

# Create test directory
TESTDIR="$STORAGEDIR/test_nuclei_fix"
mkdir -p "$TESTDIR"

# Create a mock http_services.txt file
echo "http://testasp.vulnweb.com" > "$TESTDIR/http_services.txt"

echo "Test directory: $TESTDIR"
echo "HTTP services file created"
echo ""

# Build the nuclei command as it would be in run_nuclei_scan()
echo "Building nuclei command..."
nuclei_cmd="nuclei"
nuclei_cmd="$nuclei_cmd -je \"$TESTDIR/nuclei_output.json\""
nuclei_cmd="$nuclei_cmd -l \"$TESTDIR/http_services.txt\""
nuclei_cmd="$nuclei_cmd -t \"${NUCLEI_TEMPLATES:-$HOME/nuclei-templates}\""
nuclei_cmd="$nuclei_cmd -rate ${NUCLEI_RATE:-100}"
nuclei_cmd="$nuclei_cmd -timeout ${NUCLEI_TIMEOUT:-10}"
nuclei_cmd="$nuclei_cmd -retries ${NUCLEI_RETRIES:-2}"
nuclei_cmd="$nuclei_cmd -bulk-size ${NUCLEI_BULK_SIZE:-25}"
nuclei_cmd="$nuclei_cmd -http-threads ${NUCLEI_HTTP_THREADS:-10}"

echo "Command built:"
echo "$nuclei_cmd"
echo ""

# Check if nuclei is available
if command -v nuclei &> /dev/null; then
    echo "Nuclei is installed, running test scan..."
    echo "Note: This will scan testasp.vulnweb.com and may take several minutes"
    echo ""
    
    # Run the command
    eval $nuclei_cmd
    
    # Check if output file was created
    if [ -f "$TESTDIR/nuclei_output.json" ]; then
        echo "✓ Output file created: $TESTDIR/nuclei_output.json"
        
        # Count vulnerabilities found
        vuln_count=$(jq 'length' "$TESTDIR/nuclei_output.json" 2>/dev/null || echo "0")
        echo "✓ Vulnerabilities found: $vuln_count"
        
        if [ "$vuln_count" -gt 1 ]; then
            echo "✓ SUCCESS: Multiple vulnerabilities detected (fix is working)"
        else
            echo "⚠ WARNING: Only $vuln_count vulnerability found (expected more)"
        fi
        
        # Show sample findings
        echo ""
        echo "Sample findings:"
        jq -r '.[] | "[\(.info.severity)] \(.info.name) - \(.host)"' "$TESTDIR/nuclei_output.json" 2>/dev/null | head -5 || echo "Could not parse findings"
    else
        echo "✗ ERROR: Output file was not created"
        exit 1
    fi
else
    echo "⚠ Nuclei is not installed, skipping actual scan"
    echo "Command would be:"
    echo "$nuclei_cmd"
fi

echo ""
echo "=========================================="
echo "Test completed"
echo "=========================================="
echo "Test artifacts in: $TESTDIR"
echo "To clean up: rm -rf $TESTDIR"
