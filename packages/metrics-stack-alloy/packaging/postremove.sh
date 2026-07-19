#!/bin/sh
# Runs as %postun (rpm) / postrm (deb) after package files are removed.
#
# Quadlet generates the real systemd units from the .container/.network
# files at daemon-reload time, so after those files are gone we reload once
# more or systemd keeps the stale generated units around until something
# else reloads. Harmless on upgrade too -- reload is idempotent.
systemctl daemon-reload 2>/dev/null || true
