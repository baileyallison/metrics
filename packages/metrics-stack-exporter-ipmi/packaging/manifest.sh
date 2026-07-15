# Packaging manifest for metrics-stack-exporter-ipmi, read by packaging/build.sh.
PKG_NAME="metrics-stack-exporter-ipmi"
PKG_DESCRIPTION="ipmi_exporter for metrics-stack (local host IPMI/BMC sensors: temperature, power, fans, voltage). Standalone -- installs and runs with or without the metrics-stack base package present."
PKG_DEPENDS=(podman)

PKG_FILES=(
  "0644:containers/ipmi-exporter.container:/etc/containers/systemd/ipmi-exporter.container"
)

PKG_CONFIG_FILES=(
  /etc/containers/systemd/ipmi-exporter.container
)

PKG_DIRECTORIES=()

PKG_POSTINSTALL="packaging/postinstall.sh"
PKG_PREREMOVE="packaging/preremove.sh"
