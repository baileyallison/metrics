#!/bin/sh
# Runs as %preun (rpm) / prerm (deb) before package files are removed.
#
# Data under /var/lib/alertmanager is NOT touched -- it isn't owned by the
# package manifest, so it survives removal either way.
set -e

# Only act on a real uninstall, never on upgrade. This matters on RPM,
# where scriptlet order on upgrade is %post(new) THEN %preun(old) -- an
# unguarded %preun would stop the service and deregister the target right
# after the new package's %post set them up. rpm passes $1 as the count of
# instances remaining (0 = full erase, >=1 = upgrade); dpkg passes a word
# ("remove", "upgrade", ...). On deb the ordering is prerm(old) then
# postinst(new), so skipping the upgrade case is harmless there too --
# postinst restarts everything anyway.
case "${1:-0}" in
  0|remove) ;;
  *) exit 0 ;;
esac

systemctl stop alertmanager 2>/dev/null || true

# If it was auto-registered into the local metrics-stack-prometheus's
# targets.d/alertmanagers.d, clean that up too so Prometheus doesn't keep
# alerting on a target (or notifying an instance) that no longer exists.
rm -f /etc/prometheus/targets.d/alertmanager.yml
rm -f /etc/prometheus/alertmanagers.d/local.yml /etc/prometheus/alertmanagers.d/peers.yml

# Clustering leftovers: cluster.args isn't in the package manifest (it's
# written by monitoring-configure-cluster), and the gossip port may have
# been opened by that script -- close it; removing a rule that was never
# added is harmless under the || true guards.
rm -f /etc/alertmanager/cluster.args
if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --remove-port=9094/tcp --remove-port=9094/udp || true
  firewall-cmd --reload || true
elif command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw delete allow 9094/tcp || true
  ufw delete allow 9094/udp || true
fi
