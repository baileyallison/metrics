# metrics

A metrics and monitoring stack for Rocky Linux 9+ and Ubuntu 24.04+: Prometheus,
Alertmanager (email alerts), Grafana, and node_exporter, each running as a
Podman container managed by a systemd [Quadlet](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
unit.

Only Podman itself comes from `dnf`/`apt`. Prometheus/Alertmanager/Grafana/
node_exporter versions are pinned by the `Image=` tag in each
`config/containers/*.container` file, tracked in this git repo — see
[Upgrading](#upgrading).

## Quick start

**Option A: install a release package (recommended).** Every tagged release
is built and smoke-tested in CI (see [Releasing](#releasing)), producing a
`.rpm` and a `.deb` attached to the [GitHub Release](../../releases):

```
# Rocky/RHEL/Alma
sudo dnf install ./metrics-stack-<version>-1.noarch.rpm

# Ubuntu/Debian
sudo apt install ./metrics-stack_<version>-1_all.deb
```

Podman is pulled in automatically as a dependency; the package's post-install
step deploys the Quadlet units, validates config, and starts everything —
same end state as Option B below, just via `dnf`/`apt` instead of a shell
script, with proper `%config(noreplace)`/conffile handling for local edits
and a clean `dnf remove`/`apt remove` for uninstall (your data under
`/var/lib/{prometheus,alertmanager,grafana}` isn't part of the package and
survives removal either way).

**Option B: install from source.**

```
git clone <this repo>
cd metrics
sudo ./install.sh
```

This detects your distro, installs Podman, deploys the Quadlet units and
default configuration, validates it, and starts everything. Useful for
trying out unreleased changes, or if you'd rather not fetch a prebuilt
package. Re-running `./install.sh` is safe — it's idempotent. Locally-edited
managed configs/units are left alone; pass `--force-config` to overwrite them
with the versions shipped in this repo (a timestamped backup is made first).

**Either way**, once installed:

- Grafana: `http://<host>:3000` (default login `admin`/`admin`, change on first login)
- Prometheus: `http://<host>:9090`
- Alertmanager: `http://<host>:9093`

Only port 3000 (Grafana) is opened on the firewall by default; Prometheus and
Alertmanager are reachable on the host but not punched through the firewall,
on the assumption you'll browse them through Grafana or over SSH tunnel/VPN.

## Why containers instead of native packages

The original version of this stack installed Prometheus/Grafana/Alertmanager
as native `dnf`/`apt` packages so the *whole* stack upgraded through one
command. That ran into two problems: Rocky and Ubuntu package these at
different paces (the `prometheus-rpm` EL repo lags upstream; Ubuntu's
`universe` versions can be a full release behind), and the two distros ship
them under different service/package names, which complicated the installer
and any script that needed to find "the" Alertmanager service.

Running each component as a Podman container pinned to an explicit image tag
fixes both: the version you get is exactly the version named in this repo
regardless of distro or how current its package repos are, and the
Quadlet-generated systemd unit names (`prometheus.service`,
`alertmanager.service`, `grafana.service`, `node-exporter.service`) are
identical on both distros. The trade-off is that `dnf upgrade`/`apt upgrade`
now only patches Podman and the OS — bumping Prometheus/Grafana/Alertmanager/
node_exporter versions is a one-line edit in this repo instead (see below),
which is also exactly what "version control over the container version"
means in practice.

**Ubuntu 22.04 note:** its default Podman package (3.4.4) predates Quadlet,
which needs Podman 4.4+. Ubuntu 24.04's default `universe` Podman (4.9.3)
clears that bar, so this stack now targets 24.04+ rather than 22.04+.

## Upgrading

**OS and Podman itself:**

```
sudo dnf upgrade                       # Rocky/RHEL/Alma
sudo apt update && sudo apt upgrade    # Ubuntu/Debian
```

**Prometheus, Alertmanager, Grafana, or node_exporter:** edit the `Image=`
line in the relevant `config/containers/*.container` file, e.g.:

```
# config/containers/prometheus.container
Image=docker.io/prom/prometheus:v3.9.0   ->   Image=docker.io/prom/prometheus:v3.10.0
```

then either re-run the installer or apply it directly:

```
sudo ./install.sh
# or, without re-running the whole installer:
sudo systemctl daemon-reload && sudo systemctl restart prometheus
```

Check each image's tag list before bumping:
[prom/prometheus](https://hub.docker.com/r/prom/prometheus/tags),
[prom/alertmanager](https://hub.docker.com/r/prom/alertmanager/tags),
[prom/node-exporter](https://hub.docker.com/r/prom/node-exporter/tags),
[grafana/grafana](https://hub.docker.com/r/grafana/grafana/tags).

If you installed via the `.rpm`/`.deb` package instead, an `Image=` bump
means cutting a new release (see below) and running `dnf upgrade
metrics-stack` / `apt upgrade metrics-stack` once it's out.

## Releasing

Pushing a `v*` tag (e.g. `v1.1.0`) triggers `.github/workflows/release.yml`:

1. **smoke-test** — runs `install.sh` on a live Ubuntu 24.04 GitHub-hosted
   runner (a real systemd VM, not a container, so `systemctl`/Podman/Quadlet
   all work as they would on a real box), then hits Prometheus, Alertmanager,
   Grafana, and node_exporter's health endpoints and confirms Prometheus
   sees all its targets up and all alerting rules loaded. The build is
   blocked if this fails.
2. **build** — runs `packaging/build.sh <version>` (version taken from the
   tag) to produce `metrics-stack-<version>-1.noarch.rpm` and
   `metrics-stack_<version>-1_all.deb` via [fpm](https://github.com/jordansissel/fpm),
   and attaches both to the GitHub Release for that tag.

To cut a release:

```
git tag v1.1.0
git push origin v1.1.0
```

To build packages locally instead (e.g. to test packaging changes before
tagging): `gem install --no-document fpm`, then `./packaging/build.sh 1.1.0-dev`.

## Adding email alerts

```
sudo monitoring-configure-email --smtp-host smtp.example.com:587 \
  --from alerts@example.com --to oncall@example.com \
  --user alerts@example.com
```

This writes `/etc/alertmanager/alertmanager.yml` (mode `0640`, root-only —
it holds your SMTP credentials), validates it by running `amtool` inside the
pinned Alertmanager image, and restarts the `alertmanager` service. Run
`monitoring-configure-email --help` for all options (`--no-tls`, password
prompt, etc).

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
restart needed) via a bind mount into its container — this didn't change
from the native-package version. Add a target group with:

```
sudo monitoring-add-exporter mysql db1.example.com:9104 db2.example.com:9104
```

Remove a job by deleting `/etc/prometheus/targets.d/<job>.yml`. See
`config/prometheus/targets.d/README.md` for the file format if you'd rather
write it by hand.

This stack's own node_exporter runs as a container with `Network=host` (it
needs the real host's network interfaces and `/proc`/`/sys`, not a
container's) — see `config/containers/node-exporter.container`. Prometheus
reaches it via `host.containers.internal:9100`, Podman's built-in DNS name
for "the host" as seen from a bridge-networked container.

For other exporters (MySQL, PostgreSQL, etc.), run them however you like —
their own container, a container elsewhere on the network, or a native
binary — and point Prometheus at them with
`monitoring-add-exporter <job> <host:port>`. A few official images:

| Exporter | Image | Default port |
|---|---|---|
| MySQL | `docker.io/prom/mysqld-exporter` | 9104 |
| PostgreSQL | `quay.io/prometheuscommunity/postgres-exporter` | 9187 |
| Apache | `docker.io/lusotycoon/apache-exporter` | 9117 |
| NGINX | `docker.io/nginx/nginx-prometheus-exporter` | 9113 |
| Blackbox (HTTP/TCP probes) | `docker.io/prom/blackbox-exporter` | 9115 |

## Adding Grafana dashboards

```
sudo monitoring-add-dashboard 1860          # by grafana.com dashboard ID
sudo monitoring-add-dashboard 1860:31       # a specific revision
sudo monitoring-add-dashboard ./my-dashboard.json   # a local JSON file
```

Dashboards land in `/var/lib/grafana/dashboards` (bind-mounted into the
Grafana container) and appear in Grafana's "Monitoring" folder within 30
seconds — no restart needed. `${DS_*}` datasource placeholders in downloaded
dashboards are rewritten automatically to use this stack's Prometheus
datasource.

A starter "Node Overview" dashboard (CPU, memory, disk, network, per-instance
via a template variable) is included and provisioned automatically.

## Architecture

```
node-exporter (host network, :9100) ───────────────┐
other exporters (containers, native, remote) ──────┼──► Prometheus (:9090)
   registered via targets.d/*.yml                  │        │
                                                    │        ├──► Alertmanager (:9093) ──► email
                                                    │        │
                                                    │        └──◄ Grafana (:3000) queries for graphs
                                                    │
     'metrics' Podman network joins Prometheus, Alertmanager, and Grafana
     by container name; node-exporter stays on the host network so it sees
     real host interfaces/proc/sys, reached via host.containers.internal.
```

## Repository layout

```
install.sh                                   # main installer
config/
  containers/
    metrics.network                          # shared Podman network (Quadlet)
    prometheus.container                     # Quadlet unit, pinned image tag
    alertmanager.container                   # Quadlet unit, pinned image tag
    grafana.container                        # Quadlet unit, pinned image tag
    node-exporter.container                  # Quadlet unit, pinned image tag, Network=host
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
packaging/
  build.sh                                   # stages files + runs fpm to produce .rpm/.deb
  scripts/
    postinstall.sh                           # %post / postinst: daemon-reload, validate, start, firewall
    preremove.sh                             # %preun / prerm: stop services
.github/workflows/
  release.yml                                # tag-triggered: smoke-test, then build + attach to GH Release
```

## Host paths

| Path | Contents |
|---|---|
| `/etc/containers/systemd/` | Quadlet unit files (`.network`, `.container`) |
| `/etc/prometheus/` | `prometheus.yml`, `rules.d/`, `targets.d/` (bind-mounted read-only) |
| `/etc/alertmanager/alertmanager.yml` | SMTP config, mode `0640` (bind-mounted read-only) |
| `/etc/grafana/provisioning/` | datasource + dashboard-provider YAML (bind-mounted read-only) |
| `/var/lib/prometheus/` | Prometheus TSDB data |
| `/var/lib/alertmanager/` | Alertmanager state |
| `/var/lib/grafana/` | Grafana's sqlite db + `dashboards/` |

## Service names (same on both distros)

`metrics-network`, `prometheus`, `alertmanager`, `node-exporter`, `grafana`
— all generated by Quadlet from the unit files in `config/containers/`.

## Notes

- Prometheus retains data for 15 days by default. Tune
  `--storage.tsdb.retention.time` in `config/containers/prometheus.container`'s
  `Exec=` line if you need longer retention.
- The `:U` mount flag on Alertmanager's config volume chowns
  `/etc/alertmanager` to the container's internal UID on each start so the
  root-only `0640` `alertmanager.yml` stays readable to the Alertmanager
  process without being world-readable on the host.
- No image digests are pinned, only tags — if you need bit-for-bit
  reproducibility, pin `@sha256:...` digests instead of tags in the
  `Image=` lines.
