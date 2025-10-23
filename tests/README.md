# ClaudeBox Tests

This directory contains test scripts to verify ClaudeBox compatibility across different Bash versions.

## Test Scripts

### test_cli_parsing.sh
A comprehensive test suite that verifies CLI argument parsing correctness:
- Four-bucket argument parsing (host/control/command/pass-through)
- Command recognition (help, lint, shell, create, etc.)
- Command requirements detection (none/image/docker)
- Edge cases (empty args, multiple flags, unknown commands)

**Coverage:** 24 tests covering all CLI parsing scenarios

**Usage:**
```bash
cd tests
./test_cli_parsing.sh
```

### test_container_operations.sh
Integration tests for container lifecycle and slot management:
- Project initialization and setup
- Container name generation
- Slot directory creation and management
- Multi-slot scenarios (creating/deleting multiple slots)
- Counter management
- Parent folder and image name generation

**Coverage:** 34 tests covering all container operation scenarios

**Usage:**
```bash
cd tests
./test_container_operations.sh
```

### test_bash32_compat.sh
A comprehensive test suite that verifies Bash 3.2 compatibility by checking:
- All profile functions work correctly
- Usage patterns from the main script
- No Bash 4+ specific syntax is used
- Everything works with `set -u` (strict mode)

**Usage:**
```bash
cd tests
./test_bash32_compat.sh
```

### test_in_bash32_docker.sh
Runs the compatibility test suite in actual Bash 3.2 using Docker, then compares with your local Bash version.

**Requirements:** Docker must be installed

**Usage:**
```bash
cd tests
./test_in_bash32_docker.sh
```

### run_all_tests.sh
Convenience script that runs all test suites and provides a comprehensive summary.

**Coverage:** Runs all 71 tests across 3 test suites

**Features:**
- Runs all tests in sequence
- Displays output from each suite
- Provides overall summary with total counts
- Color-coded results for easy reading
- Exit code 0 if all pass, 1 if any fail

**Usage:**
```bash
cd tests
./run_all_tests.sh
```

## Test Coverage

The test suite now includes **71 tests** covering:

1. **CLI Parsing** (24 tests - test_cli_parsing.sh)
   - Command recognition (help, lint, shell, create, etc.)
   - Four-bucket argument parsing
   - Flag handling (--verbose, --enable-sudo, rebuild)
   - Command requirements detection
   - Edge cases and error handling

2. **Container Operations** (34 tests - test_container_operations.sh)
   - Project initialization and directory structure
   - Container name generation and consistency
   - Slot directory creation and deletion
   - Multi-slot management (creating/deleting 5+ slots)
   - Counter management and state tracking
   - Parent folder and image name generation

3. **Profile Functions** (13 tests - test_bash32_compat.sh)
   - `get_profile_packages()`
   - `get_profile_description()`
   - `get_all_profile_names()`
   - `profile_exists()`

4. **Usage Patterns**
   - Profile listing (as used in `claudebox profiles`)
   - Dockerfile generation patterns
   - Empty profile handling
   - Invalid profile handling

5. **Bash 3.2 Compatibility**
   - No associative arrays (`declare -A`)
   - No `${var^^}` uppercase expansion
   - No `[[ -v` variable checking
   - Works with `set -u` (strict mode)

## Expected Results

All 71 tests should pass in both Bash 3.2 and modern Bash versions.

**Quick test run:**
```bash
cd tests
./run_all_tests.sh
```

Or run individually:
```bash
cd tests
./test_cli_parsing.sh && ./test_container_operations.sh && ./test_bash32_compat.sh
```

## macOS Testing

These tests are particularly important for macOS users, as macOS ships with Bash 3.2 by default. The Docker test ensures compatibility without needing access to a Mac.