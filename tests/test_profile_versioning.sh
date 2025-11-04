#!/usr/bin/env bash
# Test script for profile versioning feature
# Tests both CLI parsing and profiles.ini storage

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Source the libraries
source "$ROOT_DIR/lib/config.sh"

# Helper functions
pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf "${GREEN}✓${NC} %s\n" "$1"
}

fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "${RED}✗${NC} %s\n" "$1"
    if [[ -n "${2:-}" ]]; then
        printf "  ${YELLOW}Expected:${NC} %s\n" "$2"
        printf "  ${YELLOW}Got:${NC} %s\n" "$3"
    fi
}

test_header() {
    TESTS_RUN=$((TESTS_RUN + 1))
    printf "\nTest %d: %s\n" "$TESTS_RUN" "$1"
}

# Setup test environment
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Test 1: Parse profile without version
test_header "Parse profile without version"
PROFILE_SPEC="python"
PROFILE_NAME="${PROFILE_SPEC%%:*}"
if [[ "$PROFILE_NAME" == "python" ]]; then
    pass "Correctly parsed profile name without version"
else
    fail "Failed to parse profile name" "python" "$PROFILE_NAME"
fi

# Test 2: Parse profile with version
test_header "Parse profile:version syntax"
PROFILE_SPEC="python:3.12"
if [[ "$PROFILE_SPEC" == *:* ]]; then
    PROFILE_NAME="${PROFILE_SPEC%%:*}"
    PROFILE_VERSION="${PROFILE_SPEC#*:}"
    if [[ "$PROFILE_NAME" == "python" ]] && [[ "$PROFILE_VERSION" == "3.12" ]]; then
        pass "Correctly parsed profile:version (python:3.12)"
    else
        fail "Failed to parse profile:version" "python + 3.12" "$PROFILE_NAME + $PROFILE_VERSION"
    fi
else
    fail "Failed to detect colon in profile:version"
fi

# Test 3: Store version in profiles.ini
test_header "Store version in profiles.ini"
TEST_PROFILE_FILE="$TEST_DIR/profiles.ini"
echo "[profiles]" > "$TEST_PROFILE_FILE"
echo "python" >> "$TEST_PROFILE_FILE"
echo "" >> "$TEST_PROFILE_FILE"

update_profile_version "$TEST_PROFILE_FILE" "python" "3.12"

if grep -q "^\[versions\]" "$TEST_PROFILE_FILE" && grep -q "^python=3.12" "$TEST_PROFILE_FILE"; then
    pass "Successfully stored version in profiles.ini"
else
    fail "Failed to store version in profiles.ini"
    cat "$TEST_PROFILE_FILE"
fi

# Test 4: Retrieve version from profiles.ini
test_header "Retrieve version from profiles.ini"
RETRIEVED_VERSION=$(get_profile_version "$TEST_PROFILE_FILE" "python")
if [[ "$RETRIEVED_VERSION" == "3.12" ]]; then
    pass "Successfully retrieved version from profiles.ini"
else
    fail "Failed to retrieve version" "3.12" "$RETRIEVED_VERSION"
fi

# Test 5: Update existing version
test_header "Update existing version"
update_profile_version "$TEST_PROFILE_FILE" "python" "3.11"
UPDATED_VERSION=$(get_profile_version "$TEST_PROFILE_FILE" "python")
if [[ "$UPDATED_VERSION" == "3.11" ]]; then
    pass "Successfully updated existing version"
else
    fail "Failed to update version" "3.11" "$UPDATED_VERSION"
fi

# Test 6: Multiple profiles with versions
test_header "Store multiple profile versions"
update_profile_version "$TEST_PROFILE_FILE" "javascript" "18"
update_profile_version "$TEST_PROFILE_FILE" "rust" "1.75.0"

PY_VER=$(get_profile_version "$TEST_PROFILE_FILE" "python")
JS_VER=$(get_profile_version "$TEST_PROFILE_FILE" "javascript")
RUST_VER=$(get_profile_version "$TEST_PROFILE_FILE" "rust")

if [[ "$PY_VER" == "3.11" ]] && [[ "$JS_VER" == "18" ]] && [[ "$RUST_VER" == "1.75.0" ]]; then
    pass "Successfully stored multiple profile versions"
else
    fail "Failed with multiple versions" "3.11, 18, 1.75.0" "$PY_VER, $JS_VER, $RUST_VER"
fi

# Test 7: Parse all supported language versions
test_header "Parse versions for all 8 languages"
declare -a LANGS=("python:3.12" "javascript:18" "rust:1.75.0" "go:1.21.5" "java:17.0.9" "ruby:3.2.0" "flutter:3.16.0" "php:8.2.0")
ALL_PARSED=true
for lang_spec in "${LANGS[@]}"; do
    if [[ "$lang_spec" == *:* ]]; then
        name="${lang_spec%%:*}"
        version="${lang_spec#*:}"
        if [[ -z "$name" ]] || [[ -z "$version" ]]; then
            ALL_PARSED=false
            break
        fi
    else
        ALL_PARSED=false
        break
    fi
done

if [[ "$ALL_PARSED" == "true" ]]; then
    pass "Successfully parsed all 8 language versions"
else
    fail "Failed to parse all language versions"
fi

# Test 8: Empty version handling
test_header "Handle profile without version in versioned file"
EMPTY_VER=$(get_profile_version "$TEST_PROFILE_FILE" "nonexistent")
if [[ -z "$EMPTY_VER" ]]; then
    pass "Correctly returns empty string for non-existent profile version"
else
    fail "Should return empty for non-existent profile" "(empty)" "$EMPTY_VER"
fi

# Test 9: Version with special characters
test_header "Handle version with dots and numbers"
update_profile_version "$TEST_PROFILE_FILE" "java" "17.0.9-tem"
JAVA_VER=$(get_profile_version "$TEST_PROFILE_FILE" "java")
if [[ "$JAVA_VER" == "17.0.9-tem" ]]; then
    pass "Correctly handles version with dots and hyphens"
else
    fail "Failed to handle complex version" "17.0.9-tem" "$JAVA_VER"
fi

# Test 10: Profiles.ini structure validation
test_header "Validate profiles.ini structure"
if grep -q "^\[profiles\]" "$TEST_PROFILE_FILE" && grep -q "^\[versions\]" "$TEST_PROFILE_FILE"; then
    # Check that versions come after profiles
    PROFILES_LINE=$(grep -n "^\[profiles\]" "$TEST_PROFILE_FILE" | cut -d: -f1)
    VERSIONS_LINE=$(grep -n "^\[versions\]" "$TEST_PROFILE_FILE" | cut -d: -f1)
    if [[ $VERSIONS_LINE -gt $PROFILES_LINE ]]; then
        pass "profiles.ini has correct structure (versions after profiles)"
    else
        fail "profiles.ini structure incorrect" "versions after profiles" "versions before profiles"
    fi
else
    fail "profiles.ini missing required sections"
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
printf "Total tests: %d\n" "$TESTS_RUN"
printf "${GREEN}Passed: %d${NC}\n" "$TESTS_PASSED"
if [[ $TESTS_FAILED -gt 0 ]]; then
    printf "${RED}Failed: %d${NC}\n" "$TESTS_FAILED"
    exit 1
else
    printf "${GREEN}All tests passed!${NC}\n"
    exit 0
fi
