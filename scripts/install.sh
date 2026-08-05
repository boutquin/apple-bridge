#!/bin/bash
#
# install.sh - Build a release binary and install it to a stable location
#
# Builds apple-bridge in release mode and copies the binary out of the volatile
# .build/ tree (which any `swift build`, `swift package clean`, or branch switch
# regenerates) into a stable, user-writable directory on PATH. The Claude MCP
# config points at this stable path, so reinstalling here + restarting Claude is
# all that's needed to ship a new build.
#
# USAGE:
#   ./scripts/install.sh                  # build + install to ~/bin/apple-bridge
#   ./scripts/install.sh --prefix DIR     # install to DIR/apple-bridge instead
#   ./scripts/install.sh --help
#
# AFTER INSTALLING:
#   Restart Claude so it re-spawns the MCP server from the installed binary.
#   The command path lives in ~/.claude.json under mcpServers.apple-bridge.command.
#

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PREFIX="$HOME/bin"

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--prefix DIR]"
            echo ""
            echo "Options:"
            echo "  --prefix DIR  Install directory (default: \$HOME/bin)"
            echo ""
            echo "Builds release mode and installs apple-bridge to DIR/apple-bridge."
            echo "Restart Claude afterward to pick up the new binary."
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

# Run from the repo root regardless of where the script is invoked from.
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

DEST="$PREFIX/apple-bridge"

echo -e "${YELLOW}Building release binary...${NC}"
swift build -c release

SRC="$(swift build -c release --show-bin-path)/apple-bridge"
if [ ! -x "$SRC" ]; then
    echo "Build did not produce an executable at: $SRC" >&2
    exit 1
fi

mkdir -p "$PREFIX"
command cp -f "$SRC" "$DEST"

# Sign the installed copy.
#
# Why this matters even without a certificate: SwiftPM emits a *linker-signed*
# binary, which reports `Info.plist=not bound`. The privacy usage strings are
# embedded via -sectcreate (see Package.swift) but are not covered by the
# signature. An explicit `codesign` run binds them (verify with
# `codesign -dv`: "Info.plist entries=N" instead of "not bound").
#
# Set APPLE_BRIDGE_SIGN_IDENTITY to a Developer ID to produce a distributable,
# notarizable build; unset, it signs ad-hoc, which needs no certificate:
#
#   APPLE_BRIDGE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/install.sh
#
# See docs/code-signing.md for creating the certificate and notarizing.
SIGN_IDENTITY="${APPLE_BRIDGE_SIGN_IDENTITY:--}"
if [ "$SIGN_IDENTITY" = "-" ]; then
    echo -e "${YELLOW}Signing (ad-hoc)...${NC}"
    codesign --force --sign - "$DEST"
else
    echo -e "${YELLOW}Signing as:${NC} $SIGN_IDENTITY"
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$DEST"
fi

# Fail loudly rather than install a binary whose usage strings aren't covered —
# a silently unbound Info.plist is exactly the condition that makes macOS
# privacy prompts never appear.
if codesign -dv "$DEST" 2>&1 | grep -q "Info.plist=not bound"; then
    echo "Signing did not bind Info.plist — refusing to report success." >&2
    exit 1
fi
codesign -dv "$DEST" 2>&1 | grep -E 'Signature|Info.plist' | sed 's/^/  /'

echo -e "${GREEN}Installed:${NC} $DEST"
echo ""
echo -e "${YELLOW}Next:${NC} pick up the new binary with:"
echo "  pkill -f apple-bridge      # the MCP host respawns it on the next tool call"
echo "  (A full Claude restart also works but is not required.)"
echo "  (Config: ~/.claude.json -> mcpServers.apple-bridge.command = $DEST)"

case ":$PATH:" in
    *":$PREFIX:"*) ;;
    *) echo -e "${YELLOW}Note:${NC} $PREFIX is not on your PATH (the MCP config uses the absolute path, so this is fine)." ;;
esac
