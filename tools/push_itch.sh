#!/usr/bin/env bash
# Push the Godot web build to itch.io via butler.
# Target page: https://ybwangrogger.itch.io/game-of-biubiu
#
# Auth (pick one):
#   export BUTLER_API_KEY='...'   # from https://itch.io/user/settings/api-keys
#   or: butler login
#
# Usage:
#   ./tools/push_itch.sh              # push existing export/web
#   ./tools/push_itch.sh --export     # re-export with Godot, then push

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEB_DIR="${ROOT}/export/web"
ITCH_TARGET="${ITCH_TARGET:-ybwangrogger/rogue-white:html}"
GODOT_BIN="${GODOT_BIN:-$HOME/godot47/Godot_v4.7.2-stable_linux.x86_64}"
BUTLER_BIN="${BUTLER_BIN:-$HOME/bin/butler}"

if [[ "${1:-}" == "--export" ]]; then
  if [[ ! -x "$GODOT_BIN" ]]; then
    echo "Godot not found at $GODOT_BIN (set GODOT_BIN)" >&2
    exit 1
  fi
  mkdir -p "$WEB_DIR"
  "$GODOT_BIN" --headless --path "$ROOT" --export-release "Web" "$WEB_DIR/index.html"
fi

if [[ ! -f "$WEB_DIR/index.html" || ! -f "$WEB_DIR/index.pck" ]]; then
  echo "Missing web build in $WEB_DIR — run with --export first" >&2
  exit 1
fi

if [[ ! -x "$BUTLER_BIN" ]]; then
  echo "butler not found at $BUTLER_BIN" >&2
  exit 1
fi

if [[ -z "${BUTLER_API_KEY:-}" ]] && ! "$BUTLER_BIN" status >/dev/null 2>&1; then
  echo "Not logged in to itch.io." >&2
  echo "1) Open https://itch.io/user/settings/api-keys and create a key" >&2
  echo "2) export BUTLER_API_KEY='your-key'" >&2
  echo "   or run: $BUTLER_BIN login" >&2
  exit 1
fi

# Godot HTML5 needs these as ThisComputer / HTML / Embeddable on the itch page.
"$BUTLER_BIN" push "$WEB_DIR" "$ITCH_TARGET" --user="godot-web-$(date -u +%Y%m%d-%H%M%S)"
echo "Uploaded → https://ybwangrogger.itch.io/rogue-white"
