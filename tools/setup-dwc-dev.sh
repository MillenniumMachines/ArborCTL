#!/usr/bin/env bash
# Link ArborCTL dwc-plugin into a DuetWebControl clone for local hot-reload development.
# Usage: ./tools/setup-dwc-dev.sh /path/to/DuetWebControl-3.6.1
set -euo pipefail

DWC_REPO="${1:-}"
if [[ -z "$DWC_REPO" ]]; then
  echo "Usage: $0 /path/to/DuetWebControl" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARBOR_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_SRC="$ARBOR_ROOT/dwc-plugin"
DEST="$DWC_REPO/src/plugins/ArborCTL"

if [[ ! -f "$DWC_REPO/package.json" ]]; then
  echo "Not a DuetWebControl repo: $DWC_REPO" >&2
  exit 1
fi
if [[ ! -d "$PLUGIN_SRC" ]]; then
  echo "Missing dwc-plugin: $PLUGIN_SRC" >&2
  exit 1
fi

rm -rf "$DEST"
ln -sfn "$PLUGIN_SRC" "$DEST"
echo "Symlinked: $DEST -> $PLUGIN_SRC"
echo "Next: cd \"$DWC_REPO\" && npm install && npm run dev"
