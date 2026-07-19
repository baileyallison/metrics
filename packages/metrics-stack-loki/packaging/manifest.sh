# shellcheck shell=bash disable=SC2034  # sourced by packaging/build.sh, which uses these vars
# Packaging manifest for metrics-stack-loki, read by packaging/build.sh.
PKG_NAME="metrics-stack-loki"
PKG_DESCRIPTION="Loki log aggregation for metrics-stack (Podman Quadlet container), filesystem storage, 30d retention. Receives logs from metrics-stack-alloy agents; auto-registers with local Prometheus/Grafana when present. Opt-in -- not part of the metrics-stack metapackage."
PKG_DEPENDS=(podman metrics-stack-common)

# containers/ is staged to /etc/containers/systemd/ by convention (see
# packaging/build.sh) -- only files outside that convention are listed here.
PKG_FILES=(
  "0644:loki/config.yml:/etc/loki/config.yml"
)

# Convention-staged files (containers/) are marked config automatically.
PKG_CONFIG_FILES=(
  /etc/loki/config.yml
)

PKG_DIRECTORIES=(
  /var/lib/loki
)

PKG_POSTINSTALL="packaging/postinstall.sh"
PKG_PREREMOVE="packaging/preremove.sh"
PKG_POSTREMOVE="packaging/postremove.sh"
