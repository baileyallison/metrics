# metrics

A metrics and monitoring stack for Rocky Linux 9+ and Ubuntu 22.04+: Prometheus,
Alertmanager (email alerts), Grafana, and node_exporter — installed entirely
through the system package manager (`dnf`/`apt`) so it upgrades the normal way.

## Quick start

```
git clone <this repo>
cd metrics
sudo ./install.sh
```

This detects your distro, configures the needed package repos, installs
Prometheus/Alertmanager/Grafana/node_exporter, deploys default configuration,
validates it, and starts all services.

- Grafana: `http://<host>:3000` (default login `admin`/`admin`, change on first login)
- Prometheus: `http://<host>:9090`
- Alertmanager: `http://<host>:9093`

Re-running `./install.sh` is safe — it's idempotent. Locally-edited managed
configs are left alone; pass `--force-config` to overwrite them with the
versions shipped in this repo (a timestamped backup is made first).

## Upgrading

Since everything installs via the package manager, upgrades are just:

```
sudo dnf upgrade            # Rocky/RHEL/Alma
sudo apt update && sudo apt upgrade   # Ubuntu/Debian
```

Re-run `sudo ./install.sh` afterward only if you want to pick up config
changes from a newer version of this repo.

## Adding email alerts

```
sudo monitoring-configure-email --smtp-host smtp.example.com:587 \
  --from alerts@example.com --to oncall@example.com \
  --user alerts@example.com
```

This writes `/etc/alertmanager/alertmanager.yml` (or
`/etc/prometheus/alertmanager/alertmanager.yml` on Ubuntu), validates it with
`amtool`, and restarts Alertmanager. Run `monitoring-configure-email --help`
for all options (`--no-tls`, password prompt, etc).

Alerting rules already shipped (see `config/prometheus/rules.d/`):

| Alert | Fires when |
|---|---|
| `InstanceDown` | A scrape target is unreachable for 5m |
| `HostHighCpuUsage` | CPU > 90% for 10m |
| `HostOutOfMemory` | Available memory < 10% for 5m |
| `HostOutOfDiskSpace` | Available disk < 10% on any filesystem for 5m |
| `HostDiskWillFillIn24Hours` | Disk trend predicts exhaustion within 24h |
| `PrometheusConfigReloadFailed` | Last Prometheus config reload failed |
| `AlertmanagerConfigReloadFailed` | Last Alertmanager config reload failed |
| `AlertmanagerNotificationsFailing` | Alertmanager notifications are erroring |

## Adding exporters

Prometheus watches `/etc/prometheus/targets.d/*.yml` (30s refresh, no
restart needed). Add a target group with:

```
sudo monitoring-add-exporter mysql db1.example.com:9104 db2.example.com:9104
```

Remove a job by deleting `/etc/prometheus/targets.d/<job>.yml`. See
`config/prometheus/targets.d/README.md` for the file format if you'd rather
write it by hand.

Common exporters and their package names:

| Exporter | Rocky/RHEL (dnf) | Ubuntu (apt) | Default port |
|---|---|---|---|
| node_exporter | `node_exporter` (installed by default) | `prometheus-node-exporter` (installed by default) | 9100 |
| MySQL | `mysqld_exporter` | `prometheus-mysqld-exporter` | 9104 |
| PostgreSQL | `postgres_exporter` (EPEL/community repo) | `prometheus-postgres-exporter` | 9187 |
| Apache | `apache_exporter` | `prometheus-apache-exporter` | 9117 |
| NGINX | `nginx-prometheus-exporter` | `prometheus-nginx-exporter` | 9113 |
| Blackbox (HTTP/TCP probes) | `blackbox_exporter` | `prometheus-blackbox-exporter` | 9115 |

After installing an exporter's own package/service, point Prometheus at it
with `monitoring-add-exporter <job> <host:port>`.

## Adding Grafana dashboards

```
sudo monitoring-add-dashboard 1860          # by grafana.com dashboard ID
sudo monitoring-add-dashboard 1860:31       # a specific revision
sudo monitoring-add-dashboard ./my-dashboard.json   # a local JSON file
```

Dashboards land in `/var/lib/grafana/dashboards` and appear in Grafana's
"Monitoring" folder within 30 seconds — no restart needed. `${DS_*}`
datasource placeholders in downloaded dashboards are rewritten automatically
to use this stack's Prometheus datasource.

A starter "Node Overview" dashboard (CPU, memory, disk, network, per-instance
via a template variable) is included and provisioned automatically.

## Repository layout

```
install.sh                                   # main installer
config/
  prometheus/
    prometheus.yml                           # main Prometheus config
    rules.d/                                 # alerting rules (host + stack health)
    targets.d/                               # drop-in exporter targets (file_sd)
  alertmanager/
    alertmanager.yml                         # email routing template
  grafana/
    provisioning/datasources/prometheus.yml  # auto-provisioned Prometheus datasource
    provisioning/dashboards/local.yml         # file-based dashboard provider
    dashboards/node-overview.json             # starter dashboard
scripts/
  add-exporter.sh       -> monitoring-add-exporter
  configure-email.sh    -> monitoring-configure-email
  add-dashboard.sh      -> monitoring-add-dashboard
```

## Per-distro service names

| Component | Rocky/RHEL | Ubuntu |
|---|---|---|
| Prometheus | `prometheus` | `prometheus` |
| Alertmanager | `alertmanager` | `prometheus-alertmanager` |
| node_exporter | `node_exporter` | `prometheus-node-exporter` |
| Grafana | `grafana-server` | `grafana-server` |

## Notes

- The `prometheus-rpm` community repo used on EL distros can lag upstream by
  a few days for major releases; check `https://packagecloud.io/prometheus-rpm/release`
  if you need a specific version sooner.
- Prometheus retains data for 15 days by default. Tune with
  `--storage.tsdb.retention.time` in the systemd unit's `ExecStart` if you
  need longer retention (edit via `systemctl edit <service>`, not by hand-patching
  the unit file, so package upgrades don't clobber it).
