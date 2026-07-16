#!/usr/bin/env bash
# managed by metrics-stack
# Installed as: monitoring-add-dashboard
#
# Adds a Grafana dashboard to /var/lib/grafana/dashboards, either downloaded
# from grafana.com/dashboards or copied from a local JSON file. Grafana's
# file provisioning provider picks it up within 30s -- no restart needed.
set -euo pipefail

DASHBOARDS_DIR="/var/lib/grafana/dashboards"
DATASOURCE_UID="prometheus"

usage() {
  cat <<'EOF'
Usage: monitoring-add-dashboard <grafana.com-id>[:revision] | <path/to/dashboard.json>

Adds a dashboard to Grafana via the provisioning file directory.

Examples:
  monitoring-add-dashboard 1860              # Node Exporter Full, latest revision
  monitoring-add-dashboard 1860:31           # Node Exporter Full, revision 31
  monitoring-add-dashboard ./my-dashboard.json

Any ${DS_*} datasource template variables in the dashboard JSON are rewritten
to point at this stack's Prometheus datasource automatically.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "error: must be run as root (writes to $DASHBOARDS_DIR)" >&2
  exit 1
fi

mkdir -p "$DASHBOARDS_DIR"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

arg="$1"

if [[ "$arg" =~ ^[0-9]+(:[0-9]+)?$ ]]; then
  id="${arg%%:*}"
  if [[ "$arg" == *:* ]]; then
    rev="${arg#*:}"
  else
    rev="$(curl -fsSL "https://grafana.com/api/dashboards/$id" | python3 -c 'import json,sys; print(json.load(sys.stdin)["revision"])')"
  fi
  echo "downloading dashboard $id revision $rev from grafana.com..."
  curl -fsSL "https://grafana.com/api/dashboards/$id/revisions/$rev/download" -o "$tmp"
  title_hint="grafana-$id"
elif [[ -f "$arg" ]]; then
  cp "$arg" "$tmp"
  title_hint="$(basename "$arg" .json)"
else
  echo "error: '$arg' is neither a numeric grafana.com ID nor an existing file" >&2
  exit 1
fi

out_json="$(python3 - "$tmp" "$DATASOURCE_UID" <<'PYEOF'
import json
import re
import sys

path, ds_uid = sys.argv[1], sys.argv[2]

with open(path) as f:
    raw = f.read()

# Rewrite ${DS_*} template variable references to the fixed datasource uid.
raw = re.sub(r'\$\{DS_[A-Za-z0-9_]+\}', ds_uid, raw)

data = json.loads(raw)
data.pop("__inputs", None)
data.pop("__requires", None)
data["id"] = None

print(json.dumps(data, indent=2))
PYEOF
)"

title="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("title") or sys.argv[2])' "$out_json" "$title_hint")"
slug="$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')"
[[ -z "$slug" ]] && slug="$title_hint"

out_path="$DASHBOARDS_DIR/$slug.json"
echo "$out_json" > "$out_path"

echo "wrote $out_path"
echo "dashboard '$title' will appear in Grafana (folder: Monitoring) within 30s"
