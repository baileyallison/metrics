# Packaging manifest for metrics-stack-exporter-smartctl, read by packaging/build.sh.
PKG_NAME="metrics-stack-exporter-smartctl"
PKG_DESCRIPTION="smartctl_exporter for metrics-stack (disk S.M.A.R.T. metrics). Standalone -- installs and runs with or without the metrics-stack base package present."
PKG_DEPENDS=(podman)

PKG_FILES=(
  "0644:containers/smartctl-exporter.container:/etc/containers/systemd/smartctl-exporter.container"
)

PKG_CONFIG_FILES=(
  /etc/containers/systemd/smartctl-exporter.container
)

PKG_DIRECTORIES=()

PKG_POSTINSTALL="packaging/postinstall.sh"
PKG_PREREMOVE="packaging/preremove.sh"
