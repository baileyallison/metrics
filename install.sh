#!/usr/bin/env bash
# Installs/updates the metrics-stack: Prometheus, Alertmanager, Grafana,
# node_exporter, plus provisioning and helper scripts. Works on Rocky Linux 9+
# (and other EL9+ distros) and Ubuntu 22.04+ (and other Debian-family distros
# with apt). Safe to re-run: existing local edits to deployed configs are
# left alone unless --force-config is passed.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORCE_CONFIG=0
MARKER="managed by metrics-stack"

for arg in "$@"; do
  case "$arg" in
    --force-config) FORCE_CONFIG=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: sudo ./install.sh [--force-config]

Installs Prometheus, Alertmanager, Grafana, and node_exporter via the
system package manager (dnf on EL, apt on Debian/Ubuntu), deploys default
configuration and helper scripts, validates configs, and starts services.

  --force-config   Overwrite locally-modified managed configs with the
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
    if [[ "${major:-0}" -lt 22 ]]; then
      echo "error: Ubuntu version $VERSION_ID detected; this stack targets 22.04+" >&2
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
# EL (Rocky/RHEL/Alma) install path
# ---------------------------------------------------------------------------
install_el() {
  log "configuring Grafana repo"
  cat > /etc/yum.repos.d/grafana.repo <<'EOF'
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

  log "configuring prometheus-rpm repo"
  rpm --import https://packagecloud.io/prometheus-rpm/release/gpgkey 2>/dev/null || true
  cat > /etc/yum.repos.d/prometheus.repo <<'EOF'
[prometheus]
name=prometheus
baseurl=https://packagecloud.io/prometheus-rpm/release/el/$releasever/$basearch
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packagecloud.io/prometheus-rpm/release/gpgkey
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

  log "installing packages (dnf)"
  dnf install -y prometheus2 alertmanager node_exporter grafana

  PROM_CONF_DIR=/etc/prometheus
  AM_CONF_DIR=/etc/alertmanager
  PROM_SVC=prometheus
  AM_SVC=alertmanager
  GRAFANA_SVC=grafana-server
}

# ---------------------------------------------------------------------------
# Ubuntu/Debian install path
# ---------------------------------------------------------------------------
install_ubuntu() {
  log "installing prerequisites"
  apt-get update -y
  apt-get install -y apt-transport-https software-properties-common wget gnupg curl

  log "configuring Grafana repo"
  mkdir -p /etc/apt/keyrings
  wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor -o /etc/apt/keyrings/grafana.gpg
  echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
    > /etc/apt/sources.list.d/grafana.list

  log "installing packages (apt)"
  apt-get update -y
  # prometheus, alertmanager, and prometheus-node-exporter ship in Ubuntu's
  # universe component; grafana comes from the repo configured above.
  apt-get install -y prometheus prometheus-alertmanager prometheus-node-exporter grafana

  PROM_CONF_DIR=/etc/prometheus
  AM_CONF_DIR=/etc/prometheus/alertmanager
  PROM_SVC=prometheus
  AM_SVC=prometheus-alertmanager
  GRAFANA_SVC=grafana-server
}

if [[ "$DISTRO_FAMILY" == "el" ]]; then
  install_el
else
  install_ubuntu
fi

# ---------------------------------------------------------------------------
# Deploy configuration
# ---------------------------------------------------------------------------
log "deploying configuration"

deploy_managed "$REPO_DIR/config/prometheus/prometheus.yml" "$PROM_CONF_DIR/prometheus.yml"
mkdir -p "$PROM_CONF_DIR/rules.d" "$PROM_CONF_DIR/targets.d"
for f in "$REPO_DIR"/config/prometheus/rules.d/*.yml; do
  deploy_managed "$f" "$PROM_CONF_DIR/rules.d/$(basename "$f")"
done
deploy_managed "$REPO_DIR/config/prometheus/targets.d/README.md" "$PROM_CONF_DIR/targets.d/README.md"

mkdir -p "$AM_CONF_DIR"
deploy_managed "$REPO_DIR/config/alertmanager/alertmanager.yml" "$AM_CONF_DIR/alertmanager.yml"

mkdir -p /etc/grafana/provisioning/datasources /etc/grafana/provisioning/dashboards /var/lib/grafana/dashboards
deploy_managed "$REPO_DIR/config/grafana/provisioning/datasources/prometheus.yml" \
  /etc/grafana/provisioning/datasources/prometheus.yml
deploy_managed "$REPO_DIR/config/grafana/provisioning/dashboards/local.yml" \
  /etc/grafana/provisioning/dashboards/local.yml
deploy_managed "$REPO_DIR/config/grafana/dashboards/node-overview.json" \
  /var/lib/grafana/dashboards/node-overview.json

log "installing helper scripts"
install -m 0755 "$REPO_DIR/scripts/add-exporter.sh" /usr/local/bin/monitoring-add-exporter
install -m 0755 "$REPO_DIR/scripts/configure-email.sh" /usr/local/bin/monitoring-configure-email
install -m 0755 "$REPO_DIR/scripts/add-dashboard.sh" /usr/local/bin/monitoring-add-dashboard

# ---------------------------------------------------------------------------
# Validate configuration
# ---------------------------------------------------------------------------
validate_config() {
  if command -v promtool >/dev/null 2>&1; then
    log "validating prometheus config"
    promtool check config "$PROM_CONF_DIR/prometheus.yml"
    for f in "$PROM_CONF_DIR"/rules.d/*.yml; do
      [[ -e "$f" ]] || continue
      promtool check rules "$f"
    done
  else
    log "warning: promtool not found, skipping prometheus config validation"
  fi

  if command -v amtool >/dev/null 2>&1; then
    log "validating alertmanager config"
    amtool check-config "$AM_CONF_DIR/alertmanager.yml"
  else
    log "warning: amtool not found, skipping alertmanager config validation"
  fi
}
validate_config

# ---------------------------------------------------------------------------
# Start/enable services
# ---------------------------------------------------------------------------
start_services() {
  local node_svc
  if systemctl cat node_exporter >/dev/null 2>&1; then
    node_svc="node_exporter"
  else
    node_svc="prometheus-node-exporter"
  fi

  for svc in "$PROM_SVC" "$AM_SVC" "$node_svc" "$GRAFANA_SVC"; do
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
