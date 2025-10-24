#!/bin/bash
# Test script for CLI parsing functionality
# Tests the four-bucket argument parsing system in lib/cli.sh

echo "======================================"
echo "ClaudeBox CLI Parsing Test Suite"
echo "======================================"
echo "Testing: Four-bucket argument parser"
echo "Bash version: $BASH_VERSION"
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Get script paths
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$TEST_DIR")"
CLI_SCRIPT="$ROOT_DIR/lib/cli.sh"

# Source the CLI parsing functions
source "$CLI_SCRIPT"

# Test function
run_test() {
    local test_name="$1"
    local test_cmd="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Test $TESTS_RUN: $test_name... "

    if eval "$test_cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Error output:"
        eval "$test_cmd" 2>&1 | sed 's/^/    /'
        return 1
    fi
}

echo "1. Basic Command Recognition"
echo "----------------------------"

# Test 1: Recognize script commands
test_script_command() {
    parse_cli_args "help"
    [[ "$CLI_SCRIPT_COMMAND" == "help" ]]
}
run_test "Recognize 'help' command" test_script_command

# Test 2: Recognize lint command
test_lint_command() {
    parse_cli_args "lint"
    [[ "$CLI_SCRIPT_COMMAND" == "lint" ]]
}
run_test "Recognize 'lint' command" test_lint_command

# Test 3: Recognize shell command
test_shell_command() {
    parse_cli_args "shell"
    [[ "$CLI_SCRIPT_COMMAND" == "shell" ]]
}
run_test "Recognize 'shell' command" test_shell_command

# Test 4: Recognize create command
test_create_command() {
    parse_cli_args "create"
    [[ "$CLI_SCRIPT_COMMAND" == "create" ]]
}
run_test "Recognize 'create' command" test_create_command

echo
echo "2. Four-Bucket Argument Parsing"
echo "--------------------------------"

# Test 5: Host-only flags
test_host_flags() {
    parse_cli_args "--verbose" "shell"
    [[ "${CLI_HOST_FLAGS[*]}" == "--verbose" ]] && [[ "$CLI_SCRIPT_COMMAND" == "shell" ]]
}
run_test "Parse --verbose as host flag" test_host_flags

# Test 6: Control flags
test_control_flags() {
    parse_cli_args "--enable-sudo" "shell"
    [[ "${CLI_CONTROL_FLAGS[*]}" == "--enable-sudo" ]] && [[ "$CLI_SCRIPT_COMMAND" == "shell" ]]
}
run_test "Parse --enable-sudo as control flag" test_control_flags

# Test 7: Multiple flags
test_multiple_flags() {
    parse_cli_args "--verbose" "--enable-sudo" "shell"
    [[ "${CLI_HOST_FLAGS[*]}" == "--verbose" ]] && [[ "${CLI_CONTROL_FLAGS[*]}" == "--enable-sudo" ]]
}
run_test "Parse multiple flags" test_multiple_flags

# Test 8: Pass-through arguments
test_passthrough_args() {
    parse_cli_args "lint" "lib/docker.sh"
    [[ "$CLI_SCRIPT_COMMAND" == "lint" ]] && [[ "${CLI_PASS_THROUGH[*]}" == "lib/docker.sh" ]]
}
run_test "Parse pass-through arguments" test_passthrough_args

# Test 9: Complex argument combination
test_complex_args() {
    parse_cli_args "--verbose" "lint" "main.sh" "lib/cli.sh"
    [[ "${CLI_HOST_FLAGS[*]}" == "--verbose" ]] && \
    [[ "$CLI_SCRIPT_COMMAND" == "lint" ]] && \
    [[ "${CLI_PASS_THROUGH[0]}" == "main.sh" ]] && \
    [[ "${CLI_PASS_THROUGH[1]}" == "lib/cli.sh" ]]
}
run_test "Parse complex argument combination" test_complex_args

# Test 10: Flags after command
test_flags_after_command() {
    parse_cli_args "shell" "--enable-sudo"
    [[ "$CLI_SCRIPT_COMMAND" == "shell" ]] && [[ "${CLI_CONTROL_FLAGS[*]}" == "--enable-sudo" ]]
}
run_test "Parse flags after command" test_flags_after_command

echo
echo "3. Command Requirements Detection"
echo "----------------------------------"

# Test 11: Lint requires no Docker
test_lint_no_docker() {
    local req=$(get_command_requirements "lint")
    [[ "$req" == "none" ]]
}
run_test "lint requires no Docker" test_lint_no_docker

