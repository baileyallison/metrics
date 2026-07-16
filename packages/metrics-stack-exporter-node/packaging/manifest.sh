# shellcheck shell=bash disable=SC2034  # sourced by packaging/build.sh, which uses these vars
# Packaging manifest for metrics-stack-exporter-node, read by packaging/build.sh.
# containers/ is staged to /etc/containers/systemd/ (and marked config) by
# convention; postinstall/preremove/postremove come from packaging/templates/
# exporter-*.sh, rendered with the PKG_EXPORTER_* values below. All standalone
# exporter packages differ only in these values.
PKG_NAME="metrics-stack-exporter-node"
PKG_DESCRIPTION="node_exporter for metrics-stack. Standalone -- installs and runs with or without the metrics-stack base package present."
PKG_DEPENDS=(podman)

PKG_EXPORTER_SERVICE="node-exporter"
PKG_EXPORTER_JOB="node"
PKG_EXPORTER_PORT="9100"
PKG_EXPORTER_NOTE=""
