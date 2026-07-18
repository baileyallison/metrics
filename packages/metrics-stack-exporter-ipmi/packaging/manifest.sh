# shellcheck shell=bash disable=SC2034  # sourced by packaging/build.sh, which uses these vars
# Packaging manifest for metrics-stack-exporter-ipmi, read by packaging/build.sh.
# containers/ is staged to /etc/containers/systemd/ (and marked config) by
# convention; postinstall/preremove/postremove come from packaging/templates/
# exporter-*.sh, rendered with the PKG_EXPORTER_* values below. All standalone
# exporter packages differ only in these values.
PKG_NAME="metrics-stack-exporter-ipmi"
PKG_DESCRIPTION="ipmi_exporter for metrics-stack (local host IPMI/BMC sensors: temperature, power, fans, voltage). Standalone -- installs and runs with or without the metrics-stack packages present."
PKG_DEPENDS=(podman)

PKG_EXPORTER_SERVICE="ipmi-exporter"
PKG_EXPORTER_JOB="ipmi"
PKG_EXPORTER_PORT="9290"
PKG_EXPORTER_NOTE="$(cat <<'EOF'
log "Note: this reports the LOCAL host's IPMI sensors (needs a real BMC/"
log "/dev/ipmi0 -- on hardware without one, /metrics still responds but"
log "with no sensor data)."
EOF
)"
