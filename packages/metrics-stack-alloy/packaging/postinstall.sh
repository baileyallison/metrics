#!/bin/sh
# Runs as %post (rpm) / postinst (deb) after package files are laid down.
# POSIX sh -- Debian's /bin/sh is dash, not bash.
set -e

log() { echo "==> $*"; }

mkdir -p /var/lib/alloy

log "reloading systemd (runs the Quadlet generator)"
systemctl daemon-reload

log "restarting alloy"
systemctl restart alloy

if [ -f /etc/containers/systemd/loki.container ]; then
  log "metrics-stack-loki detected locally -- shipping logs to it (127.0.0.1:3100)"
else
  log "metrics-stack-loki not found on this host. Point alloy at your Loki server:"
  log "  echo 'LOKI_URL=http://<loki-host>:3100/loki/api/v1/push' > /etc/alloy/loki.env"
  log "  systemctl restart alloy"
fi

log "done. Shipping journald + /var/log/*.log; see /etc/alloy/config.alloy"
