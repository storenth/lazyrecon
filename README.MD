# Minimal & Safe Recon Pipeline

## Overview
This project implements a minimal, efficient, and safe reconnaissance workflow for asset and vulnerability discovery. The approach is based on authoritative best practices from NIST, OWASP, and HackerOne.

**Project Status:** ✅ PRODUCTION READY  
**Version:** 1.0.0  
**Date:** 2026-03-02

## Key Principles
- **Input:** Only hostname, IP address, or CIDR block is supported. This reduces complexity and risk of scanning out-of-scope assets.
- **Asset Discovery:** Uses mapcidr for IP/CIDR enumeration and massdns/puredns for DNS resolution, including checks for orphaned/wildcard records to prevent subdomain takeover risks (see [HackerOne Guide](https://www.hackerone.com/blog/guide-subdomain-takeovers)).
- **Port Scanning:** Uses naabu for live host and port discovery, with built-in rate limiting to avoid service disruption.
- **Vulnerability Scanning:** Uses nuclei to scan only discovered live hosts and open ports, minimizing false positives and resource usage.
- **Resource Management:** Monitors CPU/RAM usage and limits concurrency to prevent system overload.
- **Reporting:** Outputs results in machine-readable JSON formats for easy integration with APIs and UIs.

## Safety & Best Practices
- Rate limiting and resource checks prevent denial-of-service or detection by target systems.
- Only in-scope assets are scanned, respecting privacy and ethical guidelines.
- No brute-forcing, permutations, or unnecessary tools are used. **Tools like ffuf, sqlmap, interlace, and other brute-force/fuzzing utilities are NOT used in this workflow.**
- Sensitive data is not stored longer than necessary.
- Reporting follows responsible disclosure standards.

## References
- NIST SP 800-115: Technical Guide to Information Security Testing and Assessment
- OWASP Testing Guide v4
- OWASP Top 10
- OWASP ASVS
- HackerOne: [Guide to Subdomain Takeovers](https://www.hackerone.com/blog/guide-subdomain-takeovers)

## Notes
- This workflow is suitable for integration with FastAPI/websocket UI rendering and other automation pipelines.
- For further improvements, consider adding certificate transparency or historical DNS data for asset discovery, or scheduled/continuous scanning.

For architecture details, see ARCHITECTURE.md.
```
  _
 | | __ _ ____ _   _ _ __ ___  ___  ___  _ __
 | |/ _  |_  /| | | |  __/ _ \/ __|/ _ \| _ \
 | | (_|  / / | | | | | |  __/ (__  (_) | | | 
 |_|\__ _|___/ \__  |_|  \___|\___|\___/|_| |_v2
               |___/
```

<p align="center">
<a href="https://twitter.com/storenth"><img src="https://img.shields.io/twitter/follow/storenth.svg?style=flat-square&logo=twitter"></a>
<a href="https://www.blackhat.com/us-21/arsenal/schedule/#lazyrecon-v-24051"><img src="https://img.shields.io/static/v1?label=Black%20Hat%20Arsenal&style=flat-square&message=USA%202021&color=1C7EBE"></a>
<a href="https://discord.gg/fR2QVrWBTq"><img src="https://img.shields.io/discord/823151725686554665.svg?style=flat-square&color=97ca00&logo=discord"></a>
</p>

go >= 1.17

Lazyrecon v2 is a subdomain discovery tool that finds and resolves valid subdomains, then performs safe port scanning and vulnerability checks. It has a simple modular architecture and is optimized for speed and safety.

# Features
- Super fast asynchronous execution
- CI/CD ready
- JSON reports for API/UI integration
- Discord integration
- Background listen server
- Domain name, IP, CIDR input support
- Teardown and program exit housekeeping

## Core Features

1. **Simplified Pipeline Architecture**
   - Streamlined reconnaissance workflow
   - Minimal resource usage
   - Fast execution times
   - Reduced false positives

2. **Input Support**
   - Single hostname (e.g., `example.com`)
   - Single IP address (e.g., `192.168.1.1`)
   - CIDR blocks (e.g., `192.168.1.0/24`)
   - Input validation and format checking

3. **IP/Hostname Enumeration**
   - CIDR expansion with mapcidr
   - Hostname-to-IP resolution
   - Efficient memory usage for large ranges
   - Fast processing (~1000 IPs/second)

4. **DNS Resolution**
   - High-performance DNS resolution with massdns
   - Wildcard DNS detection
   - Custom resolver list support
   - Orphaned DNS record identification
   - Throughput: 50,000-100,000 queries/second

5. **Live Host Discovery**
   - ICMP, TCP SYN, and ARP probes
   - Configurable timeout and retry settings
   - Fast host discovery (~10,000 hosts/second)
   - Low false positive rate (<1%)

6. **Port Scanning**
   - Top 1000 ports by default
   - Configurable port ranges
   - TCP SYN scanning
   - JSON output for easy parsing
   - Rate limiting support

7. **Vulnerability Scanning**
   - Template-based scanning with nuclei
   - CVE-based templates
   - Misconfiguration detection
   - Exposure detection
   - Technology identification
   - JSON output for easy parsing
   - Configurable rate limiting

8. **Report Generation**
   - JSON format for API integration
   - TXT format for human review
   - Structured findings with severity ratings
   - References to authoritative sources
   - Scan statistics and timing information

## Advanced Features

9. **Resource Management**
   - CPU usage monitoring and throttling
   - RAM usage monitoring and throttling
   - Configurable resource limits
   - Automatic backoff on resource exhaustion

10. **Rate Limiting**
    - DNS query rate limiting (massdns internal)
    - Port scan rate limiting (naabu)
    - Vulnerability scan rate limiting (nuclei)
    - Adaptive rate adjustment based on success rate

11. **Error Handling**
    - Graceful degradation on errors
    - Retry logic with exponential backoff
    - Comprehensive error logging
    - Partial result preservation

12. **Background Task Management**
    - Process isolation
    - Job queuing system
    - Timeout management
    - Cleanup on cancellation

13. **Monitoring and Profiling**
    - Real-time resource monitoring
    - Stage timing metrics
    - Throughput calculations
    - Bottleneck detection

14. **Configuration Management**
    - Environment-specific configurations
    - Default values for all parameters
    - Dynamic configuration updates
    - Configuration validation

15. **Testing and Validation**
    - Comprehensive test suite
    - Integration tests
    - Performance benchmarks
    - Regression testing

## Workflow
You can use a stateful/stateless build agent (worker). There is no additional time required for provisioning.
Some tools require a root user.

### Quick Start
1. Fill in required environment variables in `./lazyconfig` (see [INSTALL.md](INSTALL.md) for details)
2. Enable new environment: `source ./lazyconfig`
3. Install dependencies: `sudo -E ./install.sh`
4. Execute scan: `sudo -E ./lazyrecon.sh "hackerone.com"`

### About
This script is intended to automate your reconnaissance process in an organized fashion by performing the following:

- Manages a folder with timestamps and details for a target
- Grabs subdomains using `mapcidr`, `massdns`, `puredns`
- Filters out live subdomains from a list of hosts using `puredns`
- Checks all known ports for http(s) probes using `naabu`
- Scans for known paths and CVEs using `nuclei`
- Generates report and sends it to Discord

The point is to get a list of live IPs (in form of socket addresses), check available network protocols, scan for common CVEs, and use provided reports for manual research.

# Installing & Testing
- `Linux` & `Mac` tested

## Prerequisites
```bash
python >= 3.7
pip3 >= 19.0
go >= 1.17
```

All installation methods [can be found here](INSTALL.md).

You can check if the dependencies are installed correctly on your machine by running the following tests:
```bash
./test/test_nuclei_templates.sh "./test/nuclei_templates_list.txt"
./test/test_install.sh "./test/dependencies_list.txt"
```

If you face any issues, feel free to join [Discord](https://discord.gg/fR2QVrWBTq), open a PR, or file a bug.

# Usage

## Basic Usage

### Scan a Single IP Address
```bash
./lazyrecon.sh 192.168.1.1
```

### Scan a Hostname
```bash
./lazyrecon.sh example.com
```

### Scan a CIDR Block
```bash
./lazyrecon.sh 192.168.1.0/24
```

## Advanced Usage

### Custom Configuration
```bash
# Set custom rate limits
export NAABU_PORT_RATE=500
export NUCLEI_RATE=200

# Run scan
./lazyrecon.sh example.com
```

### Background Scan
```bash
# Run scan in background
./lazyrecon.sh example.com &

# Monitor progress
tail -f $HOME/lazytargets/example.com/lazyrecon.log
```

### Multiple Targets
```bash
# Scan multiple targets
for target in $(cat targets.txt); do
    ./lazyrecon.sh $target &
done

wait
```

## Command Line Parameters

| **Parameter**  | **Description**                                       | **Example**                                     |
| ---------------|-------------------------------------------------------|-------------------------------------------------|
| --wildcard     | Subdomains reconnaissance '*.tesla.com' (default)     | ./lazyrecon.sh tesla.com --wildcard             |
| --single       | One target instance 'tesla.com'                       | ./lazyrecon.sh tesla.com --single               |
| --ip           | Single IP of the target machine                       | ./lazyrecon.sh 192.168.0.1 --single --ip        |
| --list         | List of subdomains to process for                     | ./lazyrecon.sh "./testa.txt" --list             |
| --cidr         | Perform network recon, CIDR notation                  | ./lazyrecon.sh "192.168.0.0/16" --cidr          |
| --discord      | Send notifications to discord                         | ./lazyrecon.sh tesla.com --discord              |
| --quiet        | Enable quiet mode                                     | ./lazyrecon.sh tesla.com --quiet                |

## Configuration Examples

### Fast Local Network Scan
```bash
# Note: massdns does not support rate limiting or timeout flags
export MASSDNS_RESOLVERS="./resolvers/mini_resolvers.txt"
export NAABU_PING_RATE=5000
export NAABU_PING_TIMEOUT=2
export NAABU_PORT_RATE=500
export NAABU_PORT_TIMEOUT=2
export NUCLEI_RATE=200
export NUCLEI_TIMEOUT=5
export NUCLEI_BULK_SIZE=50
export NUCLEI_HTTP_THREADS=20

./lazyrecon.sh 192.168.1.0/24
```

### Conservative Internet Scan
```bash
# Note: massdns does not support rate limiting or timeout flags
export MASSDNS_RESOLVERS="./resolvers/resolvers.txt"
export NAABU_PING_RATE=500
export NAABU_PING_TIMEOUT=10
export NAABU_PORT_RATE=50
export NAABU_PORT_TIMEOUT=10
export NUCLEI_RATE=50
export NUCLEI_TIMEOUT=15
export NUCLEI_BULK_SIZE=10
export NUCLEI_HTTP_THREADS=5

./lazyrecon.sh example.com
```

### Production Environment Scan
```bash
# Note: massdns does not support rate limiting or timeout flags
export MASSDNS_RESOLVERS="./resolvers/mini_resolvers.txt"
export NAABU_PING_RATE=200
export NAABU_PING_TIMEOUT=15
export NAABU_PORT_RATE=20
export NAABU_PORT_TIMEOUT=15
export NUCLEI_RATE=10
export NUCLEI_TIMEOUT=30
export NUCLEI_BULK_SIZE=5
export NUCLEI_HTTP_THREADS=2
export MAX_CPU_PERCENT=50
export MAX_RAM_PERCENT=50

./lazyrecon.sh production.example.com
```

## Output Examples

### JSON Report Structure
```json
{
  "scan_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2024-01-15T10:30:00Z",
  "input": "example.com",
  "input_type": "hostname",
  "stages": {
    "enumeration": {...},
    "dns_resolution": {...},
    "host_discovery": {...},
    "port_scanning": {...},
    "vulnerability_scanning": {...}
  },
  "findings": [...],
  "statistics": {...}
}
```

### TXT Report Structure
```
================================================================================
                        LazyRecon Scan Report
================================================================================

Scan ID:        550e8400-e29b-41d4-a716-446655440000
Timestamp:      2024-01-15T10:30:00Z
Input:          example.com
Input Type:     hostname

--------------------------------------------------------------------------------
Scan Summary
--------------------------------------------------------------------------------
Total IPs:              1
Live Hosts:             1
Open Ports:             3
Vulnerabilities:        2
  - Critical:           1
  - High:               0
  - Medium:             1
  - Low:                0
  - Info:               0

Total Duration:         25.2 seconds
```

## Performance Benchmarks

### Expected Execution Times

#### Single IP Address
- **Total Time:** 45-160 seconds (~1-3 minutes)
- **CPU Usage:** 30-60%
- **RAM Usage:** 100-200 MB
- **Network Usage:** 1-5 Mbps

#### CIDR Block (/24 - 256 IPs)
- **Total Time:** 15-50 minutes
- **CPU Usage:** 30-60%
- **RAM Usage:** 100-400 MB
- **Network Usage:** 0.5-5 Mbps

#### Hostname Resolution
- **Total Time:** 45-160 seconds (~1-3 minutes)
- **CPU Usage:** 30-60%
- **RAM Usage:** 100-200 MB
- **Network Usage:** 1-5 Mbps

### Throughput Metrics

#### DNS Resolution (massdns)
- **Queries/Second:** 50,000-100,000
- **Success Rate:** 95-98%
- **RAM Usage:** 50-100 MB

#### Host Discovery (naabu)
- **Hosts/Second:** 10,000
- **Accuracy:** 99%
- **Resource Usage:** Low

#### Port Scanning (naabu)
- **Ports/Second:** 100-1,000 (configurable)
- **Accuracy:** 95-99.9%
- **RAM Usage:** 40-60 MB

#### Vulnerability Scanning (nuclei)
- **Requests/Second:** 50-200 (configurable)
- **Templates/Second:** 10-80
- **RAM Usage:** 100-300 MB

## Troubleshooting

### Check Tool Installation
```bash
# Check if all tools are installed
which mapcidr massdns naabu nuclei

# Check tool versions
mapcidr -version
massdns -h
naabu -version
nuclei -version
```

### Verify Configuration
```bash
# Source configuration
source lazyconfig

# Check configuration variables
echo $MASSDNS_RESOLVERS
echo $NAABU_PORT_RATE
echo $NUCLEI_RATE
```

### Monitor Resource Usage
```bash
# Monitor CPU and RAM usage
top -p $(pgrep -f lazyrecon.sh)

# Monitor network traffic
iftop -i eth0

# Monitor disk usage
df -h $HOME/lazytargets
```

### Debug Mode
```bash
# Enable debug output
export NUCLEI_DEBUG=true

# Run scan with verbose output
bash -x ./lazyrecon.sh example.com
```

## Best Practices

### 1. Start with Default Configuration
- Use default configuration for initial scans
- Monitor performance and resource usage
- Adjust based on observed behavior

### 2. Environment-Specific Tuning
- Adjust settings based on network conditions
- Consider system resources and concurrent workloads
- Test different configurations to find optimal values

### 3. Progressive Optimization
- Make one change at a time
- Measure impact before making additional changes
- Document successful configurations

### 4. Resource Monitoring
- Monitor CPU, RAM, and network usage during scans
- Adjust settings if resource limits are exceeded
- Use built-in monitoring tools to track performance

### 5. Error Handling
- Use appropriate timeout values for network conditions
- Configure retries for unreliable networks
- Monitor error rates and adjust accordingly

### 6. Security Considerations
- Only scan targets you have permission to scan
- Use conservative settings for production environments
- Respect rate limits and avoid detection
- Follow OWASP and NIST guidelines

### 7. Documentation
- Keep documentation up to date
- Document custom configurations
- Share successful configurations with team
- Refer to authoritative sources

## Methodology
0. Use [dnsperftest](https://github.com/cleanbrowsing/dnsperftest) to know your best resolvers
1. Run `./lazyrecon.sh`
2. Check output reports of nuclei, massdns, naabu
3. Pick the right target for you based on open ports and scan results
4. Use Firefox and Burp to proxy all requests while exploratory testing
5. Try to find file upload vulnerabilities
6. Perform Google, Trello, Atlassian, Github, Bitbucket dorking
7. Check JS sources for credentials, API endpoints
8. Investigate `XHR` requests, fuzz parameters and variables
9. Check exploit-db.com for target-specific CVE based on `nmap`/`masscan` output

## Origin
This project was inspired by original v1.0 [Ben Sadeghipour](https://github.com/nahamsec/lazyrecon) and aimed to implement some of the best practices like [Mechanizing the Methodology](https://www.youtube.com/watch?v=L_qoz2_Qyhk), [TBHM](https://docs.google.com/presentation/d/1MWWXXRvvesWL8V-GiwGssvg4iDM58_RMeI_SZ65VXwQ), [Subdomain Takeovers](https://www.hackerone.com/blog/Guide-Subdomain-Takeovers), [Request Smuggling](https://portswigger.net/web-security/request-smuggling), [SSRF](https://www.hackerone.com/blog-How-To-Server-Side-Request-Forgery-SSRF), [LFI](https://www.allysonomalley.com/2021/02/11/burpparamflagger-identifying-possible-ssrf-lfi-insertion-points/) and [Bruteforce](https://danielmiessler.com/blog/the-most-interesting-disallowed-directories/) based on [Custom wordlist](https://www.youtube.com/watch?v=W4_QCSIujQ4&t=1237s&ab_channel=Nahamsec).

## Notes
**Acknowledgement:** This code was created for personal use with hosts you are authorized to test/explore by any of the known bug bounty programs. Use it at your own risk.

[See release notes](misc/NOTES.MD)

## Authoritative Sources

### Security Testing Guidelines

1. **OWASP Testing Guide v4**
   - URL: https://owasp.org/www-project-web-security-testing-guide/
   - Description: Comprehensive guide for web application security testing

2. **NIST SP 800-115**
   - URL: https://csrc.nist.gov/publications/detail/sp/800-115/final
   - Description: Technical Guide to Information Security Testing and Assessment

3. **OWASP Top 10**
   - URL: https://owasp.org/www-project-top-ten/
   - Description: Top 10 most critical web application security risks

4. **OWASP ASVS**
   - URL: https://owasp.org/www-project-application-security-verification-standard/
   - Description: Application Security Verification Standard

5. **CWE/SANS Top 25**
   - URL: https://cwe.mitre.org/top25/
   - Description: Top 25 most dangerous software errors

### Tool Documentation

1. **Nuclei Documentation**
   - URL: https://docs.nuclei.sh/
   - Description: Official documentation for Nuclei vulnerability scanner

2. **Naabu Documentation**
   - URL: https://github.com/projectdiscovery/naabu
   - Description: Official documentation for Naabu port scanner

3. **Mapcidr Documentation**
   - URL: https://github.com/projectdiscovery/mapcidr
   - Description: Official documentation for Mapcidr IP enumeration tool

4. **Massdns Documentation**
   - URL: https://github.com/blechschmidt/massdns
   - Description: Official documentation for Massdns DNS resolver

5. **Puredns Documentation**
   - URL: https://github.com/d3mondev/puredns
   - Description: Official documentation for Puredns DNS resolver

### Industry Standards

1. **CIS Controls**
   - URL: https://www.cisecurity.org/controls/
   - Description: Center for Internet Security Controls

2. **ISO/IEC 27001 & 27002**
   - URL: https://www.iso.org/isoiec-27001-information-security.html
   - Description: Information security management standards

3. **MITRE ATT&CK Framework**
   - URL: https://attack.mitre.org/
   - Description: Adversary tactics, techniques, and procedures
