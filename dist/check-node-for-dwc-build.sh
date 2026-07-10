#!/usr/bin/env bash
# Require a Node.js version that can run DWC 3.7 Vite / rolldown plugin builds.
# Required: Node ^20.19.0 or >=22.12.0

set -euo pipefail

NODE_BIN="${NODE_BIN:-$(command -v node || true)}"
if [[ -z "${NODE_BIN}" ]]; then
  echo "error: node not found on PATH" >&2
  exit 1
fi

NODE_VER="$("${NODE_BIN}" -p "process.versions.node" 2>/dev/null || true)"
if [[ -z "${NODE_VER}" ]]; then
  echo "error: could not read Node version from ${NODE_BIN}" >&2
  exit 1
fi

if ! "${NODE_BIN}" -e '
const [maj, min] = process.versions.node.split(".").map(Number);
const ok =
  (maj === 20 && min >= 19) ||
  (maj === 22 && min >= 12) ||
  maj >= 23;
process.exit(ok ? 0 : 1);
'; then
  echo "error: Node ${NODE_VER} at ${NODE_BIN} is too old for DWC 3.7 Vite/rolldown builds" >&2
  echo "  Required: Node ^20.19.0 or >=22.12.0 (Node 22 LTS recommended)" >&2
  exit 1
fi

echo "check-node-for-dwc-build: OK (Node ${NODE_VER} @ ${NODE_BIN})"
