#!/usr/bin/env bash
# Resolve ArborCTL BUILD_VERSION from git tags.
#
# Usage (source from other scripts):
#   . dist/resolve-build-version.sh
#   # exports BUILD_VERSION, BUILD_REF, BUILD_SHA, ARBORCTL_REPO_ROOT
#
# BUILD_VERSION order:
#   1. ARBORCTL_BUILD_REF_OVERRIDE
#   2. GITHUB_REF tag (refs/tags/*)
#   3. Exact tag on HEAD (git describe --tags --exact-match)
#   4. Nearest tag (git describe --tags --abbrev=0)
#
# Optional env:
#   ARBORCTL_BUILD_REF_OVERRIDE — force ref (e.g. v0.7.1)
#   ARBORCTL_PRINT_BUILD_VERSION=1 — print resolved values to stdout

set -euo pipefail

ARBORCTL_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exact_tag() {
  git -C "${ARBORCTL_REPO_ROOT}" describe --tags --exact-match HEAD 2>/dev/null || true
}

nearest_tag() {
  git -C "${ARBORCTL_REPO_ROOT}" describe --tags --abbrev=0 2>/dev/null || true
}

resolve_build_ref() {
  if [ -n "${ARBORCTL_BUILD_REF_OVERRIDE:-}" ]; then
    printf '%s' "${ARBORCTL_BUILD_REF_OVERRIDE}"
    return 0
  fi
  case "${GITHUB_REF:-}" in
    refs/tags/*)
      if [ -n "${GITHUB_REF_NAME:-}" ]; then
        printf '%s' "${GITHUB_REF_NAME}"
        return 0
      fi
      ;;
  esac
  _exact="$(exact_tag)"
  if [ -n "${_exact}" ]; then
    printf '%s' "${_exact}"
    return 0
  fi
  _near="$(nearest_tag)"
  if [ -n "${_near}" ]; then
    printf '%s' "${_near}"
    return 0
  fi
  echo "error: no git tags found; cannot resolve BUILD_VERSION" >&2
  return 1
}

BUILD_REF="$(resolve_build_ref)"
BUILD_VERSION="${BUILD_REF}"
BUILD_SHA="$(git -C "${ARBORCTL_REPO_ROOT}" rev-parse --short HEAD)"

export BUILD_REF BUILD_VERSION BUILD_SHA ARBORCTL_REPO_ROOT

if [ "${ARBORCTL_PRINT_BUILD_VERSION:-}" = "1" ]; then
  echo "BUILD_REF=${BUILD_REF}"
  echo "BUILD_VERSION=${BUILD_VERSION}"
  echo "BUILD_SHA=${BUILD_SHA}"
fi
