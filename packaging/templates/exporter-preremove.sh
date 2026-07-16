#!/bin/sh
# Runs as %preun (rpm) / prerm (deb) before package files are removed.
#
# This is a template: packaging/build.sh substitutes this exporter's
# service/job/port from PKG_EXPORTER_* in its packaging/manifest.sh, and
# embeds the result into the built package. Edit this file, not a package's
# own copy -- there isn't one; it's generated at build time.
set -e

# Only act on a real uninstall, never on upgrade. This matters on RPM,
# where scriptlet order on upgrade is %post(new) THEN %preun(old) -- an
# unguarded %preun would stop the service and deregister the target right
# after the new package's %post set them up. rpm passes $1 as the count of
# instances remaining (0 = full erase, >=1 = upgrade); dpkg passes a word
# ("remove", "upgrade", ...).
case "${1:-0}" in
  0|remove) ;;
  *) exit 0 ;;
esac

systemctl stop @SERVICE@ 2>/dev/null || true

# If it was auto-registered into the local metrics-stack base's targets.d,
# clean that up too so Prometheus doesn't keep alerting on a target that no
# longer exists.
rm -f /etc/prometheus/targets.d/@JOB@.yml

# Close the port the postinstall opened.
if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --remove-port=@PORT@/tcp || true
  firewall-cmd --reload || true
elif command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw delete allow @PORT@/tcp || true
fi
