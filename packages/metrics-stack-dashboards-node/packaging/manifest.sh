# shellcheck shell=bash disable=SC2034  # sourced by packaging/build.sh, which uses these vars
# Packaging manifest for metrics-stack-dashboards-node, read by packaging/build.sh.
# Pure data -- dashboards/ is staged to /var/lib/grafana/dashboards/ (and
# marked config) by convention; no service, no scriptlets: Grafana's file
# provisioning provider (shipped by metrics-stack-grafana) already
# polls its dashboards directory every 30s.
#
# Deliberately no PKG_DEPENDS: this mirrors packages like ceph-grafana-
# dashboards, which ship dashboard JSON as inert files usable wherever a
# Grafana ends up looking for them, without hard-requiring a local Grafana
# install on the same host.
PKG_NAME="metrics-stack-dashboards-node"
PKG_DESCRIPTION="Starter Grafana dashboards for node_exporter metrics: an overview homepage plus CPU/memory/network/disk detail pages, cross-linked. Drop-in files; pairs with metrics-stack + metrics-stack-exporter-node but doesn't require them."
