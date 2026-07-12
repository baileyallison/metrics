#!/usr/bin/env bash
# Builds metrics-stack.rpm and metrics-stack.deb from this repo's contents
# using fpm. Requires: fpm (gem install fpm), plus rpm-build tools if
# building the .rpm on a non-EL host, and dpkg-deb (present on any Debian-
# family system) for the .deb.
#
# Usage: packaging/build.sh <version>   (e.g. 1.0.0 -- no leading 'v')
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:?Usage: packaging/build.sh <version> (e.g. 1.0.0, no leading v)}"
ITERATION=1
OUT_DIR="$REPO_DIR/dist"

if ! command -v fpm >/dev/null 2>&1; then
  echo "error: fpm not found. Install with: gem install --no-document fpm" >&2
  exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$OUT_DIR"

# -----------------------------------------------------------------------
# Stage the target filesystem tree with correct permissions. fpm preserves
# whatever mode the source file has, so we set it here rather than relying
# on git's checked-out permissions.
# -----------------------------------------------------------------------
install -D -m 0644 "$REPO_DIR/config/containers/metrics.network" \
  "$STAGE/etc/containers/systemd/metrics.network"
install -D -m 0644 "$REPO_DIR/config/containers/prometheus.container" \
  "$STAGE/etc/containers/systemd/prometheus.container"
install -D -m 0644 "$REPO_DIR/config/containers/alertmanager.container" \
  "$STAGE/etc/containers/systemd/alertmanager.container"
install -D -m 0644 "$REPO_DIR/config/containers/grafana.container" \
  "$STAGE/etc/containers/systemd/grafana.container"
install -D -m 0644 "$REPO_DIR/config/containers/node-exporter.container" \
  "$STAGE/etc/containers/systemd/node-exporter.container"

install -D -m 0644 "$REPO_DIR/config/prometheus/prometheus.yml" \
  "$STAGE/etc/prometheus/prometheus.yml"
install -D -m 0644 "$REPO_DIR/config/prometheus/rules.d/host-alerts.yml" \
  "$STAGE/etc/prometheus/rules.d/host-alerts.yml"
install -D -m 0644 "$REPO_DIR/config/prometheus/rules.d/stack-alerts.yml" \
  "$STAGE/etc/prometheus/rules.d/stack-alerts.yml"
install -D -m 0644 "$REPO_DIR/config/prometheus/targets.d/README.md" \
  "$STAGE/etc/prometheus/targets.d/README.md"

# Holds SMTP credentials once monitoring-configure-email runs -- root-only.
install -D -m 0640 "$REPO_DIR/config/alertmanager/alertmanager.yml" \
  "$STAGE/etc/alertmanager/alertmanager.yml"

install -D -m 0644 "$REPO_DIR/config/grafana/provisioning/datasources/prometheus.yml" \
  "$STAGE/etc/grafana/provisioning/datasources/prometheus.yml"
install -D -m 0644 "$REPO_DIR/config/grafana/provisioning/dashboards/local.yml" \
  "$STAGE/etc/grafana/provisioning/dashboards/local.yml"
install -D -m 0644 "$REPO_DIR/config/grafana/dashboards/node-overview.json" \
  "$STAGE/var/lib/grafana/dashboards/node-overview.json"

# Package-managed convention: /usr/bin, not /usr/local/bin (reserved for
# admin-installed, unmanaged software).
install -D -m 0755 "$REPO_DIR/scripts/add-exporter.sh" "$STAGE/usr/bin/monitoring-add-exporter"
install -D -m 0755 "$REPO_DIR/scripts/configure-email.sh" "$STAGE/usr/bin/monitoring-configure-email"
install -D -m 0755 "$REPO_DIR/scripts/add-dashboard.sh" "$STAGE/usr/bin/monitoring-add-dashboard"

mkdir -p "$STAGE/var/lib/prometheus" "$STAGE/var/lib/alertmanager"

COMMON_ARGS=(
  -s dir
  -n metrics-stack
  -v "$VERSION"
  --iteration "$ITERATION"
  --license GPL-3.0
  --url "https://github.com/baileyallison/metrics"
  --description "Prometheus/Alertmanager/Grafana monitoring stack (Podman Quadlet containers)"
  --after-install "$REPO_DIR/packaging/scripts/postinstall.sh"
  --before-remove "$REPO_DIR/packaging/scripts/preremove.sh"
  --depends podman
  --config-files /etc/containers/systemd/metrics.network
  --config-files /etc/containers/systemd/prometheus.container
  --config-files /etc/containers/systemd/alertmanager.container
  --config-files /etc/containers/systemd/grafana.container
  --config-files /etc/containers/systemd/node-exporter.container
  --config-files /etc/prometheus/prometheus.yml
  --config-files /etc/prometheus/rules.d/host-alerts.yml
  --config-files /etc/prometheus/rules.d/stack-alerts.yml
  --config-files /etc/alertmanager/alertmanager.yml
  --config-files /etc/grafana/provisioning/datasources/prometheus.yml
  --config-files /etc/grafana/provisioning/dashboards/local.yml
  --config-files /var/lib/grafana/dashboards/node-overview.json
  --directories /var/lib/prometheus
  --directories /var/lib/alertmanager
  --chdir "$STAGE"
)

echo "==> building rpm"
fpm "${COMMON_ARGS[@]}" -t rpm -a noarch \
  -p "$OUT_DIR/metrics-stack-${VERSION}-${ITERATION}.noarch.rpm" \
  etc usr var

echo "==> building deb"
fpm "${COMMON_ARGS[@]}" -t deb -a all \
  -p "$OUT_DIR/metrics-stack_${VERSION}-${ITERATION}_all.deb" \
  etc usr var

echo "==> built:"
ls -la "$OUT_DIR"
