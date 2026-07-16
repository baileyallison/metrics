# shellcheck shell=bash disable=SC2034  # sourced by packaging/build.sh, which uses these vars
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

# postinstall.sh/preremove.sh are generated from packaging/templates/
# exporter-{postinstall,preremove}.sh -- see build.sh's render_template.
# All standalone exporter packages differ only in these four values.
PKG_EXPORTER_SERVICE="node-exporter"
PKG_EXPORTER_JOB="node"
PKG_EXPORTER_PORT="9100"
PKG_EXPORTER_NOTE=""
