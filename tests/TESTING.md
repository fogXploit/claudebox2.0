# Testing Guide for New Features

This guide covers testing the new profile versioning and custom mounts features.

## Test Suite Overview

We have three test scripts:

1. **`test_profile_versioning.sh`** - Unit tests for profile versioning
2. **`test_custom_mounts.sh`** - Unit tests for custom mounts
3. **`test_integration_new_features.sh`** - Integration tests (requires Docker)

## Quick Start

```bash
# Run all unit tests (no Docker required)
cd tests
./test_profile_versioning.sh
./test_custom_mounts.sh

# Run integration tests (requires Docker and ClaudeBox)
# IMPORTANT: Run from the ClaudeBox root directory, not from tests/
cd /path/to/claudebox
./tests/test_integration_new_features.sh

# Run integration tests with full container validation
RUN_CONTAINER_TESTS=true ./tests/test_integration_new_features.sh
```

## Test Details

### 1. Profile Versioning Tests (`test_profile_versioning.sh`)

**What it tests:**
- Parsing `profile:version` syntax
- Storing versions in `profiles.ini`
- Retrieving versions from config
- Updating existing versions
- Multiple profile versions
- All 8 supported languages
- Edge cases (special characters, empty values)

**Prerequisites:** None (pure unit tests)

**Expected result:** 10 tests passing

**Example output:**
```
Test 1: Parse profile without version
✓ Correctly parsed profile name without version

Test 2: Parse profile:version syntax
✓ Correctly parsed profile:version (python:3.12)

...

==========================================
Test Summary
==========================================
Total tests: 10
Passed: 10
All tests passed!
```

### 2. Custom Mounts Tests (`test_custom_mounts.sh`)

**What it tests:**
- YAML parsing from `.claudebox.yml`
- CLI mount argument parsing
- Read-only vs read-write modes
- Tilde expansion (`~` to `$HOME`)
- Absolute paths
- Paths with spaces
- Quoted paths
- Invalid mode rejection
- Mount merging logic

**Prerequisites:** None (pure unit tests)

**Expected result:** 15 tests passing

**Example output:**
```
Test 1: Parse simple YAML mount
✓ Correctly parsed simple YAML mount

Test 2: Parse multiple YAML mounts
✓ Correctly parsed multiple YAML mounts

...

==========================================
Test Summary
==========================================
Total tests: 15
Passed: 15
All tests passed!
```

### 3. Integration Tests (`test_integration_new_features.sh`)

**What it tests:**
- Project initialization
- Adding profiles with versions via CLI
- Version storage in `profiles.ini`
- Multiple profiles with versions
- Creating `.claudebox.yml`
- Parsing config file mounts
- CLI mount overrides
- Mixed versioned/unversioned profiles
- Updating existing versions
- **Container tests** (optional): Version installation and mount accessibility

**Prerequisites:**
- Docker installed and running
- ClaudeBox installed
- Write access to `~/.claudebox/`

**Expected result:** 11 tests passing (2 skipped without RUN_CONTAINER_TESTS)

**Example output:**
```
ℹ Checking prerequisites...
✓ Prerequisites check passed

Test 1: Initialize ClaudeBox project
✓ Successfully initialized ClaudeBox project

Test 2: Add profile with version via CLI
ℹ Running: claudebox add python:3.11
✓ Successfully added python:3.11 profile

Test 2: Verify version stored in profiles.ini
✓ Version correctly stored in profiles.ini

...

==========================================
Integration Test Summary
==========================================
Total tests: 11
Passed: 11
All tests passed!

Note: Container tests were skipped (Tests 7-8)
For full validation, run: RUN_CONTAINER_TESTS=true ./test_integration_new_features.sh
```

## Manual Testing Guide

For comprehensive manual validation, follow these steps:

### Profile Versioning Manual Tests

```bash
# 1. Create test project
mkdir /tmp/test-claudebox
cd /tmp/test-claudebox

# 2. Test Python versioning
claudebox add python:3.11
claudebox
# Inside container:
python --version  # Should show Python 3.11.x
exit

# 3. Test Node.js versioning
claudebox add javascript:18
claudebox shell
node --version  # Should show v18.x.x
exit

# 4. Test multiple versions
claudebox add rust:1.75.0 go:1.21.5
# Verify in profiles.ini
cat ~/.claudebox/projects/*/profiles.ini

# 5. Test version update
claudebox add python:3.12
# Verify version changed in profiles.ini

# 6. Test all 8 languages
claudebox add python:3.12 javascript:18 rust:1.75.0 \
  go:1.21.5 java:17.0.9 ruby:3.2.0 \
  flutter:3.16.0 php:8.2.0

# Launch container and verify each
claudebox shell
python --version
node --version
rustc --version
go version
java -version
ruby --version
flutter --version
php --version
```

