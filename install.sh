#!/usr/bin/env bash
# Installs/updates the metrics-stack: Prometheus, Alertmanager, Grafana, and
# node_exporter, each running as a Podman container managed by a systemd
# Quadlet unit. Works on Rocky Linux 9+ (and other EL9+ distros) and Ubuntu
# 24.04+ (and other Debian-family distros with apt) -- both ship a Podman
# new enough for Quadlet (4.4+) directly in their default repos.
#
# Only Podman itself comes from dnf/apt; Prometheus/Alertmanager/Grafana/
# node_exporter versions are controlled by the Image= tags in
# config/containers/*.container, which are tracked in this git repo. To
# upgrade one of them: bump its tag, commit, and re-run this script (or just
# `systemctl daemon-reload && systemctl restart <service>`).
#
# Safe to re-run: existing local edits to deployed configs/units are left
# alone unless --force-config is passed.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORCE_CONFIG=0
MARKER="managed by metrics-stack"

QUADLET_DIR=/etc/containers/systemd
PROM_CONF_DIR=/etc/prometheus
AM_CONF_DIR=/etc/alertmanager
GRAFANA_CONF_DIR=/etc/grafana

for arg in "$@"; do
  case "$arg" in
    --force-config) FORCE_CONFIG=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: sudo ./install.sh [--force-config]

Installs Podman via the system package manager (dnf on EL, apt on Ubuntu/
Debian), deploys Quadlet unit files and default configuration for
Prometheus, Alertmanager, Grafana, and node_exporter, validates the
configs, and starts the containers as systemd services.

  --force-config   Overwrite locally-modified managed configs/units with the
                    versions shipped in this repo (backups are still made).
EOF
      exit 0
      ;;
    *)
      echo "error: unknown argument '$arg'" >&2
      exit 1
      ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "error: this installer must be run as root (sudo)" >&2
  exit 1
fi

log() { echo "==> $*"; }

# ---------------------------------------------------------------------------
# Distro detection
# ---------------------------------------------------------------------------
if [[ ! -f /etc/os-release ]]; then
  echo "error: /etc/os-release not found, cannot detect distro" >&2
  exit 1
fi
# shellcheck disable=SC1091
source /etc/os-release

DISTRO_FAMILY=""
case "${ID:-}:${ID_LIKE:-}" in
  rocky:*|almalinux:*|centos:*|rhel:*|*:*rhel*|*:*fedora*)
    DISTRO_FAMILY="el"
    ;;
  ubuntu:*|debian:*|*:*debian*)
    DISTRO_FAMILY="debian"
    ;;
  *)
    if command -v dnf >/dev/null 2>&1; then
      DISTRO_FAMILY="el"
    elif command -v apt-get >/dev/null 2>&1; then
      DISTRO_FAMILY="debian"
    fi
    ;;
esac

if [[ "$DISTRO_FAMILY" == "el" ]]; then
  major="${VERSION_ID%%.*}"
  if [[ "${major:-0}" -lt 9 ]]; then
    echo "error: EL-family distro version $VERSION_ID detected; this stack targets version 9+" >&2
    exit 1
  fi
elif [[ "$DISTRO_FAMILY" == "debian" ]]; then
  if [[ "${ID:-}" == "ubuntu" ]]; then
    major="${VERSION_ID%%.*}"
    if [[ "${major:-0}" -lt 24 ]]; then
      echo "error: Ubuntu version $VERSION_ID detected; this stack targets 24.04+ (Ubuntu 22.04's Podman is too old for Quadlet, which needs 4.4+)" >&2
      exit 1
    fi
  fi
else
  echo "error: unsupported or undetected distro (ID=${ID:-unknown}, ID_LIKE=${ID_LIKE:-unknown})" >&2
  exit 1
fi

log "detected distro family: $DISTRO_FAMILY ($PRETTY_NAME)"

# ---------------------------------------------------------------------------
# Backup helper
# ---------------------------------------------------------------------------
backup() {
  local path="$1"
  if [[ -e "$path" ]]; then
    local bak
    bak="${path}.bak.$(date +%Y%m%d%H%M%S)"
    cp -a "$path" "$bak"
    log "backed up $path -> $bak"
  fi
}

# Deploys $src to $dest. If $dest already exists and carries the
# metrics-stack marker, it's considered "ours" and safe to overwrite
# (after a backup). If it exists without the marker, or was modified since
# deploy, it's treated as user-customized and left alone unless
# --force-config is set.
deploy_managed() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"

  if [[ -e "$dest" ]]; then
    local is_managed=0
    grep -qF "$MARKER" "$dest" 2>/dev/null && is_managed=1

    if [[ "$is_managed" -eq 1 ]]; then
      if cmp -s "$src" "$dest"; then
        return 0
      fi
      if [[ "$FORCE_CONFIG" -eq 0 ]]; then
        log "skipping $dest (locally modified managed file; use --force-config to overwrite)"
        return 0
      fi
      backup "$dest"
    elif [[ "$FORCE_CONFIG" -eq 1 ]]; then
      backup "$dest"
    else
      log "skipping $dest (exists, not managed by metrics-stack; remove it or use --force-config to overwrite)"
      return 0
    fi
  fi

  cp -a "$src" "$dest"
  log "deployed $dest"
}

