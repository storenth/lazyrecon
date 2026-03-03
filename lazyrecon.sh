#!/bin/bash
set -eE
set -m

# LazyRecon - Simplified Reconnaissance Tool
# Supports: hostname, IP, or CIDR input
# Tools: mapcidr, massdns, naabu, nuclei

# Source configuration
[ -f "./lazyconfig" ] && source ./lazyconfig

# Ensure HOMEDIR and STORAGEDIR are set
export HOMEDIR="${HOMEDIR:-$HOME}"
export STORAGEDIR="${STORAGEDIR:-$HOMEDIR/lazytargets}"
export GOPATH="${GOPATH:-$HOMEDIR/go}"

# Validate required variables
: "${HOMEDIR:?HOMEDIR not set in lazyconfig}"
: "${STORAGEDIR:?STORAGEDIR not set in lazyconfig}"
: "${GOPATH:?GOPATH not set in lazyconfig}"

mkdir -p "$STORAGEDIR"

# Set PATH for Go tools
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin:$GOROOT/bin:$HOME/.local/bin:$HOME/go/bin:$HOMEDIR/go/bin

# Configuration
MINIRESOLVERS=./resolvers/mini_resolvers.txt
PID_NUCLEI=
TARGETDIR=
target_type=""
target_value=""

# Detect input type: IP, CIDR, or hostname
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

# Prepare targets based on input type
prepare_targets() {
  echo "[$(date +%H:%M:%S)] Preparing targets..."
  if [[ "$target_type" == "ip" ]]; then
    echo "$target_value" > "$TARGETDIR/ips.txt"
  elif [[ "$target_type" == "cidr" ]]; then
    mapcidr -silent -cidr "$target_value" -o "$TARGETDIR/ips.txt"
  else
    echo "$target_value" > "$TARGETDIR/targets.txt"
    # Note: massdns does NOT support rate limiting or timeout flags
    # Only resolvers can be configured
    massdns -r "${MASSDNS_RESOLVERS:-./resolvers/mini_resolvers.txt}" -q -o S "$TARGETDIR/targets.txt" | awk '/A/{print $3}' > "$TARGETDIR/ips.txt"
  fi
  echo "[$(date +%H:%M:%S)] Targets prepared: $(wc -l < "$TARGETDIR/ips.txt") IPs"
}

# Check resource usage (CPU and RAM)
check_resource_usage() {
  local cpu=$(ps -A -o %cpu | awk '{s+=$1} END {print s}')
  local mem=$(ps -A -o %mem | awk '{s+=$1} END {print s}')
  echo "[$(date +%H:%M:%S)] Resource usage - CPU: ${cpu}%, RAM: ${mem}%"
  if (( $(echo "$cpu > 80" | bc -l 2>/dev/null || echo 0) )) || (( $(echo "$mem > 80" | bc -l 2>/dev/null || echo 0) )); then
    echo "[$(date +%H:%M:%S)] Warning: High resource usage detected"
  fi
}


# Find live hosts and scan ports
check_live_hosts() {
  # For hostnames: DNS resolution already proves host exists, skip ping scan
  # For IPs/CIDR: Use ping scan to verify hosts are alive
  if [[ "$target_type" == "hostname" ]]; then
    echo "[$(date +%H:%M:%S)] [naabu] Scanning ports (hostname resolved, skipping ping)..."
    check_resource_usage
    # Direct port scan on IPs from DNS resolution
    naabu -silent -rate ${NAABU_PORT_RATE:-100} -timeout ${NAABU_PORT_TIMEOUT:-5}s -retries ${NAABU_PORT_RETRIES:-2} -c ${NAABU_PORT_CONCURRENT:-100} -top-ports ${NAABU_TOP_PORTS:-1000} -list "$TARGETDIR/ips.txt" -o "$TARGETDIR/live_hosts_ports.txt"
    echo "[$(date +%H:%M:%S)] [naabu] Found $(wc -l < "$TARGETDIR/live_hosts_ports.txt") open ports"
  else
    # For IPs and CIDR: First ping to verify hosts are alive
    echo "[$(date +%H:%M:%S)] [naabu] Checking live hosts..."
    check_resource_usage
    naabu -silent -ping -rate ${NAABU_PING_RATE:-1000} -timeout ${NAABU_PING_TIMEOUT:-5}s -retries ${NAABU_PING_RETRIES:-2} -list "$TARGETDIR/ips.txt" -o "$TARGETDIR/live_ips.txt"
    
    if [ -s "$TARGETDIR/live_ips.txt" ]; then
      echo "[$(date +%H:%M:%S)] [naabu] Found $(wc -l < "$TARGETDIR/live_ips.txt") live hosts"
      echo "[$(date +%H:%M:%S)] [naabu] Scanning ports..."
      check_resource_usage
      naabu -silent -rate ${NAABU_PORT_RATE:-100} -timeout ${NAABU_PORT_TIMEOUT:-5}s -retries ${NAABU_PORT_RETRIES:-2} -c ${NAABU_PORT_CONCURRENT:-100} -top-ports ${NAABU_TOP_PORTS:-1000} -list "$TARGETDIR/live_ips.txt" -o "$TARGETDIR/live_hosts_ports.txt"
      echo "[$(date +%H:%M:%S)] [naabu] Found $(wc -l < "$TARGETDIR/live_hosts_ports.txt") open ports"
    else
      echo "[$(date +%H:%M:%S)] [naabu] No live hosts found"
      touch "$TARGETDIR/live_hosts_ports.txt"
    fi
  fi
}

