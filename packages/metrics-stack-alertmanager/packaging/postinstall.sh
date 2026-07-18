#!/bin/sh
# Runs as %post (rpm) / postinst (deb) after package files are laid down.
# POSIX sh -- Debian's /bin/sh is dash, not bash.
set -e

log() { echo "==> $*"; }

QUADLET_DIR=/etc/containers/systemd
AM_CONF_DIR=/etc/alertmanager

mkdir -p /var/lib/alertmanager

log "reloading systemd (runs the Quadlet generator)"
systemctl daemon-reload

if command -v podman >/dev/null 2>&1; then
  am_image="$(grep '^Image=' "$QUADLET_DIR/alertmanager.container" | head -1 | cut -d'=' -f2-)"

  log "validating alertmanager config (via $am_image)"
  # ,U: matches the alertmanager.container Quadlet unit's own mount -- the
  # config directory (and alertmanager.yml specifically, mode 0640 root:root)
  # needs chowning to the container's non-root UID or the image's own
  # 'nobody' user can't read it, even just for this one-off validation run.
  podman run --rm -v "$AM_CONF_DIR:/etc/alertmanager:ro,Z,U" --entrypoint amtool "$am_image" \
    check-config /etc/alertmanager/alertmanager.yml
else
  log "warning: podman not found on PATH -- this package depends on it, check the install"
fi

log "restarting alertmanager"
systemctl restart alertmanager

# If metrics-stack-prometheus is installed on this same host, register
# ourselves as a scrape target automatically (same pattern as the
# metrics-stack-exporter-* packages). 'alertmanager:9093' resolves for
# Prometheus over the shared 'metrics' Podman network -- both containers
# join it, so no host port is involved.
if command -v monitoring-add-exporter >/dev/null 2>&1; then
  log "metrics-stack-prometheus detected locally -- registering alertmanager target"
  monitoring-add-exporter alertmanager alertmanager:9093
else
  log "metrics-stack-prometheus not found on this host."
  log "Prometheus's alerting config expects Alertmanager on the same host's 'metrics'"
  log "network; a remote Prometheus needs alertmanager.yml/alerting config pointed here."
fi

log "done. Alertmanager: http://<host>:9093 (not opened on the firewall -- browse via SSH tunnel/VPN)"
log "Next: monitoring-configure-email --help to set up SMTP alert delivery"
