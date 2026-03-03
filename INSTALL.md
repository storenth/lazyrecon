# Installing LazyRecon

**Platform Support:** Linux & macOS  
**Go Version:** >= 1.17  
**Python Version:** >= 3.7  
**Pip Version:** >= 19.0

## Prerequisites

### System Requirements
```bash
python >= 3.7
pip3 >= 19.0
go >= 1.17
curl
wget
```

### Required Environment Variables

You must configure these environment variables in [`lazyconfig`](lazyconfig):

```bash
# Required environment variables
export HOMEDIR=    # user's home dir e.g.: /home/kali
export STORAGEDIR= # where output saved, e.g.: ${HOMEDIR}/lazytargets
export GOPATH=    # Go workspace, e.g.: ${HOMEDIR}/go
```

**Important Notes:**
- You must source `lazyconfig` before running install or scan scripts
- Only the following tools are required for the simplified scanner: mapcidr, massdns/puredns, naabu, nuclei
- Other tools listed in install.sh are not needed for the minimal workflow

## Installation Methods

### Method 1: Automated Installation (Recommended)

This is the easiest way to install LazyRecon with all dependencies.

1. **Configure environment variables in [`lazyconfig`](lazyconfig):**
```bash
export HOMEDIR=/home/kali
export STORAGEDIR=${HOMEDIR}/lazytargets
export GOPATH=${HOMEDIR}/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin:$GOROOT/bin:$HOME/.local/bin:$HOME/go/bin:$HOMEDIR/go/bin
export GO111MODULE=on
```

2. **Enable the environment:**
```bash
source ./lazyconfig
```

3. **Run the installation script:**
```bash
sudo -E ./install.sh
```

4. **Execute a scan:**
```bash
sudo -E ./lazyrecon.sh "hackerone.com"
```

### Method 2: CI/CD Installation

You can use stateful/stateless build agents (workers). There is no additional time required for provisioning.

Note that masscan/nmap/naabu may require root user access.

1. **Configure environment variables in [`lazyconfig`](lazyconfig):**
```bash
export HOMEDIR=/home/kali
export STORAGEDIR=${HOMEDIR}/lazytargets
export GOPATH=${HOMEDIR}/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin:$GOROOT/bin:$HOME/.local/bin:$HOME/go/bin:$HOMEDIR/go/bin
export GO111MODULE=on
```

2. **Enable the environment:**
```bash
source ./lazyconfig
```

3. **Run the installation:**
```bash
sudo -E ./install.sh
```

4. **Execute a scan:**
```bash
sudo -E ./lazyrecon.sh "hackerone.com"
```

### Method 3: GitHub Actions

