#!/usr/bin/env bash
# Build a legacy macros-only ZIP (sys + arborctl macros).
# Version is resolved from git tags (see dist/resolve-build-version.sh).
# Usage: ./dist/release.sh [output-zip-name]
#   A version-like first argument is ignored.

set -euo pipefail

WD="${PWD}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=dist/resolve-build-version.sh
. "${ROOT}/dist/resolve-build-version.sh"

PLUGIN_SEMVER="${BUILD_VERSION#v}"
ZIP_NAME="arborctl-${PLUGIN_SEMVER}.zip"

if [ -n "${1:-}" ]; then
  case "$1" in
    v[0-9]*|[0-9]*.[0-9]*)
      echo "warning: ignoring version-like argument '$1'; version is ${BUILD_VERSION} from git tags" >&2
      ;;
    *.zip)
      ZIP_NAME="$1"
      ;;
    *)
      ZIP_NAME="${1}.zip"
      ;;
  esac
fi

TMP_DIR="$(mktemp -d -t arborctl-release-XXXXX)"
ZIP_PATH="${WD}/dist/${ZIP_NAME}"
SYNC_CMD="rsync -a --exclude=README.md"

echo "Building release ${ZIP_NAME} for ${BUILD_VERSION} (${BUILD_SHA})..."

mkdir -p "${WD}/dist"
mkdir -p "${TMP_DIR}/sys" "${TMP_DIR}/macros/ArborCtl" "${TMP_DIR}/sys/arborctl"

${SYNC_CMD} "${ROOT}/sys/"* "${TMP_DIR}/sys/"
${SYNC_CMD} "${ROOT}/macro/public/"* "${TMP_DIR}/macros/ArborCtl/"
${SYNC_CMD} "${ROOT}/macro/private/"* "${TMP_DIR}/sys/arborctl/"
# Numbered metas as *.install so live M2604.g is not overwritten while open
for gcode in "${ROOT}/macro/gcodes/"*.g; do
  base="$(basename "${gcode}" .g)"
  cp -a "${gcode}" "${TMP_DIR}/sys/${base}.install"
done

find "${TMP_DIR}"

[ -f "${ZIP_PATH}" ] && rm "${ZIP_PATH}"

cd "${TMP_DIR}"
echo "Replacing %%ARBORCTL_VERSION%% with ${PLUGIN_SEMVER}..."
sed -si -e "s/%%ARBORCTL_VERSION%%/${PLUGIN_SEMVER}/g" sys/*.g
zip -x 'README.md' -r "${ZIP_PATH}" *
cd "${WD}"
rm -rf "${TMP_DIR}"

echo "Built: ${ZIP_PATH}"
