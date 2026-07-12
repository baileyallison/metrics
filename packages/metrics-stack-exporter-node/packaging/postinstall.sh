#!/bin/sh
# Runs as %post (rpm) / postinst (deb) after package files are laid down.
# POSIX sh -- Debian's /bin/sh is dash, not bash.
set -e

log() { echo "==> $*"; }

log "reloading systemd (runs the Quadlet generator)"
systemctl daemon-reload

log "restarting node-exporter"
systemctl restart node-exporter

# If the metrics-stack base package is installed on this same host, register
# ourselves automatically. host.containers.internal is how a container on
# the base's 'metrics' bridge network (i.e. Prometheus) reaches this host,
# since node-exporter itself uses Network=host, not that bridge network.
if command -v monitoring-add-exporter >/dev/null 2>&1; then
  log "metrics-stack base detected locally -- registering node-exporter target"
  monitoring-add-exporter node host.containers.internal:9100
else
  log "metrics-stack base not found on this host."
  log "On your Prometheus server, run:"
  log "  monitoring-add-exporter node <this-host's-reachable-address>:9100"
fi

if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
  log "opening node-exporter port 9100/tcp via firewalld"
  firewall-cmd --permanent --add-port=9100/tcp
  firewall-cmd --reload
elif command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  log "opening node-exporter port 9100/tcp via ufw"
  ufw allow 9100/tcp
fi

log "done. node-exporter listening on :9100"
