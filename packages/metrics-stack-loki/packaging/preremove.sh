#!/bin/sh
# Runs as %preun (rpm) / prerm (deb) before package files are removed.
#
# Data under /var/lib/loki is NOT touched -- it isn't owned by the package
# manifest, so it survives removal either way.
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

systemctl stop loki 2>/dev/null || true

# Deregister from the local Prometheus, if we registered.
rm -f /etc/prometheus/targets.d/loki.yml

# Remove the provisioned Grafana datasource. The YAML must be gone before
# Grafana restarts (datasource provisioning is read at startup only). The
# datasource entry itself lingers in Grafana's DB until removed in the UI --
# provisioning files can't delete on our behalf once they're gone.
rm -f /etc/grafana/provisioning/datasources/loki.yml
systemctl try-restart grafana 2>/dev/null || true

# Close the Loki port the postinstall opened.
if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --remove-port=3100/tcp || true
  firewall-cmd --reload || true
elif command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw delete allow 3100/tcp || true
fi
