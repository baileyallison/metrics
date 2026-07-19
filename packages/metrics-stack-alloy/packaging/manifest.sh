# shellcheck shell=bash disable=SC2034  # sourced by packaging/build.sh, which uses these vars
# Packaging manifest for metrics-stack-alloy, read by packaging/build.sh.
#
# Standalone agent, exporter-style: depends on podman only, installs on any
# host whose logs you want shipped, with or without the rest of the stack
# present. Logs-only by design -- metrics stay on the exporter packages +
# Prometheus pull model.
PKG_NAME="metrics-stack-alloy"
PKG_DESCRIPTION="Grafana Alloy log collector for metrics-stack: ships journald + /var/log/*.log to Loki (metrics-stack-loki, local or remote). Standalone -- installs and runs with or without the other metrics-stack packages present."
PKG_DEPENDS=(podman)

# containers/ is staged to /etc/containers/systemd/ by convention (see
# packaging/build.sh) -- only files outside that convention are listed here.
PKG_FILES=(
  "0644:alloy/config.alloy:/etc/alloy/config.alloy"
)

# Convention-staged files (containers/) are marked config automatically.
PKG_CONFIG_FILES=(
  /etc/alloy/config.alloy
)

PKG_DIRECTORIES=(
  /var/lib/alloy
)

PKG_POSTINSTALL="packaging/postinstall.sh"
PKG_PREREMOVE="packaging/preremove.sh"
PKG_POSTREMOVE="packaging/postremove.sh"
