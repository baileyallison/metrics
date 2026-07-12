# Packaging manifest for metrics-stack-exporter-node, read by packaging/build.sh.
PKG_NAME="metrics-stack-exporter-node"
PKG_DESCRIPTION="node_exporter for metrics-stack. Standalone -- installs and runs with or without the metrics-stack base package present."
PKG_DEPENDS=(podman)

PKG_FILES=(
  "0644:containers/node-exporter.container:/etc/containers/systemd/node-exporter.container"
)

PKG_CONFIG_FILES=(
  /etc/containers/systemd/node-exporter.container
)

PKG_DIRECTORIES=()

PKG_POSTINSTALL="packaging/postinstall.sh"
PKG_PREREMOVE="packaging/preremove.sh"
