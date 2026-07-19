# shellcheck shell=bash disable=SC2034  # sourced by packaging/build.sh, which uses these vars
# Packaging manifest for metrics-stack-dashboards-zfs, read by packaging/build.sh.
# Pure data -- dashboards/ is staged to /var/lib/grafana/dashboards/ (and
# marked config) by convention; no service, no scriptlets: Grafana's file
# provisioning provider (shipped by metrics-stack-grafana) already
# polls its dashboards directory every 30s.
#
# Deliberately no PKG_DEPENDS, same reasoning as metrics-stack-dashboards-node
# (the ceph-grafana-dashboards pattern): inert files, useful with a Grafana
# around but not requiring one to install.
#
# Unlike the other dashboards-* packages there is no matching exporter
# package: every metric here comes from node_exporter's built-in zfs and
# filesystem collectors (metrics-stack-exporter-node), which read the
# OpenZFS kernel kstats via the host /proc mount.
PKG_NAME="metrics-stack-dashboards-zfs"
PKG_DESCRIPTION="Starter Grafana dashboard for ZFS metrics from node_exporter's zfs collector (pool state, ARC size/hit-ratio, dataset I/O, filesystem usage, ZIL, prefetch). Drop-in file; pairs with metrics-stack + metrics-stack-exporter-node but doesn't require them."