### Custom Mounts Manual Tests

```bash
# 1. Create test directories
mkdir -p ~/test-data ~/test-models
echo "Hello from host" > ~/test-data/test.txt
echo "Model data" > ~/test-models/model.txt

# 2. Test CLI mount
claudebox --mount ~/test-data:/data:rw shell
# Inside container:
cat /data/test.txt  # Should show "Hello from host"
echo "Modified" > /data/modified.txt
exit
# Check on host:
cat ~/test-data/modified.txt  # Should show "Modified"

# 3. Test read-only mount
claudebox --mount ~/test-models:/models:ro shell
# Inside container:
cat /models/model.txt  # Should work
echo "test" > /models/new.txt  # Should fail (read-only)
exit

# 4. Test config file mounts
cd /tmp/test-claudebox
cat > .claudebox.yml << 'EOF'
mounts:
  - host: ~/test-data
    container: /data
    readonly: false
  - host: ~/test-models
    container: /models
    readonly: true
EOF

claudebox shell
# Verify both mounts:
ls /data
ls /models
exit

# 5. Test CLI override
claudebox --mount ~/test-models:/data:ro shell
# /data should now point to test-models (overriding config)
cat /data/model.txt
exit

# 6. Test multiple mounts
claudebox --mount ~/test-data:/data1 \
  --mount ~/test-models:/data2 \
  --mount ~/.aws:/aws:ro shell
ls /data1 /data2 /aws
exit
```

## Troubleshooting Tests

### Test failures

If tests fail, check:

1. **Shellcheck errors**: Run `shellcheck -x lib/*.sh build/docker-entrypoint`
2. **Function exports**: Ensure new functions are exported in `lib/config.sh`
3. **Bash version**: ClaudeBox requires Bash 3.2+ compatibility
4. **File permissions**: Ensure test scripts are executable (`chmod +x tests/*.sh`)

### Integration test failures

If integration tests fail:

1. **Docker running**: `docker info`
2. **ClaudeBox installed**: `which claudebox`
3. **Permissions**: Check `~/.claudebox/` permissions
4. **Clean state**: Remove test projects: `rm -rf ~/.claudebox/projects/test-*`

### Container test failures

If container tests fail with `RUN_CONTAINER_TESTS=true`:

1. **Build time**: Container builds can take 5-10 minutes
2. **Network**: Version managers need internet access
3. **Disk space**: Ensure enough space for container images
4. **Image cache**: Try rebuilding: `claudebox --rebuild`

## Automated CI Testing

To add these tests to CI/CD:

```yaml
# .github/workflows/test.yml
name: Test New Features
on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run unit tests
        run: |
          cd tests
          ./test_profile_versioning.sh
          ./test_custom_mounts.sh

  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Docker
        run: docker info
      - name: Install ClaudeBox
        run: ./claudebox.run
      - name: Run integration tests
        run: ./tests/test_integration_new_features.sh
      - name: Run full container tests
        run: RUN_CONTAINER_TESTS=true ./tests/test_integration_new_features.sh
```

## Test Coverage

**Profile Versioning:**
- ✅ CLI parsing (10 tests)
- ✅ Storage in profiles.ini (10 tests)
- ✅ All 8 languages supported (1 test)
- ⚠️  Container installation (manual/optional)
- ⚠️  Version manager errors (manual/optional)

**Custom Mounts:**
- ✅ YAML parsing (15 tests)
- ✅ CLI parsing (15 tests)
- ✅ Path expansion (15 tests)
- ⚠️  Docker mount integration (manual/optional)
- ⚠️  Override behavior (manual/optional)

**Total Coverage:**
- Unit tests: 25 automated tests
- Integration tests: 11 automated tests (9 standard + 2 optional container tests)
- Manual tests: Comprehensive guide provided
- Container tests: Optional with RUN_CONTAINER_TESTS

## Success Criteria

Before considering features production-ready:

- [x] All unit tests pass
- [x] All integration tests pass (without container tests)
- [ ] Container tests pass with `RUN_CONTAINER_TESTS=true`
- [ ] Manual testing completed for all 8 languages
- [ ] Manual testing completed for custom mounts
- [ ] No shellcheck errors
- [ ] Documentation updated
- [ ] Example files created

## Reporting Issues

If you find issues during testing:

1. Run with verbose mode: `VERBOSE=true claudebox ...`
2. Check logs in test output
3. Include:
   - Test script output
   - OS and Docker version
   - ClaudeBox version
   - Contents of `profiles.ini` and `.claudebox.yml`
   - Steps to reproduce

## Next Steps

After all tests pass:
1. Update CHANGELOG.md
2. Tag new version
3. Create GitHub release
4. Update documentation site (if applicable)
