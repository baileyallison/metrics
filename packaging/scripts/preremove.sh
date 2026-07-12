#!/bin/sh
# Runs as %preun (rpm) / prerm (deb) before package files are removed, on
# both upgrade and full removal -- restarting on upgrade's postinstall is
# idempotent, so we don't special-case "upgrade vs. remove" here.
#
# Data under /var/lib/{prometheus,alertmanager,grafana} is NOT touched --
# it isn't owned by the package manifest, so it survives removal either way.
set -e

for svc in grafana node-exporter alertmanager prometheus metrics-network; do
  systemctl stop "$svc" 2>/dev/null || true
done
