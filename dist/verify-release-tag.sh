#!/usr/bin/env bash
# Verify a git tag name is allowed to trigger release CI.
# Usage: ./dist/verify-release-tag.sh <tag>

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=dist/semver-version.sh
. "${ROOT}/dist/semver-version.sh"

TAG="${1:?tag required}"

if ! is_release_version "${TAG}"; then
  echo "error: build allowed only for release tags ($(semver_version_formats_hint)); got: ${TAG}" >&2
  exit 1
fi

echo "Tag build OK: ${TAG}"
