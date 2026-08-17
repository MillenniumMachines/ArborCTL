#!/usr/bin/env bash
# Build ArborCTL DWC plugin ZIP.
# Usage: build-dwc-plugin.sh [path-to-DuetWebControl]
#   Version is resolved from git tags (see dist/resolve-build-version.sh).
#   Default DWC path: <ArborCTL>/../DuetWebControl
#
# DWC 3.7+ (Vite): npm run build-plugin <staging-dir> writes <staging-dir>/ArborCTL-<semver>.zip
# DWC 3.6.x (webpack): scripts/build-plugin-pkg.js writes under DuetWebControl/dist/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -n "${2:-}" ]; then
  echo "error: version is not a CLI argument; it is resolved from git tags" >&2
  echo "Usage: $0 [path-to-DuetWebControl]" >&2
  exit 1
fi

DWC_REPO="${1:-${REPO_ROOT}/../DuetWebControl}"

if [ ! -d "${REPO_ROOT}/dwc-plugin" ]; then
  echo "error: dwc-plugin not found under ${REPO_ROOT}" >&2
  exit 1
fi

if [ ! -d "${DWC_REPO}" ]; then
  echo "error: DuetWebControl repository not found at ${DWC_REPO}" >&2
  echo "Usage: $0 [path-to-DuetWebControl]" >&2
  exit 1
fi

DWC_REPO="$(cd "${DWC_REPO}" && pwd)"

# shellcheck source=dist/resolve-build-version.sh
. "${REPO_ROOT}/dist/resolve-build-version.sh"

PLUGIN_SEMVER="${BUILD_VERSION#v}"
DWC_PLUGIN_ZIP="ArborCTL-${PLUGIN_SEMVER}.zip"
EXACT_TAG="$(git -C "${REPO_ROOT}" describe --tags --exact-match HEAD 2>/dev/null || true)"
DIRTY_SUFFIX=""
if ! git -C "${REPO_ROOT}" diff-index --quiet HEAD --; then
  DIRTY_SUFFIX="-dirty"
fi
ON_TAG_REF=0
case "${GITHUB_REF:-}" in
  refs/tags/*) ON_TAG_REF=1 ;;
esac
if [ -n "${EXACT_TAG}" ] || [ "${ON_TAG_REF}" = "1" ]; then
  OUT_NAME="${DWC_PLUGIN_ZIP}"
else
  OUT_NAME="ArborCTL-${PLUGIN_SEMVER}-${BUILD_SHA}${DIRTY_SUFFIX}.zip"
fi

chmod +x "${REPO_ROOT}/dist/check-node-for-dwc-build.sh"
"${REPO_ROOT}/dist/check-node-for-dwc-build.sh"

DWC_BUILDER="$(node "${REPO_ROOT}/dist/detect-dwc-plugin-builder.mjs" "${DWC_REPO}")"
echo "DWC plugin builder: ${DWC_BUILDER}"
echo "ArborCTL plugin build: embedded ${BUILD_VERSION} (plugin.json ${PLUGIN_SEMVER}, zip ${OUT_NAME})"

STAGING="$(mktemp -d "${TMPDIR:-/tmp}/arborctl-dwc-XXXXXX")"
cleanup() { rm -rf "${STAGING}"; }
trap cleanup EXIT

echo "Staging DWC plugin (version ${PLUGIN_SEMVER})..."

cp -a "${REPO_ROOT}/dwc-plugin/." "${STAGING}/"

mkdir -p "${STAGING}/sd/sys/arborctl"
cp -a "${REPO_ROOT}/sys/." "${STAGING}/sd/sys/"
# Numbered metas as *.install so DSF does not delete live 0:/sys/M2604.g
for gcode in "${REPO_ROOT}/macro/gcodes/"*.g; do
  base="$(basename "${gcode}" .g)"
  cp -a "${gcode}" "${STAGING}/sd/sys/${base}.install"
done
cp -a "${REPO_ROOT}/macro/private/." "${STAGING}/sd/sys/arborctl/"

# NeXT data.nxt entrypoints → 0:/sys/plugins/arborctl/
if [ -d "${REPO_ROOT}/sd/sys/plugins/arborctl" ]; then
  mkdir -p "${STAGING}/sd/sys/plugins/arborctl"
  cp -a "${REPO_ROOT}/sd/sys/plugins/arborctl/." "${STAGING}/sd/sys/plugins/arborctl/"
fi

while IFS= read -r -d '' f; do
  if grep -q '%%ARBORCTL_VERSION%%' "$f" 2>/dev/null; then
    sed -i.bak "s/%%ARBORCTL_VERSION%%/${PLUGIN_SEMVER}/g" "$f" && rm -f "${f}.bak"
  fi
done < <(find "${STAGING}" -type f \( -name '*.g' -o -name '*.install' -o -name '*.example' -o -name 'plugin.json' \) -print0)

mkdir -p "${REPO_ROOT}/dist"

if [ "${DWC_BUILDER}" = "vite" ]; then
  echo "Running DuetWebControl npm run build-plugin (Vite)..."
  (
    cd "${DWC_REPO}"
    if [ ! -d node_modules ]; then
      npm ci || npm install
    fi
    npm run build-plugin -- "${STAGING}"
  )

  OUT=""
  if [ -f "${STAGING}/${DWC_PLUGIN_ZIP}" ]; then
    OUT="${STAGING}/${DWC_PLUGIN_ZIP}"
  else
    shopt -s nullglob
    _cands=("${STAGING}"/ArborCTL-*.zip "${DWC_REPO}/dist"/ArborCTL-*.zip)
    shopt -u nullglob
    if [ "${#_cands[@]}" -gt 0 ]; then
      OUT="${_cands[0]}"
      echo "warning: using unexpected ZIP name ${OUT} (expected ${DWC_PLUGIN_ZIP})" >&2
    fi
  fi
  if [ -z "${OUT}" ] || [ ! -f "${OUT}" ]; then
    echo "error: expected Vite output missing: ${STAGING}/${DWC_PLUGIN_ZIP}" >&2
    ls -la "${STAGING}" >&2 || true
    exit 1
  fi
  cp -f "${OUT}" "${REPO_ROOT}/dist/${OUT_NAME}"
else
  if [ ! -f "${DWC_REPO}/scripts/build-plugin-pkg.js" ]; then
    echo "error: webpack builder expected but ${DWC_REPO}/scripts/build-plugin-pkg.js missing" >&2
    exit 1
  fi
  echo "Running DuetWebControl scripts/build-plugin-pkg.js (webpack)..."
  ( cd "${DWC_REPO}" && node scripts/build-plugin-pkg.js "${STAGING}" )

  OUT="${DWC_REPO}/dist/${DWC_PLUGIN_ZIP}"
  if [ ! -f "${OUT}" ]; then
    echo "error: expected output missing: ${OUT}" >&2
    ls -la "${DWC_REPO}/dist" >&2 || true
    exit 1
  fi
  cp -f "${OUT}" "${REPO_ROOT}/dist/${OUT_NAME}"
fi

echo "Built: ${REPO_ROOT}/dist/${OUT_NAME}"
