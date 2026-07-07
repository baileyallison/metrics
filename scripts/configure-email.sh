#!/usr/bin/env bash
# managed by metrics-stack
# Installed as: monitoring-configure-email
#
# Writes /etc/alertmanager/alertmanager.yml with SMTP settings, validates
# with amtool, and restarts the Alertmanager service.
set -euo pipefail

CONFIG="/etc/alertmanager/alertmanager.yml"

usage() {
  cat <<'EOF'
Usage: monitoring-configure-email --smtp-host HOST:PORT --from ADDR --to ADDR
                                   [--user USER] [--password PASS] [--no-tls]

Configures Alertmanager to send email alerts.

  --smtp-host HOST:PORT   SMTP server, e.g. smtp.gmail.com:587
  --from ADDR             From address
  --to ADDR               To address (recipient of alerts)
  --user USER             SMTP auth username (optional)
  --password PASS         SMTP auth password (optional; prompted if --user
                           given without --password)
  --no-tls                Disable smtp_require_tls (default: enabled)

Example:
  monitoring-configure-email --smtp-host smtp.gmail.com:587 \
    --from alerts@example.com --to oncall@example.com \
    --user alerts@example.com
EOF
}

smtp_host=""
from=""
to=""
user=""
password=""
require_tls="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --smtp-host) smtp_host="$2"; shift 2 ;;
    --from) from="$2"; shift 2 ;;
    --to) to="$2"; shift 2 ;;
    --user) user="$2"; shift 2 ;;
    --password) password="$2"; shift 2 ;;
    --no-tls) require_tls="false"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument '$1'" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$smtp_host" || -z "$from" || -z "$to" ]]; then
  echo "error: --smtp-host, --from, and --to are required" >&2
  usage
  exit 1
fi

if [[ -n "$user" && -z "$password" ]]; then
  read -r -s -p "SMTP password for $user: " password
  echo
fi

if [[ $EUID -ne 0 ]]; then
  echo "error: must be run as root (writes to $CONFIG)" >&2
  exit 1
fi

if [[ -f "$CONFIG" ]]; then
  backup="$CONFIG.bak.$(date +%Y%m%d%H%M%S)"
  cp -p "$CONFIG" "$backup"
  echo "backed up existing config to $backup"
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

{
  echo "# managed by metrics-stack: monitoring-configure-email"
  echo "global:"
  echo "  smtp_smarthost: '$smtp_host'"
  echo "  smtp_from: '$from'"
  if [[ -n "$user" ]]; then
    echo "  smtp_auth_username: '$user'"
    echo "  smtp_auth_password: '$password'"
  fi
  echo "  smtp_require_tls: $require_tls"
  echo ""
  echo "route:"
  echo "  receiver: email"
  echo "  group_by: ['alertname', 'instance']"
  echo "  group_wait: 30s"
  echo "  group_interval: 5m"
  echo "  repeat_interval: 4h"
  echo ""
  echo "inhibit_rules:"
  echo "  - source_match:"
  echo "      alertname: InstanceDown"
  echo "    target_match_re:"
  echo "      severity: warning|critical"
  echo "    equal: ['instance']"
  echo ""
  echo "receivers:"
  echo "  - name: email"
  echo "    email_configs:"
  echo "      - to: '$to'"
  echo "        send_resolved: true"
} > "$tmp"

if command -v amtool >/dev/null 2>&1; then
  if ! amtool check-config "$tmp"; then
    echo "error: generated config failed amtool check-config, aborting" >&2
    exit 1
  fi
else
  echo "warning: amtool not found, skipping config validation" >&2
fi

install -o root -g prometheus -m 0640 "$tmp" "$CONFIG" 2>/dev/null || {
  # 'prometheus' group may not exist under all package layouts; fall back
  install -o root -g root -m 0640 "$tmp" "$CONFIG"
}

echo "wrote $CONFIG"

svc=""
for candidate in alertmanager prometheus-alertmanager; do
  if systemctl cat "$candidate" >/dev/null 2>&1; then
    svc="$candidate"
    break
  fi
done

if [[ -z "$svc" ]]; then
  echo "error: could not find alertmanager service (tried: alertmanager, prometheus-alertmanager)" >&2
  exit 1
fi

systemctl restart "$svc"
echo "restarted $svc"
