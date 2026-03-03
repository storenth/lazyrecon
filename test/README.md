# LazyRecon Test Suite

This directory contains comprehensive test scripts for validating the simplified lazyrecon.sh implementation.

## Test Scripts

### 1. test_lazyrecon.sh
Basic validation tests for script structure, dependencies, and configuration.

**Tests:**
- Bash syntax validation
- Script executability
- Configuration file existence
- Tool dependency availability
- Input type detection
- Function definitions
- Error handling setup
- Variable initialization
- Report generation structure
- Tool command validation

**Usage:**
```bash
./test/test_lazyrecon.sh
```

**Expected Output:** All tests should pass (30+ tests)

---

### 2. test_functions.sh
Unit tests for individual functions.

**Tests:**
- `detect_type()` function with various inputs:
  - IP addresses (8.8.8.8)
  - CIDR blocks (192.168.1.0/24, 10.0.0.0/8)
  - Hostnames (example.com, subdomain.example.org)

**Usage:**
```bash
./test/test_functions.sh
```

**Expected Output:** All 5 tests should pass

---

### 3. test_integration.sh
Full integration tests with actual script execution.

**Tests:**
- Error handling (no arguments)
- IP address input (8.8.8.8)
- CIDR input (192.0.2.0/30)
- Hostname input (example.com)
- Report file generation
- JSON report structure validation
- TXT report content validation

**Usage:**
```bash
./test/test_integration.sh
```

**Expected Output:** All 20 tests should pass

**Note:** This test takes ~8-10 minutes to complete as it runs actual scans.

---

## Test Results

### Latest Test Run (2026-03-02)

| Test Suite | Tests Run | Passed | Failed | Status |
|------------|-----------|---------|---------|--------|
| test_functions.sh | 5 | 5 | 0 | ✅ PASS |
| test_integration.sh | 20 | 20 | 0 | ✅ PASS |
| **Total** | **25** | **25** | **0** | **✅ PASS** |

---

## Issues Found and Fixed

During testing, 3 issues were discovered and fixed:

1. **Empty HOMEDIR Variable (CRITICAL)**
   - Location: [`lazyconfig:7`](../lazyconfig:7)
   - Fix: Commented out empty `export HOMEDIR=`
   - Impact: Script was completely non-functional

2. **JSON Report Generation (HIGH)**
   - Location: [`lazyrecon.sh:104`](../lazyrecon.sh:104)
   - Fix: Changed from command substitution to string literals
   - Impact: JSON report generation failed

3. **TXT Report Template ID (LOW)**
   - Location: [`lazyrecon.sh:161`](../lazyrecon.sh:161)
   - Fix: Changed `.templateID` to `.["template-id"]`
   - Impact: Cosmetic issue only

See [`ISSUES_FOUND.md`](ISSUES_FOUND.md) for detailed information.

---

## Running All Tests

To run the complete test suite:

```bash
# Run all tests
./test/test_lazyrecon.sh
./test/test_functions.sh
./test/test_integration.sh

# Or run individually
./test/test_lazyrecon.sh      # Quick validation (~1 minute)
./test/test_functions.sh       # Function tests (~5 seconds)
./test/test_integration.sh     # Full integration (~10 minutes)
```

---

## Test Coverage

The test suite covers:

- ✅ Script syntax and structure
- ✅ Tool dependencies and versions
- ✅ Input type detection (IP, CIDR, hostname)
- ✅ Configuration file loading
- ✅ Error handling and cleanup
- ✅ Resource monitoring
- ✅ Report generation (JSON and TXT)
- ✅ JSON schema validation
- ✅ Integration with actual targets

---

## Documentation

- **[TEST_REPORT.md](../TEST_REPORT.md)** - Comprehensive test report with all results
- **[ISSUES_FOUND.md](ISSUES_FOUND.md)** - Detailed list of issues found and fixed
- **[../ARCHITECTURE.md](../ARCHITECTURE.md)** - System architecture documentation
- **[../PERFORMANCE.md](../PERFORMANCE.md)** - Performance analysis and metrics

---

## Continuous Integration

To integrate these tests into CI/CD:

```yaml
# Example GitHub Actions workflow
name: Test LazyRecon

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install dependencies
        run: ./install.sh
      - name: Run syntax tests
        run: ./test/test_lazyrecon.sh
      - name: Run function tests
        run: ./test/test_functions.sh
      - name: Run integration tests
        run: ./test/test_integration.sh
```

---

## Contributing

When adding new features to lazyrecon.sh:

1. Add corresponding tests to [`test_lazyrecon.sh`](test_lazyrecon.sh)
2. Add integration tests to [`test_integration.sh`](test_integration.sh)
3. Update this README with new test descriptions
4. Update [`TEST_REPORT.md`](../TEST_REPORT.md) with results

---

## Troubleshooting

### Test Failures

If tests fail:

1. **Check tool installation:**
   ```bash
   which mapcidr massdns naabu nuclei jq bc
   ```

2. **Check configuration:**
   ```bash
   cat lazyconfig
   ```

3. **Check permissions:**
   ```bash
   ls -la lazyrecon.sh
   chmod +x lazyrecon.sh
   ```

4. **Check test logs:**
   ```bash
   cat /tmp/test_*.log
   ```

### Integration Test Timeout

If integration tests timeout:

1. Check network connectivity
2. Verify target hosts are reachable
3. Check if tools are functioning correctly
4. Review system resource usage

---

## License

Same as parent project (LazyRecon)

---

**Last Updated:** 2026-03-02  
**Test Suite Version:** 1.0  
**Status:** All tests passing ✅