# Check for HTTP services using httpx
checkhttprobe() {
  echo "[$(date +%H:%M:%S)] [httpx] Checking for HTTP services..."
  
  # For hostname targets: check HTTP services on the original hostname
  if [[ "$target_type" == "hostname" ]]; then
    if [ -s "$TARGETDIR/targets.txt" ]; then
      check_resource_usage
      # Use httpx to detect HTTP/HTTPS services
      # httpx automatically checks both http and https with additional features
      httpx -silent -status-code -title -timeout ${HTTPX_TIMEOUT:-5} -retries ${HTTPX_RETRIES:-2} -threads ${HTTPX_CONCURRENCY:-20} -l "$TARGETDIR/targets.txt" -o "$TARGETDIR/http_services.txt"
      
      if [ -s "$TARGETDIR/http_services.txt" ]; then
        echo "[$(date +%H:%M:%S)] [httpx] Found $(wc -l < "$TARGETDIR/http_services.txt") HTTP services"
      else
        echo "[$(date +%H:%M:%S)] [httpx] No HTTP services found"
        touch "$TARGETDIR/http_services.txt"
      fi
    else
      echo "[$(date +%H:%M:%S)] [httpx] No targets to check"
      touch "$TARGETDIR/http_services.txt"
    fi
  else
    # For IP/CIDR targets: httpx can check HTTP services on IPs
    if [ -s "$TARGETDIR/ips.txt" ]; then
      check_resource_usage
      httpx -silent -status-code -title -timeout ${HTTPX_TIMEOUT:-5} -retries ${HTTPX_RETRIES:-2} -threads ${HTTPX_CONCURRENCY:-20} -l "$TARGETDIR/ips.txt" -o "$TARGETDIR/http_services.txt"
      
      if [ -s "$TARGETDIR/http_services.txt" ]; then
        echo "[$(date +%H:%M:%S)] [httpx] Found $(wc -l < "$TARGETDIR/http_services.txt") HTTP services"
      else
        echo "[$(date +%H:%M:%S)] [httpx] No HTTP services found"
        touch "$TARGETDIR/http_services.txt"
      fi
    else
      echo "[$(date +%H:%M:%S)] [httpx] No IPs to check"
      touch "$TARGETDIR/http_services.txt"
    fi
  fi
}

# Run nuclei vulnerability scan
run_nuclei_scan() {
  if [ -s "$TARGETDIR/http_services.txt" ]; then
    echo "[$(date +%H:%M:%S)] [nuclei] Starting vulnerability scan..."
    # Use HTTP services discovered by httpx (already have proper protocol prefixes)
    # This ensures nuclei only scans actual HTTP/HTTPS services, not SSH or other ports
    check_resource_usage

    cut -f1 -d ' ' $TARGETDIR/http_services.txt | nuclei -je $TARGETDIR/nuclei_output.json 

    PID_NUCLEI=$!
    wait $PID_NUCLEI
    echo "[$(date +%H:%M:%S)] [nuclei] Scan completed"
  else
    echo "[$(date +%H:%M:%S)] [nuclei] No HTTP services to scan"
    echo "[]" > "$TARGETDIR/nuclei_output.json"
  fi
}

# Generate JSON report for FastAPI
generate_json_report() {
  echo "[$(date +%H:%M:%S)] Generating JSON report..."
  local start_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local end_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  # Read results or use empty arrays
  local nuclei_results="[]"
  [ -s "$TARGETDIR/nuclei_output.json" ] && nuclei_results=$(cat "$TARGETDIR/nuclei_output.json")
  
  local portscan_results="[]"
  if [ -s "$TARGETDIR/live_hosts_ports.txt" ]; then
    portscan_results=$(jq -R -s -c 'split("\n") | map(select(length > 0) | split(":") | {host: .[0], port: .[1]})' "$TARGETDIR/live_hosts_ports.txt")
  fi
  
  local http_services="[]"
  if [ -s "$TARGETDIR/http_services.txt" ]; then
    http_services=$(jq -R -s -c 'split("\n") | map(select(length > 0))' "$TARGETDIR/http_services.txt")
  fi
  
  local errors="[]"
  [ -s "$TARGETDIR/errors.json" ] && errors=$(cat "$TARGETDIR/errors.json")
  
  # Build unified report
  jq -n --argjson nuclei "$nuclei_results" \
        --argjson ports "$portscan_results" \
        --argjson http_services "$http_services" \
        --arg start_time "$start_time" \
        --arg end_time "$end_time" \
        --arg target "$target_value" \
        --argjson errors "$errors" '{
    metadata: {
      target: $target,
      start_time: $start_time,
      end_time: $end_time,
      status: "completed"
    },
    results: {
      nuclei: $nuclei,
      ports: $ports,
      http_services: $http_services
    },
    errors: $errors
  }' > "$TARGETDIR/report.json"
  
  echo "[$(date +%H:%M:%S)] JSON report generated at $TARGETDIR/report.json"
}

