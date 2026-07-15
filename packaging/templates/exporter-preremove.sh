#!/bin/sh
# Runs as %preun (rpm) / prerm (deb) before package files are removed.
#
# This is a template: packaging/build.sh substitutes this exporter's
# service/job from PKG_EXPORTER_* in its packaging/manifest.sh, and embeds
# the result into the built package. Edit this file, not a package's own
# copy -- there isn't one; it's generated at build time.
set -e

systemctl stop @SERVICE@ 2>/dev/null || true

# If it was auto-registered into the local metrics-stack base's targets.d,
# clean that up too so Prometheus doesn't keep alerting on a target that no
# longer exists.
rm -f /etc/prometheus/targets.d/@JOB@.yml
