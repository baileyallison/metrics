#!/bin/sh
# Runs as %post (rpm) / postinst (deb) after package files are laid down.
# POSIX sh -- Debian's /bin/sh is dash, not bash.
set -e

log() { echo "==> $*"; }

QUADLET_DIR=/etc/containers/systemd
PROM_CONF_DIR=/etc/prometheus
AM_CONF_DIR=/etc/alertmanager

mkdir -p /var/lib/prometheus /var/lib/alertmanager /var/lib/grafana/dashboards

log "reloading systemd (runs the Quadlet generator)"
systemctl daemon-reload

image_from_unit() {
  grep '^Image=' "$QUADLET_DIR/$1" | head -1 | cut -d'=' -f2-
}

if command -v podman >/dev/null 2>&1; then
  prom_image="$(image_from_unit prometheus.container)"
  am_image="$(image_from_unit alertmanager.container)"

  log "validating prometheus config (via $prom_image)"
  podman run --rm -v "$PROM_CONF_DIR:/etc/prometheus:ro,Z" --entrypoint promtool "$prom_image" \
    check config /etc/prometheus/prometheus.yml
  for f in "$PROM_CONF_DIR"/rules.d/*.yml; do
    [ -e "$f" ] || continue
    podman run --rm -v "$PROM_CONF_DIR:/etc/prometheus:ro,Z" --entrypoint promtool "$prom_image" \
      check rules "/etc/prometheus/rules.d/$(basename "$f")"
  done

  log "validating alertmanager config (via $am_image)"
  podman run --rm -v "$AM_CONF_DIR:/etc/alertmanager:ro,Z" --entrypoint amtool "$am_image" \
    check-config /etc/alertmanager/alertmanager.yml
else
  log "warning: podman not found on PATH -- this package depends on it, check the install"
fi

for svc in metrics-network prometheus alertmanager node-exporter grafana; do
  log "restarting $svc"
  systemctl restart "$svc"
done

if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
  log "opening Grafana port 3000/tcp via firewalld"
  firewall-cmd --permanent --add-port=3000/tcp
  firewall-cmd --reload
elif command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  log "opening Grafana port 3000/tcp via ufw"
  ufw allow 3000/tcp
fi

log "done. Grafana: http://<host>:3000 (default admin/admin, change on first login)"
log "Next: monitoring-configure-email --help, monitoring-add-exporter --help, monitoring-add-dashboard --help"
