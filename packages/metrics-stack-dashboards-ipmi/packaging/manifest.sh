# shellcheck shell=bash disable=SC2034  # sourced by packaging/build.sh, which uses these vars
# Packaging manifest for metrics-stack-dashboards-ipmi, read by packaging/build.sh.
# Pure data -- dashboards/ is staged to /var/lib/grafana/dashboards/ (and
# marked config) by convention; no service, no scriptlets: Grafana's file
# provisioning provider (shipped by metrics-stack-grafana) already
# polls its dashboards directory every 30s.
#
# Deliberately no PKG_DEPENDS, same reasoning as the other dashboards
# packages (the ceph-grafana-dashboards pattern): inert files, useful with a
# Grafana around but not requiring one to install.
PKG_NAME="metrics-stack-dashboards-ipmi"
PKG_DESCRIPTION="Starter Grafana dashboard for ipmi_exporter metrics (chassis power, live power draw, temperature/fan/voltage/current sensors, SEL entries, sensor state). Drop-in file; pairs with metrics-stack + metrics-stack-exporter-ipmi but doesn't require them."