Customize `.github/workflows/test-recon-action.yaml` using `DISCORDWEBHOOKURL` [secrets](https://docs.github.com/en/actions/reference/encrypted-secrets). Enable `--discord` to receive a report:

```yaml
- name: Install & Recon
  env:
    GO111MODULE: on
    DISCORDWEBHOOKURL: ${{ secrets.DISCORDWEBHOOKURL }}
  run: |
    export HOMEDIR=$HOME
    export STORAGEDIR="${HOMEDIR}"/lazytargets
    sudo -E ./install.sh
    sudo -E ./lazyrecon.sh "hackerone.com" --quiet --discord
```

### Method 4: Manual Installation

You can configure environment variables and dependencies by hand without using the `install.sh` script, but keep in mind the following:

**Important Considerations:**
- To start using lazyrecon script, please clone and setup the [dependencies below](#dependencies)
- Note that many dependencies are tuned for recon needs and differ from the original ones
- Make sure environment variables are filled in `./lazyconfig`
- If you operate under VPS: first call `./helpers/linux-apt-install.sh`
- Update your local `~/.gf` with `./gfpatterns/*`
- Use option `nuclei -update-templates` to use it properly under `$HOMEDIR`
- Make sure all tools correctly installed and enabled with execute permissions: `chmod +x`
- Take care about appropriate tokens and API keys
- Don't forget that the script acts as a root user

## Dependencies

The simplified scanner only requires the following tools:

### Core Dependencies

1. **[mapcidr](https://github.com/projectdiscovery/mapcidr)** - IP/CIDR enumeration
   - Purpose: Expand CIDR blocks and enumerate IP addresses
   - Installation: `go install -v github.com/projectdiscovery/mapcidr/v2/cmd/mapcidr@latest`

2. **[massdns](https://github.com/blechschmidt/massdns)** - Fast DNS resolution
   - Purpose: High-performance DNS resolution for subdomain enumeration
   - Installation: Compile from source or use package manager
   - **Important:** massdns does NOT support rate limiting (`--rate`) or timeout (`--timeout`) flags

3. **[puredns](https://github.com/d3mondev/puredns)** - DNS resolution with wildcard detection
   - Purpose: DNS resolution with wildcard subdomain detection
   - Installation: `go install github.com/d3mondev/puredns/v2@latest`

4. **[naabu](https://github.com/projectdiscovery/naabu)** - Port scanning
   - Purpose: Fast port scanner for live host and port discovery
   - Installation: `go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest`

5. **[httpx](https://github.com/projectdiscovery/httpx)** - HTTP service detection
    - Purpose: Detect HTTP/HTTPS services on targets with advanced features
    - Installation: `go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest`

6. **[nuclei](https://github.com/projectdiscovery/nuclei)** - Vulnerability scanning
   - Purpose: Template-based vulnerability scanner
   - Installation: `go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest`

7. **[nuclei-templates](https://github.com/projectdiscovery/nuclei-templates)** - Nuclei templates
   - Purpose: Vulnerability detection templates for nuclei
   - Installation: `nuclei -update-templates`

8. **[jq](https://stedolan.github.io/jq/)** - JSON processing
   - Purpose: Command-line JSON processor for parsing reports
   - Installation: Package manager (apt, brew, etc.)

### Installation Options

You may copy each executable dependency to `/usr/local/bin/`, create symlinks, or export to PATH:

```bash
# Option 1: Copy to /usr/local/bin/
sudo cp $HOME/go/bin/nuclei /usr/local/bin/nuclei

# Option 2: Create symlink
sudo ln -s $HOME/go/bin/nuclei /usr/local/bin/nuclei

# Option 3: Export to PATH
export PATH=$HOME/go/bin:$PATH
```

## Configuration

### Basic Configuration

The [`lazyconfig`](lazyconfig) file contains all configuration variables for the tools. Here's the basic structure:

```bash
# Required environment variables
export HOMEDIR="${HOMEDIR:-$HOME}"
export STORAGEDIR="${STORAGEDIR:-$HOMEDIR/lazytargets}"
export GOPATH="${GOPATH:-$HOMEDIR/go}"

# DNS Resolution (massdns)
export MASSDNS_RESOLVERS="./resolvers/resolvers.txt"
# Note: massdns does NOT support rate limiting or timeout flags

# Port Scanning (naabu)
export NAABU_PING_RATE=1000
export NAABU_PING_TIMEOUT=5
export NAABU_PORT_RATE=100
export NAABU_PORT_TIMEOUT=5

# HTTP Service Detection (httpx)
export HTTPX_CONCURRENCY=20
export HTTPX_TIMEOUT=5
export HTTPX_RETRIES=2

# Vulnerability Scanning (nuclei)
export NUCLEI_RATE=100
export NUCLEI_TIMEOUT=10
export NUCLEI_RETRIES=2
export NUCLEI_BULK_SIZE=25
export NUCLEI_HTTP_THREADS=10
```

### Environment-Specific Configuration

#### Fast Local Network Scan
```bash
# Note: massdns does not support rate limiting or timeout flags
export MASSDNS_RESOLVERS="./resolvers/mini_resolvers.txt"
export NAABU_PING_RATE=5000
export NAABU_PING_TIMEOUT=2
export NAABU_PORT_RATE=500
export NAABU_PORT_TIMEOUT=2
export HTTPX_CONCURRENCY=50
export HTTPX_TIMEOUT=2
export HTTPX_RETRIES=1
export NUCLEI_RATE=200
export NUCLEI_TIMEOUT=5
export NUCLEI_BULK_SIZE=50
export NUCLEI_HTTP_THREADS=20
```

#### Conservative Internet Scan
```bash
# Note: massdns does not support rate limiting or timeout flags
export MASSDNS_RESOLVERS="./resolvers/resolvers.txt"
export NAABU_PING_RATE=500
export NAABU_PING_TIMEOUT=10
export NAABU_PORT_RATE=50
export NAABU_PORT_TIMEOUT=10
export HTTPX_CONCURRENCY=10
export HTTPX_TIMEOUT=10
export HTTPX_RETRIES=3
export NUCLEI_RATE=50
export NUCLEI_TIMEOUT=15
export NUCLEI_BULK_SIZE=10
export NUCLEI_HTTP_THREADS=5
```

#### Production Environment Scan
```bash
# Note: massdns does not support rate limiting or timeout flags
export MASSDNS_RESOLVERS="./resolvers/mini_resolvers.txt"
export NAABU_PING_RATE=200
export NAABU_PING_TIMEOUT=15
export NAABU_PORT_RATE=20
export NAABU_PORT_TIMEOUT=15
export HTTPX_CONCURRENCY=5
export HTTPX_TIMEOUT=15
export HTTPX_RETRIES=3
export NUCLEI_RATE=10
export NUCLEI_TIMEOUT=30
export NUCLEI_BULK_SIZE=5
export NUCLEI_HTTP_THREADS=2
export MAX_CPU_PERCENT=50
export MAX_RAM_PERCENT=50
```

### Configuration Variables Reference

#### DNS Resolution (massdns)
| Variable | Description | Default | Notes |
|----------|-------------|---------|-------|
| `MASSDNS_RESOLVERS` | Path to resolver list | `./resolvers/resolvers.txt` | Use mini_resolvers.txt for faster scans |
| `MASSDNS_RATE` | **NOT SUPPORTED** | N/A | massdns does not support rate limiting |
| `MASSDNS_TIMEOUT` | **NOT SUPPORTED** | N/A | massdns does not support timeout |

#### Port Scanning (naabu)
| Variable | Description | Default | Range |
|----------|-------------|---------|-------|
| `NAABU_PING_RATE` | Packets per second for ping scan | 1000 | 100-10000 |
| `NAABU_PING_TIMEOUT` | Timeout for ping scan (seconds) | 5 | 1-30 |
| `NAABU_PORT_RATE` | Packets per second for port scan | 100 | 10-1000 |
| `NAABU_PORT_TIMEOUT` | Timeout for port scan (seconds) | 5 | 1-30 |

#### HTTP Service Detection (httpx)
| Variable | Description | Default | Range |
|----------|-------------|---------|-------|
| `HTTPX_CONCURRENCY` | Number of concurrent probes | 20 | 5-100 |
| `HTTPX_TIMEOUT` | Timeout for HTTP probe (seconds) | 5 | 1-30 |
| `HTTPX_RETRIES` | Number of retries for failed requests | 2 | 1-5 |

#### Vulnerability Scanning (nuclei)
| Variable | Description | Default | Range |
|----------|-------------|---------|-------|
| `NUCLEI_RATE` | Requests per second | 100 | 10-500 |
| `NUCLEI_TIMEOUT` | Request timeout (seconds) | 10 | 5-60 |
| `NUCLEI_RETRIES` | Number of retries | 2 | 1-5 |
| `NUCLEI_BULK_SIZE` | Bulk size for template processing | 25 | 5-100 |
| `NUCLEI_HTTP_THREADS` | Number of HTTP threads | 10 | 1-50 |

#### Resource Management
| Variable | Description | Default | Range |
|----------|-------------|---------|-------|
| `MAX_CPU_PERCENT` | Maximum CPU usage percentage | 80 | 10-100 |
| `MAX_RAM_PERCENT` | Maximum RAM usage percentage | 80 | 10-100 |

## Testing

### Verify Installation

Check if all tools are installed correctly:

```bash
# Check if all tools are installed
which mapcidr massdns naabu nuclei jq

# Check tool versions
mapcidr -version
massdns -h
naabu -version
nuclei -version
jq --version
```

### Run Test Suite

You can check if the dependencies are installed correctly on your machine by running the following tests:

```bash
# Test nuclei templates
./test/test_nuclei_templates.sh "./test/nuclei_templates_list.txt"

# Test installation
./test/test_install.sh "./test/dependencies_list.txt"

# Run all tests
./test/test_lazyrecon.sh
./test/test_functions.sh
./test/test_integration.sh
```

### Test Scan

Run a test scan to verify everything is working:

```bash
# Test with a public DNS server
./lazyrecon.sh 8.8.8.8

# Test with a hostname
./lazyrecon.sh example.com

# Test with a CIDR block
./lazyrecon.sh 192.0.2.0/30
```

## Troubleshooting

### Common Issues

#### Issue: "command not found" errors
**Solution:** Make sure all tools are in your PATH or create symlinks to `/usr/local/bin/`

```bash
# Check PATH
echo $PATH

# Add Go binaries to PATH
export PATH=$PATH:$HOME/go/bin

# Create symlinks
sudo ln -s $HOME/go/bin/nuclei /usr/local/bin/nuclei
```

#### Issue: Permission denied errors
**Solution:** Make sure scripts are executable and run with sudo when needed

```bash
# Make scripts executable
chmod +x lazyrecon.sh install.sh

# Run with sudo
sudo -E ./lazyrecon.sh example.com
```

#### Issue: massdns rate limiting not working
**Solution:** massdns does NOT support rate limiting or timeout flags. Only the resolver configuration is available.

```bash
# This will NOT work:
massdns --rate 1000  # Invalid flag

# This WILL work:
massdns -r resolvers.txt  # Valid flag
```

#### Issue: nuclei input format errors
**Solution:** nuclei requires HTTP/HTTPS protocol prefix for all targets

```bash
# nuclei expects targets like:
http://example.com:80
https://example.com:443

# The script automatically adds the http:// prefix
```

#### Issue: High resource usage
**Solution:** Adjust rate limits and resource thresholds in [`lazyconfig`](lazyconfig)

```bash
# Reduce scan rates
export NAABU_PORT_RATE=50
export NUCLEI_RATE=50

# Set resource limits
export MAX_CPU_PERCENT=50
export MAX_RAM_PERCENT=50
```

### Debug Mode

Enable debug output to troubleshoot issues:

```bash
# Enable nuclei debug
export NUCLEI_DEBUG=true

# Run scan with bash debug mode
bash -x ./lazyrecon.sh example.com

# Check logs
tail -f $HOME/lazytargets/example.com/lazyrecon.log
```

### Get Help

If you face any issues:
- Join [Discord](https://discord.gg/fR2QVrWBTq)
- Open a PR
- File a bug report
- Check the [ARCHITECTURE.md](ARCHITECTURE.md) for detailed documentation

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

### 5. Security Considerations
- Only scan targets you have permission to scan
- Use conservative settings for production environments
- Respect rate limits and avoid detection
- Follow OWASP and NIST guidelines

## Important Notes

### massdns Limitations
- **massdns does NOT support rate limiting (`--rate`) or timeout (`--timeout`) flags**
- Only resolver configuration is available via `-r` flag
- Rate limiting is managed internally by massdns
- Do not attempt to use `--rate` or `--timeout` flags with massdns

### nuclei Input Format
- nuclei requires HTTP/HTTPS protocol prefix for all targets
- The script automatically adds `http://` prefix to all targets
- Format: `http://host:port` or `https://host:port`

### Resource Management
- Monitor CPU and RAM usage during scans
- Use `MAX_CPU_PERCENT` and `MAX_RAM_PERCENT` to limit resource usage
- The script includes built-in resource monitoring and warnings

### Testing
- Always test with known targets before production use
- Use the test suite to verify installation
- Check output files for expected results

## Additional Resources

### Documentation
- [README.md](README.md) - Project overview and usage
- [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture and design details
- [test/README.md](test/README.md) - Test suite documentation

### Tool Documentation
- [Nuclei Documentation](https://docs.nuclei.sh/)
- [Naabu Documentation](https://github.com/projectdiscovery/naabu)
- [Mapcidr Documentation](https://github.com/projectdiscovery/mapcidr)
- [Massdns Documentation](https://github.com/blechschmidt/massdns)
- [Puredns Documentation](https://github.com/d3mondev/puredns)

### Authoritative Sources
- [OWASP Testing Guide v4](https://owasp.org/www-project-web-security-testing-guide/)
- [NIST SP 800-115](https://csrc.nist.gov/publications/detail/sp/800-115/final)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/)
- [HackerOne: Guide to Subdomain Takeovers](https://www.hackerone.com/blog/guide-subdomain-takeovers)