# ---------------------------------------------------------------------------
# Install Podman
# ---------------------------------------------------------------------------
if [[ "$DISTRO_FAMILY" == "el" ]]; then
  log "installing podman (dnf)"
  dnf install -y podman
else
  log "installing podman (apt)"
  apt-get update -y
  apt-get install -y podman
fi

if ! podman --version | grep -qE 'podman version (4\.[4-9]|[5-9])' ; then
  log "warning: podman version looks older than 4.4 -- Quadlet may not work. Check 'podman --version'."
fi

# ---------------------------------------------------------------------------
# Deploy configuration + Quadlet units
# ---------------------------------------------------------------------------
log "deploying configuration"

deploy_managed "$REPO_DIR/config/prometheus/prometheus.yml" "$PROM_CONF_DIR/prometheus.yml"
mkdir -p "$PROM_CONF_DIR/rules.d" "$PROM_CONF_DIR/targets.d"
for f in "$REPO_DIR"/config/prometheus/rules.d/*.yml; do
  deploy_managed "$f" "$PROM_CONF_DIR/rules.d/$(basename "$f")"
done
deploy_managed "$REPO_DIR/config/prometheus/targets.d/README.md" "$PROM_CONF_DIR/targets.d/README.md"
mkdir -p /var/lib/prometheus

mkdir -p "$AM_CONF_DIR"
deploy_managed "$REPO_DIR/config/alertmanager/alertmanager.yml" "$AM_CONF_DIR/alertmanager.yml"
mkdir -p /var/lib/alertmanager

mkdir -p "$GRAFANA_CONF_DIR/provisioning/datasources" "$GRAFANA_CONF_DIR/provisioning/dashboards" /var/lib/grafana/dashboards
deploy_managed "$REPO_DIR/config/grafana/provisioning/datasources/prometheus.yml" \
  "$GRAFANA_CONF_DIR/provisioning/datasources/prometheus.yml"
deploy_managed "$REPO_DIR/config/grafana/provisioning/dashboards/local.yml" \
  "$GRAFANA_CONF_DIR/provisioning/dashboards/local.yml"
deploy_managed "$REPO_DIR/config/grafana/dashboards/node-overview.json" \
  /var/lib/grafana/dashboards/node-overview.json

log "deploying Quadlet units"
mkdir -p "$QUADLET_DIR"
for f in "$REPO_DIR"/config/containers/*; do
  deploy_managed "$f" "$QUADLET_DIR/$(basename "$f")"
done

log "installing helper scripts"
install -m 0755 "$REPO_DIR/scripts/add-exporter.sh" /usr/local/bin/monitoring-add-exporter
install -m 0755 "$REPO_DIR/scripts/configure-email.sh" /usr/local/bin/monitoring-configure-email
install -m 0755 "$REPO_DIR/scripts/add-dashboard.sh" /usr/local/bin/monitoring-add-dashboard

log "reloading systemd (runs the Quadlet generator)"
systemctl daemon-reload

# ---------------------------------------------------------------------------
# Validate configuration
# ---------------------------------------------------------------------------
image_from_unit() {
  grep '^Image=' "$QUADLET_DIR/$1" | head -1 | cut -d'=' -f2-
}

validate_config() {
  local prom_image am_image
  prom_image="$(image_from_unit prometheus.container)"
  am_image="$(image_from_unit alertmanager.container)"

  log "validating prometheus config (via $prom_image)"
  podman run --rm -v "$PROM_CONF_DIR:/etc/prometheus:ro,Z" --entrypoint promtool "$prom_image" \
    check config /etc/prometheus/prometheus.yml
  for f in "$PROM_CONF_DIR"/rules.d/*.yml; do
    [[ -e "$f" ]] || continue
    podman run --rm -v "$PROM_CONF_DIR:/etc/prometheus:ro,Z" --entrypoint promtool "$prom_image" \
      check rules "/etc/prometheus/rules.d/$(basename "$f")"
  done

  log "validating alertmanager config (via $am_image)"
  podman run --rm -v "$AM_CONF_DIR:/etc/alertmanager:ro,Z" --entrypoint amtool "$am_image" \
    check-config /etc/alertmanager/alertmanager.yml
}
validate_config

# ---------------------------------------------------------------------------
# Start/enable services
# ---------------------------------------------------------------------------
start_services() {
  for svc in metrics-network prometheus alertmanager node-exporter grafana; do
    log "enabling and starting $svc"
    systemctl enable --now "$svc"
  done
}
start_services

# ---------------------------------------------------------------------------
# Firewall
# ---------------------------------------------------------------------------
open_firewall() {
  if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
    log "opening Grafana port 3000/tcp via firewalld"
    firewall-cmd --permanent --add-port=3000/tcp
    firewall-cmd --reload
  elif command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    log "opening Grafana port 3000/tcp via ufw"
    ufw allow 3000/tcp
  else
    log "no active firewall manager detected, skipping firewall changes"
  fi
}
open_firewall

log "done. Grafana: http://<host>:3000 (default admin/admin, change on first login)"
log "Prometheus: http://<host>:9090   Alertmanager: http://<host>:9093"
log "Next steps: monitoring-configure-email --help, monitoring-add-exporter --help, monitoring-add-dashboard --help"
log "To bump a component's version: edit Image= in config/containers/<name>.container, commit, re-run this script."
