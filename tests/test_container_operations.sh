#!/bin/bash
# Integration test script for container operations
# Tests container creation, deletion, and multi-slot management

echo "================================================"
echo "ClaudeBox Container Operations Test Suite"
echo "================================================"
echo "Testing: Container lifecycle and slot management"
echo "Bash version: $BASH_VERSION"
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
CLEANUP_NEEDED=false

# Get script paths
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$TEST_DIR")"

# Create temporary test project directory
TEST_PROJECT_DIR="/tmp/claudebox-test-project-$$"
mkdir -p "$TEST_PROJECT_DIR"
CLEANUP_NEEDED=true

# Source required libraries
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/config.sh"
source "$ROOT_DIR/lib/docker.sh"
source "$ROOT_DIR/lib/project.sh"

# Cleanup function
cleanup() {
    if [[ "$CLEANUP_NEEDED" == "true" ]]; then
        echo
        echo -e "${YELLOW}Cleaning up test artifacts...${NC}"

        # Remove test project directory and any slots
        if [[ -d "$TEST_PROJECT_DIR" ]]; then
            local parent_dir
            parent_dir=$(get_parent_dir "$TEST_PROJECT_DIR" 2>/dev/null || echo "")
            if [[ -n "$parent_dir" && -d "$parent_dir" ]]; then
                rm -rf "$parent_dir"
            fi
            rm -rf "$TEST_PROJECT_DIR"
        fi

        echo -e "${GREEN}Cleanup complete${NC}"
    fi
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

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

# Test function with output capture
run_test_with_output() {
    local test_name="$1"
    local test_cmd="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Test $TESTS_RUN: $test_name... "

    local output
    output=$(eval "$test_cmd" 2>&1)
    local result=$?

    if [ $result -eq 0 ]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "$output"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Error output:"
        echo "$output" | sed 's/^/    /'
        return 1
    fi
}

echo "=== 1. Project Setup Tests ==="
echo

# Initialize project
export PROJECT_DIR="$TEST_PROJECT_DIR"
init_project_dir "$PROJECT_DIR" >/dev/null 2>&1

run_test "Project directory is initialized" \
    "[[ -d '$TEST_PROJECT_DIR' ]]"

run_test "Parent directory is created" \
    "[[ -d \$(get_parent_dir '$TEST_PROJECT_DIR') ]]"

run_test "Counter file is created" \
    "[[ -f \$(get_parent_dir '$TEST_PROJECT_DIR')/.project_container_counter ]]"

run_test "Initial counter value is 1" \
    "[[ \$(read_counter \$(get_parent_dir '$TEST_PROJECT_DIR')) -eq 1 ]]"

echo
echo "=== 2. Container Name Generation Tests ==="
echo

run_test "Generate container name for slot 1" \
    "[[ -n \$(generate_container_name '$TEST_PROJECT_DIR' 1) ]]"

run_test "Generate container name for slot 5" \
    "[[ -n \$(generate_container_name '$TEST_PROJECT_DIR' 5) ]]"

run_test "Container names are consistent for same slot" \
    "[[ \$(generate_container_name '$TEST_PROJECT_DIR' 1) == \$(generate_container_name '$TEST_PROJECT_DIR' 1) ]]"

run_test "Container names differ for different slots" \
    "[[ \$(generate_container_name '$TEST_PROJECT_DIR' 1) != \$(generate_container_name '$TEST_PROJECT_DIR' 2) ]]"

echo
echo "=== 3. Slot Directory Management Tests ==="
echo

# Create first slot directory
SLOT1_NAME=$(generate_container_name "$TEST_PROJECT_DIR" 1)
PARENT_DIR=$(get_parent_dir "$TEST_PROJECT_DIR")
SLOT1_DIR="$PARENT_DIR/$SLOT1_NAME"
mkdir -p "$SLOT1_DIR"
write_counter "$PARENT_DIR" 1

run_test "Slot 1 directory is created" \
    "[[ -d '$SLOT1_DIR' ]]"

run_test "Get slot directory for slot 1" \
    "[[ \$(get_slot_dir '$TEST_PROJECT_DIR' 1) == '$SLOT1_DIR' ]]"

run_test "Counter increments to 1" \
    "[[ \$(read_counter '$PARENT_DIR') -eq 1 ]]"

# Create second slot directory
SLOT2_NAME=$(generate_container_name "$TEST_PROJECT_DIR" 2)
SLOT2_DIR="$PARENT_DIR/$SLOT2_NAME"
mkdir -p "$SLOT2_DIR"
write_counter "$PARENT_DIR" 2

run_test "Slot 2 directory is created" \
    "[[ -d '$SLOT2_DIR' ]]"

run_test "Get slot directory for slot 2" \
    "[[ \$(get_slot_dir '$TEST_PROJECT_DIR' 2) == '$SLOT2_DIR' ]]"

run_test "Counter increments to 2" \
    "[[ \$(read_counter '$PARENT_DIR') -eq 2 ]]"

run_test "Both slot directories exist" \
    "[[ -d '$SLOT1_DIR' && -d '$SLOT2_DIR' ]]"

echo
echo "=== 4. Slot Deletion Tests ==="
echo

# Delete slot 2
rm -rf "$SLOT2_DIR"
write_counter "$PARENT_DIR" 1

run_test "Slot 2 directory is deleted" \
    "[[ ! -d '$SLOT2_DIR' ]]"

run_test "Slot 1 directory still exists" \
    "[[ -d '$SLOT1_DIR' ]]"

run_test "Counter decrements to 1" \
    "[[ \$(read_counter '$PARENT_DIR') -eq 1 ]]"

# Delete slot 1
rm -rf "$SLOT1_DIR"
write_counter "$PARENT_DIR" 0

run_test "Slot 1 directory is deleted" \
    "[[ ! -d '$SLOT1_DIR' ]]"

run_test "Counter resets to 0" \
    "[[ \$(read_counter '$PARENT_DIR') -eq 0 ]]"

echo
echo "=== 5. Multi-Slot Management Tests ==="
echo

# Create multiple slots
SLOT_COUNT=5
for ((i=1; i<=SLOT_COUNT; i++)); do
    SLOT_NAME=$(generate_container_name "$TEST_PROJECT_DIR" $i)
    SLOT_DIR="$PARENT_DIR/$SLOT_NAME"
    mkdir -p "$SLOT_DIR"
done
write_counter "$PARENT_DIR" $SLOT_COUNT

run_test "Create $SLOT_COUNT slots" \
    "[[ \$(read_counter '$PARENT_DIR') -eq $SLOT_COUNT ]]"

# Count only slot directories (hex names starting with numbers)
ACTUAL_SLOTS=$(find "$PARENT_DIR" -mindepth 1 -maxdepth 1 -type d -name '[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]' 2>/dev/null | wc -l)
run_test "All $SLOT_COUNT slot directories exist" \
    "[[ $ACTUAL_SLOTS -eq $SLOT_COUNT ]]"

# Verify each slot directory
for ((i=1; i<=SLOT_COUNT; i++)); do
    SLOT_NAME=$(generate_container_name "$TEST_PROJECT_DIR" $i)
    SLOT_DIR="$PARENT_DIR/$SLOT_NAME"
    run_test "Slot $i directory exists" \
        "[[ -d '$SLOT_DIR' ]]"
done

# Delete all slots
for ((i=SLOT_COUNT; i>=1; i--)); do
    SLOT_NAME=$(generate_container_name "$TEST_PROJECT_DIR" $i)
    SLOT_DIR="$PARENT_DIR/$SLOT_NAME"
    rm -rf "$SLOT_DIR"
done
write_counter "$PARENT_DIR" 0

run_test "All slots deleted" \
    "[[ \$(read_counter '$PARENT_DIR') -eq 0 ]]"

REMAINING_SLOTS=$(find "$PARENT_DIR" -mindepth 1 -maxdepth 1 -type d -name '[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]' 2>/dev/null | wc -l)
run_test "No slot directories remain" \
    "[[ $REMAINING_SLOTS -eq 0 ]]"

echo
echo "=== 6. Parent Folder Name Generation Tests ==="
echo

run_test "Generate parent folder name" \
    "[[ -n \$(generate_parent_folder_name '$TEST_PROJECT_DIR') ]]"

run_test "Parent folder name is consistent" \
    "[[ \$(generate_parent_folder_name '$TEST_PROJECT_DIR') == \$(generate_parent_folder_name '$TEST_PROJECT_DIR') ]]"

# Test with different project paths
TEST_PROJECT_DIR2="/tmp/claudebox-test-project2-$$"
mkdir -p "$TEST_PROJECT_DIR2"

run_test "Different projects have different parent folder names" \
    "[[ \$(generate_parent_folder_name '$TEST_PROJECT_DIR') != \$(generate_parent_folder_name '$TEST_PROJECT_DIR2') ]]"

rm -rf "$TEST_PROJECT_DIR2"

echo
echo "=== 7. Image Name Generation Tests ==="
echo

export PROJECT_DIR="$TEST_PROJECT_DIR"

run_test "Generate image name" \
    "[[ -n \$(get_image_name) ]]"

run_test "Image name starts with 'claudebox-'" \
    "[[ \$(get_image_name) == claudebox-* ]]"

echo
echo "================================================"
echo "Test Results"
echo "================================================"
echo -e "Tests run:    ${BLUE}$TESTS_RUN${NC}"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$((TESTS_RUN - TESTS_PASSED))${NC}"
echo

if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