# Generate human-readable TXT report
generate_txt_report() {
  echo "[$(date +%H:%M:%S)] Generating TXT report..."
  local report_file="$TARGETDIR/report.txt"
  
  {
    echo "=========================================="
    echo "       LazyRecon Scan Report"
    echo "=========================================="
    echo "Target: $target_value | Type: $target_type"
    echo "Scan Date: $(date)"
    echo ""
    echo "HTTP Services:"
    if [ -s "$TARGETDIR/http_services.txt" ]; then
      cat "$TARGETDIR/http_services.txt"
    else
      echo "No HTTP services found"
    fi
    echo ""
    echo "Live Hosts & Ports:"
    if [ -s "$TARGETDIR/live_hosts_ports.txt" ]; then
      cat "$TARGETDIR/live_hosts_ports.txt"
    else
      echo "No live hosts found"
    fi
    echo ""
    echo "Vulnerability Findings:"
    if [ -s "$TARGETDIR/nuclei_output.json" ]; then
      local vuln_count=$(jq 'length' "$TARGETDIR/nuclei_output.json")
      echo "Total vulnerabilities found: $vuln_count"
      jq -r '.[] | "\n[Severity: \(.info.severity)] \(.info.name)\n  Host: \(.host)\n  Template: \(.["template-id"])"' "$TARGETDIR/nuclei_output.json" 2>/dev/null || echo "No vulnerabilities found"
    else
      echo "No vulnerabilities found"
    fi
    echo ""
    echo "Summary:"
    echo "  HTTP services: $(wc -l < "$TARGETDIR/http_services.txt" 2>/dev/null || echo 0)"
    echo "  Live hosts: $(cut -d: -f1 "$TARGETDIR/live_hosts_ports.txt" 2>/dev/null | sort -u | wc -l || echo 0)"
    echo "  Open ports: $(wc -l < "$TARGETDIR/live_hosts_ports.txt" 2>/dev/null || echo 0)"
    echo "  Vulnerabilities: $(jq 'length' "$TARGETDIR/nuclei_output.json" 2>/dev/null || echo 0)"
    echo ""
    echo "Report directory: $TARGETDIR"
    echo "=========================================="
  } > "$report_file"
  
  echo "[$(date +%H:%M:%S)] TXT report generated at $report_file"
}

# Error handler
error_handler() {
  echo "[ERROR]: LINENO=${LINENO}, SOURCE=$(caller)"
  local err_msg="[ERROR]: $(basename $0): ${FUNCNAME} ${LINENO} ${BASH_LINENO[@]}"
  echo "$err_msg"
  [[ -n "$TARGETDIR" ]] && jq -n --arg error "$err_msg" '[{"timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'", "error": $error}]' > "$TARGETDIR/errors.json"
  [[ -n "$PID_NUCLEI" ]] && kill -9 $PID_NUCLEI &>/dev/null || true
  exit 1
}

# Cleanup on exit
cleanup() {
  [[ -n "$PID_NUCLEI" ]] && kill -9 $PID_NUCLEI &>/dev/null || true
}

# Trap errors and exit
trap error_handler ERR
trap cleanup EXIT

# Main function
main() {
  [[ $# -eq 0 ]] && { echo "Error: expected target argument"; echo "Usage: $0 <hostname|IP|CIDR>"; exit 1; }
  
  target_value="$1"
  target_type=$(detect_type "$target_value")
  
  echo "=========================================="
  echo "       LazyRecon - Simplified Recon"
  echo "=========================================="
  echo "Target: $target_value | Type: $target_type"
  echo "=========================================="
  echo ""
  
  # Create target directory
  foldername="recon-$(date +"%y-%m-%d_%H-%M-%S")"
  TARGETDIR="$STORAGEDIR/$target_value/$foldername"
  mkdir -p "$TARGETDIR"
  
  # Run minimal pipeline
  prepare_targets
  check_live_hosts
  checkhttprobe
  run_nuclei_scan
  generate_json_report
  generate_txt_report
  
  echo ""
  echo "=========================================="
  echo "       Scan Completed Successfully"
  echo "=========================================="
  echo "Results saved to: $TARGETDIR"
  echo "  - report.json (structured)"
  echo "  - report.txt (human-readable)"
  echo "=========================================="
}

# Run main
main "$@"
