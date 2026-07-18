#!/bin/sh
# managed by metrics-stack-alertmanager -- container entrypoint for the
# alertmanager Quadlet unit (see PodmanArgs= in alertmanager.container).
# Ships as a plain package file, not a conffile: local edits are overwritten
# on upgrade.
#
# Runs Alertmanager with the packaged flags ("$@", from the unit's Exec=
# line) plus any cluster flags from /etc/alertmanager/cluster.args, written
# by monitoring-configure-cluster. This indirection exists because the
# .container file is a conffile that must stay unedited for clean package
# upgrades, and Quadlet drop-ins need Podman >= 5.0 (Ubuntu 24.04 ships
# 4.9). No cluster.args file means no extra flags -- not clustered.
set -e
# shellcheck disable=SC2046  # word-splitting cluster.args into flags is the point
exec /bin/alertmanager "$@" $(cat /etc/alertmanager/cluster.args 2>/dev/null || true)
