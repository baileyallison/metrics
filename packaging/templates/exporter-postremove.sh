#!/bin/sh
# Runs as %postun (rpm) / postrm (deb) after package files are removed.
#
# This is a template: packaging/build.sh embeds it into every standalone
# exporter package (it needs no per-package substitutions, but lives with
# the other exporter templates). Edit this file, not a package's own copy
# -- there isn't one; it's generated at build time.
#
# Quadlet generates the real systemd unit from the .container file at
# daemon-reload time, so after the .container file is gone we reload once
# more or systemd keeps the stale generated unit around until something
# else reloads. Harmless on upgrade too -- reload is idempotent.
systemctl daemon-reload 2>/dev/null || true
