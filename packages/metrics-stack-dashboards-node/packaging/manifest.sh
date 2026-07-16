# shellcheck shell=bash disable=SC2034  # sourced by packaging/build.sh, which uses these vars
# Packaging manifest for metrics-stack-dashboards-node, read by packaging/build.sh.
# Pure data -- no service, no postinstall/preremove needed: Grafana's file
# provisioning provider (shipped by the metrics-stack base package) already
# polls its dashboards directory every 30s.
#
# Deliberately no PKG_DEPENDS: this mirrors packages like ceph-grafana-
# dashboards, which ship dashboard JSON as inert files usable wherever a
# Grafana ends up looking for them, without hard-requiring a local Grafana
# install on the same host.
PKG_NAME="metrics-stack-dashboards-node"
PKG_DESCRIPTION="Starter Grafana dashboard for node_exporter metrics (CPU/memory/disk/network). Drop-in file; pairs with metrics-stack + metrics-stack-exporter-node but doesn't require them."
PKG_DEPENDS=()

PKG_FILES=(
  "0644:dashboards/node-overview.json:/var/lib/grafana/dashboards/node-overview.json"
)

PKG_CONFIG_FILES=(
  /var/lib/grafana/dashboards/node-overview.json
)

PKG_DIRECTORIES=()

PKG_POSTINSTALL=""
PKG_PREREMOVE=""
PKG_POSTREMOVE=""
