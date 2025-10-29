#!/usr/bin/env bash
set -euo pipefail

# Create runtime directories with safe perms
LOKI_DIR="${LOKI_DATA_DIR:-./loki/data}"
PROMTAIL_POS="${PROMTAIL_POSITIONS_DIR:-./promtail/positions}"

mkdir -p "$LOKI_DIR" "$PROMTAIL_POS"
chmod 755 "$LOKI_DIR" "$PROMTAIL_POS"

echo "Created:"
echo "  $LOKI_DIR"
echo "  $PROMTAIL_POS"
echo "Done."
