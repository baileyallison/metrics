#!/bin/sh
# Runs as %post (rpm) / postinst (deb) after package files are laid down.
# POSIX sh -- Debian's /bin/sh is dash, not bash.
set -e

log() { echo "==> $*"; }

mkdir -p /var/lib/grafana/dashboards

log "reloading systemd (runs the Quadlet generator)"
systemctl daemon-reload

log "restarting grafana"
systemctl restart grafana

if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
  log "opening Grafana port 3000/tcp via firewalld"
  firewall-cmd --permanent --add-port=3000/tcp
  firewall-cmd --reload
elif command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  log "opening Grafana port 3000/tcp via ufw"
  ufw allow 3000/tcp
fi

log "done. Grafana: http://<host>:3000 (default admin/admin, change on first login)"
log "The provisioned datasource expects Prometheus on this host's 'metrics' network;"
log "if Prometheus runs elsewhere, edit /etc/grafana/provisioning/datasources/prometheus.yml"
log "Next: monitoring-add-dashboard --help, or install the metrics-stack-dashboards-* packages"
