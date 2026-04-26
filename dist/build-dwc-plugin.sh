#!/usr/bin/env bash
# Build ArborCTL DWC plugin ZIP (same layout as build-dwc-plugin.ps1).
# Usage: build-dwc-plugin.sh <path-to-DuetWebControl-clone> <version>
#   version: tag e.g. v0.2.0 or 0.2.0 (leading "v" stripped for filenames)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DWC_REPO="${1:?Usage: $0 <path-to-DuetWebControl> <version>}"
VERSION_RAW="${2:?Usage: $0 <path-to-DuetWebControl> <version>}"
VERSION="${VERSION_RAW#v}"

if [[ ! -d "${REPO_ROOT}/dwc-plugin" ]]; then
  echo "error: dwc-plugin not found under ${REPO_ROOT}" >&2
  exit 1
fi

if [[ ! -f "${DWC_REPO}/scripts/build-plugin-pkg.js" ]]; then
  echo "error: not a DuetWebControl repo: ${DWC_REPO}/scripts/build-plugin-pkg.js missing" >&2
  exit 1
fi

STAGING="$(mktemp -d "${TMPDIR:-/tmp}/arborctl-dwc-XXXXXX")"
cleanup() { rm -rf "${STAGING}"; }
trap cleanup EXIT

echo "Staging DWC plugin (version ${VERSION})..."

cp -a "${REPO_ROOT}/dwc-plugin/." "${STAGING}/"

mkdir -p "${STAGING}/sd/sys/arborctl"
cp -a "${REPO_ROOT}/sys/." "${STAGING}/sd/sys/"
cp -a "${REPO_ROOT}/macro/gcodes/." "${STAGING}/sd/sys/"
cp -a "${REPO_ROOT}/macro/private/." "${STAGING}/sd/sys/arborctl/"

while IFS= read -r -d '' f; do
  if grep -q '%%ARBORCTL_VERSION%%' "$f" 2>/dev/null; then
    sed -i.bak "s/%%ARBORCTL_VERSION%%/${VERSION}/g" "$f" && rm -f "${f}.bak"
  fi
done < <(find "${STAGING}" -type f \( -name '*.g' -o -name '*.example' -o -name 'plugin.json' \) -print0)

echo "Running DuetWebControl scripts/build-plugin-pkg.js..."
( cd "${DWC_REPO}" && node scripts/build-plugin-pkg.js "${STAGING}" )

mkdir -p "${REPO_ROOT}/dist"

OUT="${DWC_REPO}/dist/ArborCTL-${VERSION}.zip"
if [[ ! -f "${OUT}" ]]; then
  echo "error: expected output missing: ${OUT}" >&2
  ls -la "${DWC_REPO}/dist" >&2 || true
  exit 1
fi

cp -f "${OUT}" "${REPO_ROOT}/dist/"
echo "Built: ${REPO_ROOT}/dist/ArborCTL-${VERSION}.zip"
