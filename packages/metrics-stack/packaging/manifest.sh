# Packaging manifest for metrics-stack, read by packaging/build.sh.
PKG_NAME="metrics-stack"
PKG_DESCRIPTION="Prometheus/Alertmanager/Grafana monitoring stack base (Podman Quadlet containers). Add exporters via the separate metrics-stack-exporter-* packages."
PKG_DEPENDS=(podman)

# "mode:src(relative to this package dir):dest(absolute path on target)"
PKG_FILES=(
  "0644:containers/metrics.network:/etc/containers/systemd/metrics.network"
  "0644:containers/prometheus.container:/etc/containers/systemd/prometheus.container"
  "0644:containers/alertmanager.container:/etc/containers/systemd/alertmanager.container"
  "0644:containers/grafana.container:/etc/containers/systemd/grafana.container"
  "0644:prometheus/prometheus.yml:/etc/prometheus/prometheus.yml"
  "0644:prometheus/rules.d/host-alerts.yml:/etc/prometheus/rules.d/host-alerts.yml"
  "0644:prometheus/rules.d/stack-alerts.yml:/etc/prometheus/rules.d/stack-alerts.yml"
  "0644:prometheus/targets.d/README.md:/etc/prometheus/targets.d/README.md"
  "0640:alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml"
  "0644:grafana/provisioning/datasources/prometheus.yml:/etc/grafana/provisioning/datasources/prometheus.yml"
  "0644:grafana/provisioning/dashboards/local.yml:/etc/grafana/provisioning/dashboards/local.yml"
  "0755:scripts/add-exporter.sh:/usr/bin/monitoring-add-exporter"
  "0755:scripts/configure-email.sh:/usr/bin/monitoring-configure-email"
  "0755:scripts/add-dashboard.sh:/usr/bin/monitoring-add-dashboard"
)

PKG_CONFIG_FILES=(
  /etc/containers/systemd/metrics.network
  /etc/containers/systemd/prometheus.container
  /etc/containers/systemd/alertmanager.container
  /etc/containers/systemd/grafana.container
  /etc/prometheus/prometheus.yml
  /etc/prometheus/rules.d/host-alerts.yml
  /etc/prometheus/rules.d/stack-alerts.yml
  /etc/alertmanager/alertmanager.yml
  /etc/grafana/provisioning/datasources/prometheus.yml
  /etc/grafana/provisioning/dashboards/local.yml
)

PKG_DIRECTORIES=(
  /var/lib/prometheus
  /var/lib/alertmanager
  /var/lib/grafana/dashboards
)

PKG_POSTINSTALL="packaging/postinstall.sh"
PKG_PREREMOVE="packaging/preremove.sh"
