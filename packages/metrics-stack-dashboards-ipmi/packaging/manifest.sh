# shellcheck shell=bash disable=SC2034  # sourced by packaging/build.sh, which uses these vars
# Packaging manifest for metrics-stack-dashboards-ipmi, read by packaging/build.sh.
# Pure data -- no service, no postinstall/preremove needed: Grafana's file
# provisioning provider (shipped by the metrics-stack base package) already
# polls its dashboards directory every 30s.
#
# Deliberately no PKG_DEPENDS, same reasoning as the other dashboards
# packages (the ceph-grafana-dashboards pattern): inert files, useful with a
# Grafana around but not requiring one to install.
PKG_NAME="metrics-stack-dashboards-ipmi"
PKG_DESCRIPTION="Starter Grafana dashboard for ipmi_exporter metrics (chassis power, live power draw, temperature/fan/voltage/current sensors, SEL entries, sensor state). Drop-in file; pairs with metrics-stack + metrics-stack-exporter-ipmi but doesn't require them."
PKG_DEPENDS=()

PKG_FILES=(
  "0644:dashboards/ipmi-overview.json:/var/lib/grafana/dashboards/ipmi-overview.json"
)

PKG_CONFIG_FILES=(
  /var/lib/grafana/dashboards/ipmi-overview.json
)

PKG_DIRECTORIES=()

PKG_POSTINSTALL=""
PKG_PREREMOVE=""
PKG_POSTREMOVE=""
