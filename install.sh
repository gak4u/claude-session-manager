#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-$HOME/.local/bin}"

mkdir -p "$TARGET"
ln -sf "$SCRIPT_DIR/csm" "$TARGET/csm"
chmod +x "$SCRIPT_DIR/csm"

echo "linked $TARGET/csm -> $SCRIPT_DIR/csm"

case ":$PATH:" in
  *":$TARGET:"*) ;;
  *)
    echo
    echo "warning: $TARGET is not in your PATH"
    echo "add this to your shell rc:"
    echo "  export PATH=\"$TARGET:\$PATH\""
    ;;
esac
