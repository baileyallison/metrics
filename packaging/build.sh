#!/usr/bin/env bash
# Builds a .rpm and .deb for every package under packages/*/, using fpm.
# Each package directory must have a packaging/manifest.sh describing what
# to ship (see any packages/*/packaging/manifest.sh for the format).
#
# Requires: fpm (gem install --no-document fpm), plus rpm-build tools if
# building the .rpm on a non-EL host, and dpkg-deb (present on any Debian-
# family system) for the .deb.
#
# Usage: packaging/build.sh <version>   (e.g. 1.0.0 -- no leading 'v')
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:?Usage: packaging/build.sh <version> (e.g. 1.0.0, no leading v)}"
ITERATION=1
OUT_DIR="$REPO_DIR/dist"

if ! command -v fpm >/dev/null 2>&1; then
  echo "error: fpm not found. Install with: gem install --no-document fpm" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

build_package() {
  local pkg_dir="$1"

  # Reset manifest variables so nothing leaks between packages in this loop.
  PKG_NAME=""
  PKG_DESCRIPTION=""
  PKG_DEPENDS=()
  PKG_FILES=()
  PKG_CONFIG_FILES=()
  PKG_DIRECTORIES=()
  PKG_POSTINSTALL=""
  PKG_PREREMOVE=""
  # shellcheck disable=SC1090
  source "$pkg_dir/packaging/manifest.sh"

  echo "=== building $PKG_NAME ==="

  local stage
  stage="$(mktemp -d)"
  trap 'rm -rf "$stage"' RETURN

  local entry mode rest src dest
  for entry in "${PKG_FILES[@]}"; do
    mode="${entry%%:*}"
    rest="${entry#*:}"
    src="${rest%%:*}"
    dest="${rest#*:}"
    install -D -m "$mode" "$pkg_dir/$src" "$stage$dest"
  done

  local d
  for d in "${PKG_DIRECTORIES[@]}"; do
    mkdir -p "$stage$d"
  done

  local common_args=(
    -s dir
    -n "$PKG_NAME"
    -v "$VERSION"
    --iteration "$ITERATION"
    --license GPL-3.0
    --url "https://github.com/baileyallison/metrics"
    --description "$PKG_DESCRIPTION"
    --chdir "$stage"
  )

  local dep
  for dep in "${PKG_DEPENDS[@]:-}"; do
    [[ -n "$dep" ]] && common_args+=(--depends "$dep")
  done

  local cf
  for cf in "${PKG_CONFIG_FILES[@]:-}"; do
    [[ -n "$cf" ]] && common_args+=(--config-files "$cf")
  done

  if [[ -n "$PKG_POSTINSTALL" ]]; then
    common_args+=(--after-install "$pkg_dir/$PKG_POSTINSTALL")
  fi
  if [[ -n "$PKG_PREREMOVE" ]]; then
    common_args+=(--before-remove "$pkg_dir/$PKG_PREREMOVE")
  fi

  # fpm needs at least one input path -- pass whichever top-level FHS dirs
  # actually got staged for this package.
  local inputs=()
  local top
  for top in etc usr var; do
    [[ -d "$stage/$top" ]] && inputs+=("$top")
  done

  echo "--- rpm ---"
  fpm "${common_args[@]}" -t rpm -a noarch \
    -p "$OUT_DIR/${PKG_NAME}-${VERSION}-${ITERATION}.noarch.rpm" \
    "${inputs[@]}"

  echo "--- deb ---"
  fpm "${common_args[@]}" -t deb -a all \
    -p "$OUT_DIR/${PKG_NAME}_${VERSION}-${ITERATION}_all.deb" \
    "${inputs[@]}"
}

for pkg_dir in "$REPO_DIR"/packages/*/; do
  build_package "${pkg_dir%/}"
done

echo "=== built: ==="
ls -la "$OUT_DIR"
