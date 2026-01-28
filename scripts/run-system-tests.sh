#!/bin/bash
#
# run-system-tests.sh - Run system tests with optional coverage reporting
#
# This script enables system tests (which require macOS permissions) and runs
# them with optional code coverage reporting.
#
# PREREQUISITES:
#   - Calendar access granted (for EventKit tests)
#   - Contacts access granted (for CNContact tests)
#   - Full Disk Access granted (for Notes/Messages SQLite tests)
#   - Apple Mail configured (for Mail tests)
#   - Apple Maps available (for Maps tests)
#
# USAGE:
#   ./scripts/run-system-tests.sh           # Run system tests only
#   ./scripts/run-system-tests.sh --coverage # Run with coverage report
#   ./scripts/run-system-tests.sh --manual-qa # Include manual QA tests (FDA tests)
#
# ENVIRONMENT VARIABLES:
#   APPLE_BRIDGE_SYSTEM_TESTS=1  - Enable system tests (auto-set by this script)
#   APPLE_BRIDGE_MANUAL_QA=1     - Enable manual QA tests (requires FDA denied)
#
# OUTPUT:
#   Coverage reports are saved to .build/coverage/
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
COVERAGE=false
MANUAL_QA=false

for arg in "$@"; do
    case $arg in
        --coverage)
            COVERAGE=true
            shift
            ;;
        --manual-qa)
            MANUAL_QA=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--coverage] [--manual-qa]"
            echo ""
            echo "Options:"
            echo "  --coverage   Generate code coverage report"
            echo "  --manual-qa  Include manual QA tests (requires FDA to be DENIED)"
            echo ""
            echo "Prerequisites:"
            echo "  - Calendar, Contacts, Full Disk Access permissions granted"
            echo "  - Apple Mail configured, Apple Maps available"
            exit 0
            ;;
    esac
done

# Change to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  Apple Bridge System Tests${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Set environment variables
export APPLE_BRIDGE_SYSTEM_TESTS=1
echo -e "${GREEN}✓${NC} APPLE_BRIDGE_SYSTEM_TESTS=1"

if [ "$MANUAL_QA" = true ]; then
    export APPLE_BRIDGE_MANUAL_QA=1
    echo -e "${YELLOW}⚠${NC} APPLE_BRIDGE_MANUAL_QA=1 (FDA must be DENIED for these tests)"
fi

echo ""

# Build first
echo -e "${YELLOW}Building...${NC}"
swift build

echo ""
echo -e "${YELLOW}Running system tests...${NC}"
echo ""

if [ "$COVERAGE" = true ]; then
    # Run with coverage
    swift test --filter SystemTests --enable-code-coverage

    # Generate coverage report
    echo ""
    echo -e "${YELLOW}Generating coverage report...${NC}"

    COVERAGE_DIR=".build/coverage"
    mkdir -p "$COVERAGE_DIR"

    # Find the profdata file
    PROFDATA=$(find .build -name "*.profdata" | head -1)

    if [ -n "$PROFDATA" ]; then
        # Find the test binary
        TEST_BINARY=$(find .build -name "apple-bridgePackageTests.xctest" -type d | head -1)

        if [ -n "$TEST_BINARY" ]; then
            # Get the actual binary inside the xctest bundle
            if [ -d "$TEST_BINARY/Contents/MacOS" ]; then
                BINARY_PATH="$TEST_BINARY/Contents/MacOS/apple-bridgePackageTests"
            else
                BINARY_PATH="$TEST_BINARY"
            fi

            # Generate lcov report
            xcrun llvm-cov export \
                -format=lcov \
                -instr-profile "$PROFDATA" \
                "$BINARY_PATH" \
                > "$COVERAGE_DIR/lcov.info" 2>/dev/null || true

            # Generate text summary
            xcrun llvm-cov report \
                -instr-profile "$PROFDATA" \
                "$BINARY_PATH" \
                > "$COVERAGE_DIR/summary.txt" 2>/dev/null || true

            echo -e "${GREEN}✓${NC} Coverage reports saved to $COVERAGE_DIR/"
            echo ""

            # Show summary if available
            if [ -f "$COVERAGE_DIR/summary.txt" ]; then
                echo -e "${YELLOW}Coverage Summary:${NC}"
                head -20 "$COVERAGE_DIR/summary.txt"
            fi
        else
            echo -e "${RED}✗${NC} Could not find test binary for coverage report"
        fi
    else
        echo -e "${RED}✗${NC} Could not find profdata file for coverage report"
    fi
else
    # Run without coverage
    swift test --filter SystemTests
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  System tests complete!${NC}"
echo -e "${GREEN}========================================${NC}"
