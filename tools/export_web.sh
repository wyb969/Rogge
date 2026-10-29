#!/usr/bin/env bash
# Export Rogge to HTML5 and optionally serve it for phone testing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/export/web"
GODOT_BIN="${GODOT_BIN:-}"

if [[ -z "$GODOT_BIN" ]]; then
  for candidate in \
    "$HOME/godot/Godot_v4.3-stable_linux.x86_64" \
    "$HOME/godot/Godot"*linux* \
    "$(command -v godot || true)" \
    "$(command -v godot4 || true)"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      GODOT_BIN="$candidate"
      break
    fi
  done
fi

if [[ -z "${GODOT_BIN}" || ! -x "$GODOT_BIN" ]]; then
  echo "Godot binary not found. Set GODOT_BIN to your Godot 4.x executable."
  echo "Preferred: Godot 4.7 matching this project."
  exit 1
fi

mkdir -p "$OUT"
echo "Using Godot: $GODOT_BIN"
echo "Exporting Web preset -> $OUT/index.html"

# Import resources first (needed on clean machines / CI).
"$GODOT_BIN" --headless --path "$ROOT" --import || true
"$GODOT_BIN" --headless --path "$ROOT" --export-release "Web" "$OUT/index.html"

echo "Export finished."
echo "Serve with:  python3 -m http.server 8080 --directory \"$OUT\""
echo "Then open on phone (same LAN): http://<your-pc-ip>:8080"
