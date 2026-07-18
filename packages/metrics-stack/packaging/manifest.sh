# shellcheck shell=bash disable=SC2034  # sourced by packaging/build.sh, which uses these vars
# Packaging manifest for metrics-stack, read by packaging/build.sh.
#
# Metapackage: ships no services of its own, just depends on the three
# component packages so "install metrics-stack" still means "install the
# whole monitoring stack". Install a component package directly instead if
# you want only part of the stack (e.g. Grafana on a separate host).
PKG_NAME="metrics-stack"
PKG_DESCRIPTION="Prometheus/Alertmanager/Grafana monitoring stack (metapackage). Pulls in metrics-stack-prometheus, metrics-stack-alertmanager, and metrics-stack-grafana; add exporters via the separate metrics-stack-exporter-* packages."
PKG_DEPENDS=(metrics-stack-prometheus metrics-stack-alertmanager metrics-stack-grafana)

# fpm needs at least one input path, so ship the doc README.
PKG_FILES=(
  "0644:doc/README:/usr/share/doc/metrics-stack/README"
)
