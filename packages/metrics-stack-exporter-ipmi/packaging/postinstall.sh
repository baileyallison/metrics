#!/bin/sh
# Runs as %post (rpm) / postinst (deb) after package files are laid down.
# POSIX sh -- Debian's /bin/sh is dash, not bash.
set -e

log() { echo "==> $*"; }

log "reloading systemd (runs the Quadlet generator)"
systemctl daemon-reload

log "restarting ipmi-exporter"
systemctl restart ipmi-exporter

if command -v monitoring-add-exporter >/dev/null 2>&1; then
  log "metrics-stack base detected locally -- registering ipmi-exporter target"
  monitoring-add-exporter ipmi host.containers.internal:9290
else
  log "metrics-stack base not found on this host."
  log "On your Prometheus server, run:"
  log "  monitoring-add-exporter ipmi <this-host's-reachable-address>:9290"
fi

if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
  log "opening ipmi-exporter port 9290/tcp via firewalld"
  firewall-cmd --permanent --add-port=9290/tcp
  firewall-cmd --reload
elif command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  log "opening ipmi-exporter port 9290/tcp via ufw"
  ufw allow 9290/tcp
fi

log "done. ipmi-exporter listening on :9290"
log "Note: this reports the LOCAL host's IPMI sensors (needs a real BMC/"
log "/dev/ipmi0 -- on hardware without one, /metrics still responds but"
log "with no sensor data)."
