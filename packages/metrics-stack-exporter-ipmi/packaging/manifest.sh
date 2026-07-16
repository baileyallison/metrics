# shellcheck shell=bash disable=SC2034  # sourced by packaging/build.sh, which uses these vars
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

# postinstall.sh/preremove.sh are generated from packaging/templates/
# exporter-{postinstall,preremove}.sh -- see build.sh's render_template.
# All standalone exporter packages differ only in these four values.
PKG_EXPORTER_SERVICE="ipmi-exporter"
PKG_EXPORTER_JOB="ipmi"
PKG_EXPORTER_PORT="9290"
PKG_EXPORTER_NOTE="$(cat <<'EOF'
log "Note: this reports the LOCAL host's IPMI sensors (needs a real BMC/"
log "/dev/ipmi0 -- on hardware without one, /metrics still responds but"
log "with no sensor data)."
EOF
)"
