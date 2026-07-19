# shellcheck shell=bash disable=SC2034  # sourced by packaging/build.sh, which uses these vars
# Packaging manifest for metrics-stack-prometheus, read by packaging/build.sh.
PKG_NAME="metrics-stack-prometheus"
PKG_DESCRIPTION="Prometheus for metrics-stack (Podman Quadlet container): alerting rules, targets.d drop-in discovery, and monitoring-add-exporter. Installs standalone; add Alertmanager/Grafana via their own metrics-stack-* packages."
PKG_DEPENDS=(podman metrics-stack-common)

# containers/ is staged to /etc/containers/systemd/ by convention (see
# packaging/build.sh) -- only files outside that convention are listed here.
# "mode:src(relative to this package dir):dest(absolute path on target)"
PKG_FILES=(
  "0644:prometheus/prometheus.yml:/etc/prometheus/prometheus.yml"
  "0644:prometheus/rules.d/host-alerts.yml:/etc/prometheus/rules.d/host-alerts.yml"
  "0644:prometheus/rules.d/stack-alerts.yml:/etc/prometheus/rules.d/stack-alerts.yml"
  "0644:prometheus/rules.d/smart-alerts.yml:/etc/prometheus/rules.d/smart-alerts.yml"
  "0644:prometheus/rules.d/ipmi-alerts.yml:/etc/prometheus/rules.d/ipmi-alerts.yml"
  "0644:prometheus/rules.d/zfs-alerts.yml:/etc/prometheus/rules.d/zfs-alerts.yml"
  "0644:prometheus/targets.d/README.md:/etc/prometheus/targets.d/README.md"
  "0644:prometheus/alertmanagers.d/README.md:/etc/prometheus/alertmanagers.d/README.md"
  "0755:scripts/add-exporter.sh:/usr/bin/monitoring-add-exporter"
)

# Convention-staged files (containers/) are marked config automatically.
PKG_CONFIG_FILES=(
  /etc/prometheus/prometheus.yml
  /etc/prometheus/rules.d/host-alerts.yml
  /etc/prometheus/rules.d/stack-alerts.yml
  /etc/prometheus/rules.d/smart-alerts.yml
  /etc/prometheus/rules.d/ipmi-alerts.yml
  /etc/prometheus/rules.d/zfs-alerts.yml
)

PKG_DIRECTORIES=(
  /var/lib/prometheus
)

PKG_POSTINSTALL="packaging/postinstall.sh"
PKG_PREREMOVE="packaging/preremove.sh"
PKG_POSTREMOVE="packaging/postremove.sh"
