# shellcheck shell=bash disable=SC2034  # sourced by packaging/build.sh, which uses these vars
# Packaging manifest for metrics-stack-dashboards-logs, read by packaging/build.sh.
# Pure data -- dashboards/ is staged to /var/lib/grafana/dashboards/ (and
# marked config) by convention; no service, no scriptlets: Grafana's file
# provisioning provider (shipped by metrics-stack-grafana) already
# polls its dashboards directory every 30s.
#
# Deliberately no PKG_DEPENDS, same reasoning as metrics-stack-dashboards-node
# (the ceph-grafana-dashboards pattern): inert files, useful with a Grafana
# around but not requiring one to install. Panels query the 'loki'
# datasource provisioned by metrics-stack-loki's postinstall.
PKG_NAME="metrics-stack-dashboards-logs"
PKG_DESCRIPTION="Starter Grafana dashboard for logs shipped by metrics-stack-alloy into metrics-stack-loki (volume by unit/host/file, error volume, journal log browser). Drop-in file; pairs with metrics-stack-loki + metrics-stack-alloy but doesn't require them."
