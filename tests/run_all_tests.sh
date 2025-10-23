#!/bin/bash
# Run all ClaudeBox test suites

echo "=========================================="
echo "Running All ClaudeBox Tests"
echo "=========================================="
echo

# Get script directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Track overall results
TOTAL_SUITES=0
PASSED_SUITES=0
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

# Run test suite and capture results
run_suite() {
    local suite_name="$1"
    local suite_script="$2"

    echo -e "${BLUE}Running: $suite_name${NC}"
    echo "----------------------------------------"

    TOTAL_SUITES=$((TOTAL_SUITES + 1))

    # Run the test and capture output
    local output
    output=$("$TEST_DIR/$suite_script" 2>&1)
    local exit_code=$?

    # Display the output
    echo "$output"
    echo

    # Extract test counts from output (strip ANSI color codes first)
    local clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
    local tests_run=$(echo "$clean_output" | grep -oP "Tests run:\s*\K\d+" | tail -1)
    local tests_passed=$(echo "$clean_output" | grep -oP "Tests passed:\s*\K\d+" | tail -1)

    if [[ -n "$tests_run" && -n "$tests_passed" ]]; then
        TOTAL_TESTS=$((TOTAL_TESTS + tests_run))
        TOTAL_PASSED=$((TOTAL_PASSED + tests_passed))
    fi

    if [ $exit_code -eq 0 ]; then
        PASSED_SUITES=$((PASSED_SUITES + 1))
    fi

    return $exit_code
}

# Run all test suites
run_suite "CLI Parsing Tests" "test_cli_parsing.sh"
run_suite "Container Operations Tests" "test_container_operations.sh"
run_suite "Bash 3.2 Compatibility Tests" "test_bash32_compat.sh"

# Calculate failed tests
TOTAL_FAILED=$((TOTAL_TESTS - TOTAL_PASSED))

# Print summary
echo "=========================================="
echo "Overall Test Summary"
echo "=========================================="
echo -e "Test Suites:  ${BLUE}$TOTAL_SUITES${NC}"
echo -e "Suites Passed: ${GREEN}$PASSED_SUITES${NC}"
echo -e "Suites Failed: ${RED}$((TOTAL_SUITES - PASSED_SUITES))${NC}"
echo
echo -e "Total Tests:  ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Tests Passed: ${GREEN}$TOTAL_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TOTAL_FAILED${NC}"
echo

if [ $PASSED_SUITES -eq $TOTAL_SUITES ]; then
    echo -e "${GREEN}✓ All test suites passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some test suites failed!${NC}"
    exit 1
fi
