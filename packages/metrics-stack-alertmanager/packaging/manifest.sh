# shellcheck shell=bash disable=SC2034  # sourced by packaging/build.sh, which uses these vars
# Packaging manifest for metrics-stack-alertmanager, read by packaging/build.sh.
PKG_NAME="metrics-stack-alertmanager"
PKG_DESCRIPTION="Alertmanager for metrics-stack (Podman Quadlet container), with monitoring-configure-email for SMTP setup. Installs standalone; auto-registers as a Prometheus scrape target when metrics-stack-prometheus is on the same host."
PKG_DEPENDS=(podman metrics-stack-common)

# containers/ is staged to /etc/containers/systemd/ by convention (see
# packaging/build.sh) -- only files outside that convention are listed here.
# "mode:src(relative to this package dir):dest(absolute path on target)"
PKG_FILES=(
  "0640:alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml"
  "0755:scripts/configure-email.sh:/usr/bin/monitoring-configure-email"
)

# Convention-staged files (containers/) are marked config automatically.
PKG_CONFIG_FILES=(
  /etc/alertmanager/alertmanager.yml
)

PKG_DIRECTORIES=(
  /var/lib/alertmanager
)

PKG_POSTINSTALL="packaging/postinstall.sh"
PKG_PREREMOVE="packaging/preremove.sh"
PKG_POSTREMOVE="packaging/postremove.sh"
