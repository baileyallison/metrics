#!/bin/sh
# Runs as %post (rpm) / postinst (deb) after package files are laid down.
# POSIX sh -- Debian's /bin/sh is dash, not bash.
set -e

log() { echo "==> $*"; }

QUADLET_DIR=/etc/containers/systemd
LOKI_CONF_DIR=/etc/loki

mkdir -p /var/lib/loki

log "reloading systemd (runs the Quadlet generator)"
systemctl daemon-reload

if command -v podman >/dev/null 2>&1; then
  loki_image="$(grep '^Image=' "$QUADLET_DIR/loki.container" | head -1 | cut -d'=' -f2-)"
  log "validating loki config (via $loki_image)"
  podman run --rm -v "$LOKI_CONF_DIR:/etc/loki:ro,Z" "$loki_image" \
    -config.file=/etc/loki/config.yml -verify-config
else
  log "warning: podman not found on PATH -- this package depends on it, check the install"
fi

log "restarting loki"
systemctl restart loki

# Alloy agents on other hosts push logs to 3100, so open it -- same
# rationale as Grafana's 3000. Everything on 3100 is unauthenticated
# (push, query, metrics); keep it inside your trusted network.
if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
  log "opening Loki port 3100/tcp via firewalld"
  firewall-cmd --permanent --add-port=3100/tcp
  firewall-cmd --reload
elif command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  log "opening Loki port 3100/tcp via ufw"
  ufw allow 3100/tcp
fi

# Self-monitoring: Loki serves Prometheus metrics on its HTTP port, so
# register it as a scrape target if metrics-stack-prometheus is local
# (same pattern as the exporter packages and Alertmanager).
if command -v monitoring-add-exporter >/dev/null 2>&1; then
  log "metrics-stack-prometheus detected locally -- registering loki target"
  monitoring-add-exporter loki loki:3100
fi

# Grafana datasource: unlike dashboards, datasource provisioning is only
# read at Grafana startup, hence the try-restart.
if command -v monitoring-add-dashboard >/dev/null 2>&1; then
  log "metrics-stack-grafana detected locally -- provisioning Loki datasource"
  cat > /etc/grafana/provisioning/datasources/loki.yml <<'EOF'
# managed by metrics-stack-loki
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    uid: loki
    # 'loki' resolves via the shared 'metrics' Podman network.
    url: http://loki:3100
    editable: true
EOF
  systemctl try-restart grafana 2>/dev/null || true
fi

log "done. Loki: http://<host>:3100 (push/query API; browse logs via Grafana)"
log "Install metrics-stack-alloy on every host whose logs you want shipped here"
