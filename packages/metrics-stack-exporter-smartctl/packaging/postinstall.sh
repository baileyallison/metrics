#!/bin/sh
# Runs as %post (rpm) / postinst (deb) after package files are laid down.
# POSIX sh -- Debian's /bin/sh is dash, not bash.
set -e

log() { echo "==> $*"; }

log "reloading systemd (runs the Quadlet generator)"
systemctl daemon-reload

log "restarting smartctl-exporter"
systemctl restart smartctl-exporter

if command -v monitoring-add-exporter >/dev/null 2>&1; then
  log "metrics-stack base detected locally -- registering smartctl-exporter target"
  monitoring-add-exporter smartctl host.containers.internal:9633
else
  log "metrics-stack base not found on this host."
  log "On your Prometheus server, run:"
  log "  monitoring-add-exporter smartctl <this-host's-reachable-address>:9633"
fi

if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
  log "opening smartctl-exporter port 9633/tcp via firewalld"
  firewall-cmd --permanent --add-port=9633/tcp
  firewall-cmd --reload
elif command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  log "opening smartctl-exporter port 9633/tcp via ufw"
  ufw allow 9633/tcp
fi

log "done. smartctl-exporter listening on :9633"
