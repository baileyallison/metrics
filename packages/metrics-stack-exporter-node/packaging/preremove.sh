#!/bin/sh
# Runs as %preun (rpm) / prerm (deb) before package files are removed.
set -e

systemctl stop node-exporter 2>/dev/null || true

# If it was auto-registered into the local metrics-stack base's targets.d,
# clean that up too so Prometheus doesn't keep alerting on a target that no
# longer exists.
rm -f /etc/prometheus/targets.d/node.yml
