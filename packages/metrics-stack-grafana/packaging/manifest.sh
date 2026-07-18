# shellcheck shell=bash disable=SC2034  # sourced by packaging/build.sh, which uses these vars
# Packaging manifest for metrics-stack-grafana, read by packaging/build.sh.
PKG_NAME="metrics-stack-grafana"
PKG_DESCRIPTION="Grafana for metrics-stack (Podman Quadlet container): pre-provisioned Prometheus datasource, file-based dashboard provider, and monitoring-add-dashboard. Installs standalone; edit the datasource conffile if Prometheus runs on a different host."
PKG_DEPENDS=(podman metrics-stack-common)

# containers/ is staged to /etc/containers/systemd/ by convention (see
# packaging/build.sh) -- only files outside that convention are listed here.
# "mode:src(relative to this package dir):dest(absolute path on target)"
PKG_FILES=(
  "0644:grafana/provisioning/datasources/prometheus.yml:/etc/grafana/provisioning/datasources/prometheus.yml"
  "0644:grafana/provisioning/dashboards/local.yml:/etc/grafana/provisioning/dashboards/local.yml"
  "0755:scripts/add-dashboard.sh:/usr/bin/monitoring-add-dashboard"
)

# Convention-staged files (containers/) are marked config automatically.
PKG_CONFIG_FILES=(
  /etc/grafana/provisioning/datasources/prometheus.yml
  /etc/grafana/provisioning/dashboards/local.yml
)

PKG_DIRECTORIES=(
  /var/lib/grafana/dashboards
)

PKG_POSTINSTALL="packaging/postinstall.sh"
PKG_PREREMOVE="packaging/preremove.sh"
PKG_POSTREMOVE="packaging/postremove.sh"
