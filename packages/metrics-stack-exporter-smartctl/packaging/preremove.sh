#!/bin/sh
# Runs as %preun (rpm) / prerm (deb) before package files are removed.
set -e

systemctl stop smartctl-exporter 2>/dev/null || true
rm -f /etc/prometheus/targets.d/smartctl.yml