# Test 12: Shell requires Docker
test_shell_requires_docker() {
    local req=$(get_command_requirements "shell")
    [[ "$req" == "docker" ]]
}
run_test "shell requires Docker" test_shell_requires_docker

# Test 13: Help requires no Docker
test_help_no_docker() {
    local req=$(get_command_requirements "help")
    [[ "$req" == "none" ]]
}
run_test "help requires no Docker" test_help_no_docker

# Test 14: Profiles requires no Docker
test_profiles_no_docker() {
    local req=$(get_command_requirements "profiles")
    [[ "$req" == "none" ]]
}
run_test "profiles requires no Docker" test_profiles_no_docker

# Test 15: Add requires image (not Docker)
test_add_requires_image() {
    local req=$(get_command_requirements "add")
    [[ "$req" == "image" ]]
}
run_test "add requires image" test_add_requires_image

# Test 16: Clean requires no Docker
test_clean_no_docker() {
    local req=$(get_command_requirements "clean")
    [[ "$req" == "none" ]]
}
run_test "clean requires no Docker" test_clean_no_docker

# Test 17: Create requires no Docker
test_create_no_docker() {
    local req=$(get_command_requirements "create")
    [[ "$req" == "none" ]]
}
run_test "create requires no Docker" test_create_no_docker

# Test 18: Kill requires no Docker
test_kill_no_docker() {
    local req=$(get_command_requirements "kill")
    [[ "$req" == "none" ]]
}
run_test "kill requires no Docker" test_kill_no_docker

echo
echo "4. Edge Cases"
echo "-------------"

# Test 19: Empty arguments
test_empty_args() {
    parse_cli_args
    # Check that no command was set
    [[ -z "$CLI_SCRIPT_COMMAND" ]] || return 1
    # Check that pass-through is either empty or contains only empty elements
    # This handles both ${array[@]} (length 0) and ${array[@]:-} (length 1 with empty string)
    if [[ ${#CLI_PASS_THROUGH[@]} -eq 0 ]]; then
        return 0
    elif [[ ${#CLI_PASS_THROUGH[@]} -eq 1 ]] && [[ -z "${CLI_PASS_THROUGH[0]}" ]]; then
        return 0
    else
        return 1
    fi
}
run_test "Handle empty arguments" test_empty_args

# Test 20: Only flags, no command
test_only_flags() {
    parse_cli_args "--verbose" "--enable-sudo"
    [[ "${CLI_HOST_FLAGS[*]}" == "--verbose" ]] && \
    [[ "${CLI_CONTROL_FLAGS[*]}" == "--enable-sudo" ]] && \
    [[ -z "$CLI_SCRIPT_COMMAND" ]]
}
run_test "Handle only flags" test_only_flags

# Test 21: Unknown command (should be pass-through)
test_unknown_command() {
    local req=$(get_command_requirements "unknown-command")
    [[ "$req" == "docker" ]]  # Unknown commands forwarded to container
}
run_test "Unknown commands forward to Docker" test_unknown_command

# Test 22: First command wins (no duplicate commands)
test_first_command_wins() {
    parse_cli_args "help" "shell" "lint"
    [[ "$CLI_SCRIPT_COMMAND" == "help" ]] && \
    [[ "${CLI_PASS_THROUGH[0]}" == "shell" ]] && \
    [[ "${CLI_PASS_THROUGH[1]}" == "lint" ]]
}
run_test "First command wins" test_first_command_wins

# Test 23: Rebuild as host flag
test_rebuild_flag() {
    parse_cli_args "rebuild" "shell"
    [[ "${CLI_HOST_FLAGS[*]}" == "rebuild" ]] && [[ "$CLI_SCRIPT_COMMAND" == "shell" ]]
}
run_test "rebuild is a host flag" test_rebuild_flag

# Test 24: Short help flag
test_short_help() {
    parse_cli_args "-h"
    [[ "$CLI_SCRIPT_COMMAND" == "-h" ]]
}
run_test "Recognize -h flag" test_short_help

echo
echo "======================================"
echo "Test Summary"
echo "======================================"
echo "Tests run: $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$((TESTS_RUN - TESTS_PASSED))${NC}"
echo

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    echo -e "${GREEN}All tests passed! ✓${NC}"
    echo "CLI parsing is working correctly"
    exit 0
else
    echo -e "${RED}Some tests failed ✗${NC}"
    echo "There are issues with CLI parsing"
    exit 1
fi
