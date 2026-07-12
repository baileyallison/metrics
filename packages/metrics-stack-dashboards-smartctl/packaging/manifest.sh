# Packaging manifest for metrics-stack-dashboards-smartctl, read by packaging/build.sh.
# Pure data -- no service, no postinstall/preremove needed: Grafana's file
# provisioning provider (shipped by the metrics-stack base package) already
# polls its dashboards directory every 30s.
#
# Deliberately no PKG_DEPENDS, same reasoning as metrics-stack-dashboards-node
# (the ceph-grafana-dashboards pattern): inert files, useful with a Grafana
# around but not requiring one to install.
PKG_NAME="metrics-stack-dashboards-smartctl"
PKG_DESCRIPTION="Starter Grafana dashboard for smartctl_exporter metrics (health, temperature, power-on time, SMART attributes, NVMe wear/errors). Drop-in file; pairs with metrics-stack + metrics-stack-exporter-smartctl but doesn't require them."
PKG_DEPENDS=()

PKG_FILES=(
  "0644:dashboards/smartctl-overview.json:/var/lib/grafana/dashboards/smartctl-overview.json"
)

PKG_CONFIG_FILES=(
  /var/lib/grafana/dashboards/smartctl-overview.json
)

PKG_DIRECTORIES=()

PKG_POSTINSTALL=""
PKG_PREREMOVE=""
