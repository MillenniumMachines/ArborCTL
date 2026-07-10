#!/usr/bin/env bash
# Build ArborCTL DWC plugin ZIP.
# Usage: build-dwc-plugin.sh <path-to-DuetWebControl-clone> <version>
#   version: tag e.g. v0.2.0 or 0.2.0 (leading "v" stripped for filenames)
#
# DWC 3.7+ (Vite): npm run build-plugin <staging-dir> writes <staging-dir>/ArborCTL-<version>.zip
# DWC 3.6.x (webpack): scripts/build-plugin-pkg.js writes under DuetWebControl/dist/

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

DWC_REPO="$(cd "${DWC_REPO}" && pwd)"

chmod +x "${REPO_ROOT}/dist/check-node-for-dwc-build.sh"
"${REPO_ROOT}/dist/check-node-for-dwc-build.sh"

DWC_BUILDER="$(node "${REPO_ROOT}/dist/detect-dwc-plugin-builder.mjs" "${DWC_REPO}")"
echo "DWC plugin builder: ${DWC_BUILDER}"

STAGING="$(mktemp -d "${TMPDIR:-/tmp}/arborctl-dwc-XXXXXX")"
cleanup() { rm -rf "${STAGING}"; }
trap cleanup EXIT

echo "Staging DWC plugin (version ${VERSION})..."

cp -a "${REPO_ROOT}/dwc-plugin/." "${STAGING}/"

mkdir -p "${STAGING}/sd/sys/arborctl"
cp -a "${REPO_ROOT}/sys/." "${STAGING}/sd/sys/"
cp -a "${REPO_ROOT}/macro/gcodes/." "${STAGING}/sd/sys/"
cp -a "${REPO_ROOT}/macro/private/." "${STAGING}/sd/sys/arborctl/"

# NeXT data.nxt entrypoints → 0:/sys/plugins/arborctl/
if [[ -d "${REPO_ROOT}/sd/sys/plugins/arborctl" ]]; then
  mkdir -p "${STAGING}/sd/sys/plugins/arborctl"
  cp -a "${REPO_ROOT}/sd/sys/plugins/arborctl/." "${STAGING}/sd/sys/plugins/arborctl/"
fi

while IFS= read -r -d '' f; do
  if grep -q '%%ARBORCTL_VERSION%%' "$f" 2>/dev/null; then
    sed -i.bak "s/%%ARBORCTL_VERSION%%/${VERSION}/g" "$f" && rm -f "${f}.bak"
  fi
done < <(find "${STAGING}" -type f \( -name '*.g' -o -name '*.example' -o -name 'plugin.json' \) -print0)

mkdir -p "${REPO_ROOT}/dist"
OUT_NAME="ArborCTL-${VERSION}.zip"

if [[ "${DWC_BUILDER}" == "vite" ]]; then
  echo "Running DuetWebControl npm run build-plugin (Vite)..."
  (
    cd "${DWC_REPO}"
    if [[ ! -d node_modules ]]; then
      npm ci || npm install
    fi
    npm run build-plugin -- "${STAGING}"
  )

  OUT=""
  if [[ -f "${STAGING}/${OUT_NAME}" ]]; then
    OUT="${STAGING}/${OUT_NAME}"
  else
    shopt -s nullglob
    _cands=("${STAGING}"/ArborCTL-*.zip "${DWC_REPO}/dist"/ArborCTL-*.zip)
    shopt -u nullglob
    if [[ ${#_cands[@]} -gt 0 ]]; then
      OUT="${_cands[0]}"
      echo "warning: using unexpected ZIP name ${OUT} (expected ${OUT_NAME})" >&2
    fi
  fi
  if [[ -z "${OUT}" || ! -f "${OUT}" ]]; then
    echo "error: expected Vite output missing: ${STAGING}/${OUT_NAME}" >&2
    ls -la "${STAGING}" >&2 || true
    exit 1
  fi
  cp -f "${OUT}" "${REPO_ROOT}/dist/${OUT_NAME}"
else
  if [[ ! -f "${DWC_REPO}/scripts/build-plugin-pkg.js" ]]; then
    echo "error: webpack builder expected but ${DWC_REPO}/scripts/build-plugin-pkg.js missing" >&2
    exit 1
  fi
  echo "Running DuetWebControl scripts/build-plugin-pkg.js (webpack)..."
  ( cd "${DWC_REPO}" && node scripts/build-plugin-pkg.js "${STAGING}" )

  OUT="${DWC_REPO}/dist/${OUT_NAME}"
  if [[ ! -f "${OUT}" ]]; then
    echo "error: expected output missing: ${OUT}" >&2
    ls -la "${DWC_REPO}/dist" >&2 || true
    exit 1
  fi
  cp -f "${OUT}" "${REPO_ROOT}/dist/"
fi

echo "Built: ${REPO_ROOT}/dist/${OUT_NAME}"
