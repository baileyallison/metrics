#!/usr/bin/env bash
# managed by metrics-stack-alertmanager
# Installed as: monitoring-configure-cluster
#
# Enables (or disables) Alertmanager HA clustering: writes the cluster flags
# to /etc/alertmanager/cluster.args (read by /etc/alertmanager/entrypoint.sh
# inside the container), opens the gossip port on the firewall, registers the
# peers' HTTP endpoints for Prometheus notification fan-out, and restarts
# the alertmanager Quadlet service.
set -euo pipefail

ARGS_FILE="/etc/alertmanager/cluster.args"
PEERS_FILE="/etc/prometheus/alertmanagers.d/peers.yml"
GOSSIP_PORT=9094
HTTP_PORT=9093

usage() {
  cat <<'EOF'
Usage: monitoring-configure-cluster [--advertise HOST[:PORT]] PEER[:PORT] [PEER...]
       monitoring-configure-cluster --disable

Clusters this host's Alertmanager with the given peers. Gossip runs over
TCP+UDP 9094 (opened on the firewall by this script); run the same command
on every cluster node, each listing the other nodes as peers.

  PEER[:PORT]             A peer's gossip endpoint; bare hostnames get :9094.
  --advertise HOST[:PORT] Address this node tells peers to reach it at.
                          Defaults to this host's first address (hostname -I);
                          set explicitly on multi-homed hosts.
  --disable               Leave the cluster: remove the cluster flags and
                          peer registration, close the gossip port, restart.

If metrics-stack-prometheus is installed on this host, the peers' HTTP
endpoints (PEER:9093) are also registered in /etc/prometheus/alertmanagers.d/
so the local Prometheus sends alerts to every cluster member.

Example (on node A, clustering with nodes B and C):
  monitoring-configure-cluster --advertise nodeA.example.com \
    nodeB.example.com nodeC.example.com
EOF
}

advertise=""
disable="false"
peers=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --advertise) advertise="$2"; shift 2 ;;
    --disable) disable="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "error: unknown argument '$1'" >&2; usage; exit 1 ;;
    *) peers+=("$1"); shift ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "error: must be run as root (writes to $ARGS_FILE)" >&2
  exit 1
fi

# Firewall helpers for the gossip port; same firewalld/ufw split as the
# package postinstall scripts. Gossip needs both TCP and UDP.
open_gossip_port() {
  if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
    echo "opening gossip port $GOSSIP_PORT (tcp+udp) via firewalld"
    firewall-cmd --permanent --add-port="$GOSSIP_PORT/tcp" --add-port="$GOSSIP_PORT/udp"
    firewall-cmd --reload
  elif command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    echo "opening gossip port $GOSSIP_PORT (tcp+udp) via ufw"
    ufw allow "$GOSSIP_PORT/tcp"
    ufw allow "$GOSSIP_PORT/udp"
  fi
}

close_gossip_port() {
  if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --remove-port="$GOSSIP_PORT/tcp" --remove-port="$GOSSIP_PORT/udp" || true
    firewall-cmd --reload || true
  elif command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    ufw delete allow "$GOSSIP_PORT/tcp" || true
    ufw delete allow "$GOSSIP_PORT/udp" || true
  fi
}

if [[ "$disable" == "true" ]]; then
  if [[ ${#peers[@]} -gt 0 || -n "$advertise" ]]; then
    echo "error: --disable takes no other arguments" >&2
    exit 1
  fi
  rm -f "$ARGS_FILE" "$PEERS_FILE"
  close_gossip_port
  systemctl restart alertmanager
  echo "clustering disabled; alertmanager restarted standalone"
  exit 0
fi

if [[ ${#peers[@]} -lt 1 ]]; then
  echo "error: at least one peer is required (or --disable)" >&2
  usage >&2
  exit 1
fi

# Hostname/IPv4 like nodeB.example.com:9094, or bracketed IPv6 like
# [2001:db8::1]:9094 -- same shapes monitoring-add-exporter accepts.
hostport_re='^([a-zA-Z0-9.-]+|\[[0-9a-fA-F:]+\]):[0-9]+$'

# Bare hosts get the default gossip port appended.
with_default_port() {
  if [[ "$1" =~ :[0-9]+$ && ! "$1" =~ ^\[[0-9a-fA-F:]+\]$ ]]; then
    echo "$1"
  else
    echo "$1:$GOSSIP_PORT"
  fi
}

normalized=()
for p in "${peers[@]}"; do
  p="$(with_default_port "$p")"
  if [[ ! "$p" =~ $hostport_re ]]; then
    echo "error: invalid peer '$p' (expected HOST[:PORT])" >&2
    exit 1
  fi
  normalized+=("$p")
done

if [[ -z "$advertise" ]]; then
  advertise="$(hostname -I 2>/dev/null | awk '{print $1}')"
  if [[ -z "$advertise" ]]; then
    echo "error: could not auto-detect this host's address; pass --advertise" >&2
    exit 1
  fi
  echo "auto-detected advertise address: $advertise (override with --advertise)"
fi
advertise="$(with_default_port "$advertise")"
if [[ ! "$advertise" =~ $hostport_re ]]; then
  echo "error: invalid --advertise '$advertise' (expected HOST[:PORT])" >&2
  exit 1
fi

# One line of flags, word-split by /etc/alertmanager/entrypoint.sh.
{
  printf -- '--cluster.advertise-address=%s' "$advertise"
  for p in "${normalized[@]}"; do
    printf -- ' --cluster.peer=%s' "$p"
  done
  printf '\n'
} > "$ARGS_FILE"
chmod 0644 "$ARGS_FILE"
echo "wrote $ARGS_FILE"

# Register the peers' HTTP endpoints so the local Prometheus (if any) sends
# alerts to every cluster member; the cluster deduplicates via gossip. The
# HTTP port is assumed to be the stack default 9093 on each peer host.
if command -v monitoring-add-exporter >/dev/null 2>&1; then
  mkdir -p "$(dirname "$PEERS_FILE")"
  {
    echo "# managed by metrics-stack-alertmanager: monitoring-configure-cluster"
    echo "- targets:"
    for p in "${normalized[@]}"; do
      host="${p%:*}"
      echo "    - $host:$HTTP_PORT"
    done
  } > "$PEERS_FILE"
  echo "wrote $PEERS_FILE (Prometheus alert fan-out to all cluster members)"
else
  echo "metrics-stack-prometheus not found on this host."
  echo "On each Prometheus server, make sure every cluster member is listed in"
  echo "/etc/prometheus/alertmanagers.d/ (see its README.md) so alerts fan out."
fi

open_gossip_port

systemctl restart alertmanager
echo "restarted alertmanager"

# Show the cluster status once the API is back up. Peers appear here as they
# connect; a freshly-configured remote peer may take a few seconds (or show
# only this node until the peer is configured too).
for _ in $(seq 1 10); do
  if status="$(curl -fsS --max-time 5 "http://localhost:$HTTP_PORT/api/v2/status" 2>/dev/null)"; then
    echo "$status" | python3 -c '
import json, sys
cluster = json.load(sys.stdin)["cluster"]
print("cluster status: " + cluster["status"])
for peer in cluster.get("peers") or []:
    print("  peer: " + peer["name"] + " " + peer["address"])
' 2>/dev/null || echo "$status"
    exit 0
  fi
  sleep 2
done
echo "warning: alertmanager API did not answer on :$HTTP_PORT yet; check 'systemctl status alertmanager'" >&2
exit 1
