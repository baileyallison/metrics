#!/bin/sh
# Runs as %post (rpm) / postinst (deb) after package files are laid down.
# POSIX sh -- Debian's /bin/sh is dash, not bash.
#
# This is a template: packaging/build.sh substitutes this exporter's
# service/job/port (and an optional note) from PKG_EXPORTER_* in its
# packaging/manifest.sh, and embeds the result into the built package. Edit
# this file, not a package's own copy -- there isn't one; it's generated at
# build time.
set -e

log() { echo "==> $*"; }

log "reloading systemd (runs the Quadlet generator)"
systemctl daemon-reload

log "restarting @SERVICE@"
systemctl restart @SERVICE@

# If metrics-stack-prometheus is installed on this same host, register
# ourselves automatically. host.containers.internal is how a container on
# the stack's 'metrics' bridge network (i.e. Prometheus) reaches this host,
# since this exporter itself uses Network=host, not that bridge network.
if command -v monitoring-add-exporter >/dev/null 2>&1; then
  log "metrics-stack-prometheus detected locally -- registering @SERVICE@ target"
  monitoring-add-exporter @JOB@ host.containers.internal:@PORT@
else
  log "metrics-stack-prometheus not found on this host."
  log "On your Prometheus server, run:"
  log "  monitoring-add-exporter @JOB@ <this-host's-reachable-address>:@PORT@"
fi

if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
  log "opening @SERVICE@ port @PORT@/tcp via firewalld"
  firewall-cmd --permanent --add-port=@PORT@/tcp
  firewall-cmd --reload
elif command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  log "opening @SERVICE@ port @PORT@/tcp via ufw"
  ufw allow @PORT@/tcp
fi

log "done. @SERVICE@ listening on :@PORT@"
@NOTE@
