#!/bin/sh
# Runs as %post (rpm) / postinst (deb) after package files are laid down.
# POSIX sh -- Debian's /bin/sh is dash, not bash.
set -e

log() { echo "==> $*"; }

log "reloading systemd (runs the Quadlet generator)"
systemctl daemon-reload

log "restarting metrics-network"
systemctl restart metrics-network
