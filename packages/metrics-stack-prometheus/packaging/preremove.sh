#!/bin/sh
# Runs as %preun (rpm) / prerm (deb) before package files are removed.
#
# Data under /var/lib/prometheus is NOT touched -- it isn't owned by the
# package manifest, so it survives removal either way.
set -e

# Only act on a real uninstall, never on upgrade. This matters on RPM,
# where scriptlet order on upgrade is %post(new) THEN %preun(old) -- an
# unguarded %preun would stop the service right after the new package's
# %post restarted it, leaving it down after `dnf upgrade`. rpm passes $1 as
# the count of instances remaining (0 = full erase, >=1 = upgrade); dpkg
# passes a word ("remove", "upgrade", ...). On deb the ordering is
# prerm(old) then postinst(new), so skipping the upgrade case is harmless
# there too -- postinst restarts everything anyway.
case "${1:-0}" in
  0|remove) ;;
  *) exit 0 ;;
esac

systemctl stop prometheus 2>/dev/null || true
