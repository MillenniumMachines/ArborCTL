#!/usr/bin/env bash
WD="${PWD}"
TMP_DIR=$(mktemp -d -t arborctl-release-XXXXX)
ZIP_NAME="${1:-arborctl-release}.zip"
ZIP_PATH="${WD}/dist/${ZIP_NAME}"
SYNC_CMD="rsync -a --exclude=README.md"
COMMIT_ID=$(git describe --tags --exclude "release-*" --always --dirty)

echo "Building release ${ZIP_NAME} for ${COMMIT_ID}..."

# Make stub folder-structure
mkdir -p ${TMP_DIR}/{sys,macros,macros/ArborCtl,sys/arborctl}

# Copy files to correct location in temp dir
${SYNC_CMD} sys/* ${TMP_DIR}/sys/
${SYNC_CMD} macro/public/* ${TMP_DIR}/macros/ArborCtl
${SYNC_CMD} macro/private/* ${TMP_DIR}/sys/arborctl
${SYNC_CMD} macro/gcodes/* ${TMP_DIR}/sys/

find ${TMP_DIR}

[[ -f "${ZIP_PATH}" ]] && rm "${ZIP_PATH}"

cd "${TMP_DIR}"
echo "Replacing %%ARBORCTL_VERSION%% with ${COMMIT_ID}..."
sed -si -e "s/%%ARBORCTL_VERSION%%/${COMMIT_ID}/g" sys/*.g
zip -x 'README.md' -r "${ZIP_PATH}" *
cd "${WD}"
rm -rf "${TMP_DIR}"
