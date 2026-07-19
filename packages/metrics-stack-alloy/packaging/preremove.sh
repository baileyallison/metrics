#!/bin/sh
# Runs as %preun (rpm) / prerm (deb) before package files are removed.
#
# Positions/WAL under /var/lib/alloy are NOT touched -- not owned by the
# package manifest, so they survive removal either way.
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

systemctl stop alloy 2>/dev/null || true
