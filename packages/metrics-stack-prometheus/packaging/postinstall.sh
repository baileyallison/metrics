#!/bin/sh
# Runs as %post (rpm) / postinst (deb) after package files are laid down.
# POSIX sh -- Debian's /bin/sh is dash, not bash.
set -e

log() { echo "==> $*"; }

QUADLET_DIR=/etc/containers/systemd
PROM_CONF_DIR=/etc/prometheus

mkdir -p /var/lib/prometheus

log "reloading systemd (runs the Quadlet generator)"
systemctl daemon-reload

if command -v podman >/dev/null 2>&1; then
  prom_image="$(grep '^Image=' "$QUADLET_DIR/prometheus.container" | head -1 | cut -d'=' -f2-)"

  log "validating prometheus config (via $prom_image)"
  podman run --rm -v "$PROM_CONF_DIR:/etc/prometheus:ro,Z" --entrypoint promtool "$prom_image" \
    check config /etc/prometheus/prometheus.yml
  for f in "$PROM_CONF_DIR"/rules.d/*.yml; do
    [ -e "$f" ] || continue
    podman run --rm -v "$PROM_CONF_DIR:/etc/prometheus:ro,Z" --entrypoint promtool "$prom_image" \
      check rules "/etc/prometheus/rules.d/$(basename "$f")"
  done
else
  log "warning: podman not found on PATH -- this package depends on it, check the install"
fi

log "restarting prometheus"
systemctl restart prometheus

log "done. Prometheus: http://<host>:9090 (not opened on the firewall -- browse via Grafana or SSH tunnel/VPN)"
log "Next: monitoring-add-exporter --help, or install metrics-stack-exporter-* / metrics-stack-alertmanager / metrics-stack-grafana"
