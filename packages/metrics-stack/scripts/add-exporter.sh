#!/usr/bin/env bash
# managed by metrics-stack
# Installed as: monitoring-add-exporter
#
# Adds a Prometheus scrape target via the file_sd drop-in directory. Picked
# up automatically within 30s -- no Prometheus restart required.
set -euo pipefail

TARGETS_DIR="/etc/prometheus/targets.d"

usage() {
  cat <<'EOF'
Usage: monitoring-add-exporter <job-name> <host:port> [host:port ...]

Adds (or replaces) a Prometheus scrape target group for <job-name>, writing
/etc/prometheus/targets.d/<job-name>.yml. Prometheus picks up the change
within 30 seconds; no restart needed.

Examples:
  monitoring-add-exporter mysql db1.example.com:9104
  monitoring-add-exporter mysql db1.example.com:9104 db2.example.com:9104
  monitoring-add-exporter node [2001:db8::1]:9100    # IPv6: bracket the address

To remove a job, delete /etc/prometheus/targets.d/<job-name>.yml.
EOF
}

if [[ $# -lt 2 ]] || [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit "$([[ $# -ge 2 ]] && echo 0 || echo 1)"
fi

job="$1"
shift

if [[ ! "$job" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "error: job name must match [a-zA-Z0-9_-]+" >&2
  exit 1
fi

# Hostname/IPv4 like db1.example.com:9104, or bracketed IPv6 like
# [2001:db8::1]:9104 (the bracket form is what Prometheus expects).
for hp in "$@"; do
  if [[ ! "$hp" =~ ^([a-zA-Z0-9.-]+|\[[0-9a-fA-F:]+\]):[0-9]+$ ]]; then
    echo "error: invalid host:port '$hp'" >&2
    exit 1
  fi
done

if [[ $EUID -ne 0 ]]; then
  echo "error: must be run as root (writes to $TARGETS_DIR)" >&2
  exit 1
fi

mkdir -p "$TARGETS_DIR"
out="$TARGETS_DIR/$job.yml"

{
  echo "# managed by metrics-stack: monitoring-add-exporter"
  echo "- targets:"
  for hp in "$@"; do
    echo "    - $hp"
  done
  echo "  labels:"
  echo "    job: $job"
} > "$out"

echo "wrote $out"
echo "job '$job' will appear in Prometheus targets within 30s"
