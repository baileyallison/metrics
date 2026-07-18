# shellcheck shell=bash disable=SC2034  # sourced by packaging/build.sh, which uses these vars
# Packaging manifest for metrics-stack-common, read by packaging/build.sh.
#
# Owns the shared 'metrics' Podman network Quadlet unit that Prometheus,
# Alertmanager, and Grafana all join. Its own package (rather than living in
# one of the component packages) so any component installs standalone
# without dragging in another component.
PKG_NAME="metrics-stack-common"
PKG_DESCRIPTION="Shared Podman network for the metrics-stack component packages (metrics-stack-prometheus/-alertmanager/-grafana)."
PKG_DEPENDS=(podman)

# containers/ is staged to /etc/containers/systemd/ (and marked config) by
# convention -- see packaging/build.sh. Nothing else ships.

PKG_POSTINSTALL="packaging/postinstall.sh"
PKG_PREREMOVE="packaging/preremove.sh"
PKG_POSTREMOVE="packaging/postremove.sh"
