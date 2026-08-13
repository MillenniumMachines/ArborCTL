#!/usr/bin/env bash
# Shared ArborCTL release version patterns (stable, beta, release candidate).
#
#   vMAJOR.MINOR.PATCH           e.g. v0.6.0
#   vMAJOR.MINOR.PATCH-beta.N    e.g. v0.6.0-beta.16
#   vMAJOR.MINOR.PATCH-rcN       e.g. v0.6.0-rc1  (no dot before rc number)
#
# Usage:
#   . dist/semver-version.sh
#   is_release_version v0.6.0-rc1 && echo ok

is_stable_version() {
  [[ "${1}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

is_beta_version() {
  [[ "${1}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-beta\.[0-9]+$ ]]
}

is_rc_version() {
  [[ "${1}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-rc[0-9]+$ ]]
}

is_release_version() {
  is_stable_version "${1}" || is_beta_version "${1}" || is_rc_version "${1}"
}

semver_version_formats_hint() {
  printf '%s' 'vMAJOR.MINOR.PATCH, vMAJOR.MINOR.PATCH-beta.N, or vMAJOR.MINOR.PATCH-rcN (e.g. v0.6.0-rc1)'
}
