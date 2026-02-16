#!/usr/bin/env bash
# test-hook.sh - Test the pre-ssh hook behavior
#
# Usage: ./scripts/test-hook.sh

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/hooks/pre-ssh.sh"
STATE_FILE="${HOME}/.config/pai/infrastructure/ssh-permissions.json"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Test helper
test_ssh() {
    local desc="$1"
    local cmd="$2"
    local expected_exit="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    echo ""
    echo "Test $TESTS_RUN: $desc"
    echo "  Command: $cmd"

    set +e
    eval "$HOOK $cmd" > /dev/null 2>&1
    local actual_exit=$?
    set -e

    if [[ $actual_exit -eq $expected_exit ]]; then
        echo -e "  ${GREEN}✓ PASS${NC} (exit $actual_exit)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗ FAIL${NC} (expected exit $expected_exit, got $actual_exit)"
    fi
}

# Ensure state file exists with test data
setup_test_state() {
    echo "Setting up test state file..."

    mkdir -p "$(dirname "$STATE_FILE")"

    cat > "$STATE_FILE" << 'EOF'
{
  "version": "1.0",
  "machine": "mac-studio",
  "lastUpdated": "2026-01-31T23:55:00Z",
  "hosts": [
    {
      "id": "proxmox02",
      "hostname": "proxmox02",
      "ip": "10.71.1.8",
      "user": "rico",
      "state": "allowed",
      "note": "Test allowed host"
    },
    {
      "id": "test-blocked",
      "hostname": "blocked",
      "ip": "10.71.20.99",
      "user": "root",
      "state": "blocked",
      "note": "Test blocked host"
    },
    {
      "id": "test-ask",
      "hostname": "askme",
      "ip": "10.71.20.100",
      "user": "rico",
      "state": "ask",
      "note": "Test ask host"
    }
  ],
  "pending": []
}
EOF

    echo "✓ Test state file created"
}

# Main test suite
main() {
    echo "========================================="
    echo "SSHGuard Hook Test Suite"
    echo "========================================="

    # Setup
    setup_test_state

    # Test allowed host
    test_ssh \
        "Allowed host (by IP)" \
        "ssh rico@10.71.1.8" \
        0

    test_ssh \
        "Allowed host (by hostname)" \
        "ssh rico@proxmox02" \
        0

    # Test blocked host
    test_ssh \
        "Blocked host" \
        "ssh root@10.71.20.99" \
        1

    # Test ask host
    test_ssh \
        "Ask host" \
        "ssh rico@10.71.20.100" \
        1

    # Test unknown host (should add to pending)
    test_ssh \
        "Unknown host (adds to pending)" \
        "ssh rico@10.71.20.200" \
        1

    # Verify pending queue updated
    echo ""
    echo "Checking pending queue..."
    local pending_count=$(jq '.pending | length' "$STATE_FILE")
    if [[ $pending_count -gt 0 ]]; then
        echo -e "${GREEN}✓${NC} Unknown host added to pending queue"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Unknown host NOT added to pending queue"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    # Non-SSH command (should allow)
    test_ssh \
        "Non-SSH command (should allow)" \
        "ls -la" \
        0

    # Results
    echo ""
    echo "========================================="
    echo "Test Results"
    echo "========================================="
    echo "Tests run: $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$((TESTS_RUN - TESTS_PASSED))${NC}"

    if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
        echo -e "\n${GREEN}✓ All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}✗ Some tests failed${NC}"
        exit 1
    fi
}

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed${NC}"
    echo "Install with: brew install jq"
    exit 1
fi

if [[ ! -x "$HOOK" ]]; then
    echo -e "${RED}Error: Hook script not executable: $HOOK${NC}"
    echo "Run: chmod +x $HOOK"
    exit 1
fi

main
