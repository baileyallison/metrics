# metrics

A metrics and monitoring stack for Rocky Linux 9+ and Ubuntu 24.04+:
Prometheus, Alertmanager (email alerts), and Grafana as separate component
packages (with a `metrics-stack` metapackage that installs all three), plus
separate exporter and dashboard packages you add only where you need them.
Every component runs as a Podman container managed by a systemd
[Quadlet](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
unit.

## Packages

| Package | What it is | Depends on |
|---|---|---|
| `metrics-stack` | Metapackage: the full stack | the three component packages below |
| `metrics-stack-prometheus` | Prometheus + alerting rules + `monitoring-add-exporter` | Podman, `metrics-stack-common` |
| `metrics-stack-alertmanager` | Alertmanager + `monitoring-configure-email` + `monitoring-configure-cluster` (HA) | Podman, `metrics-stack-common` |
| `metrics-stack-grafana` | Grafana + provisioning + `monitoring-add-dashboard` | Podman, `metrics-stack-common` |
| `metrics-stack-common` | The shared `metrics` Podman network the components join | Podman |
| `metrics-stack-exporter-node` | node_exporter (host CPU/mem/disk/network) | Podman only — **no** stack packages |
| `metrics-stack-exporter-smartctl` | smartctl_exporter (disk S.M.A.R.T. health) | Podman only — **no** stack packages |
| `metrics-stack-exporter-ipmi` | ipmi_exporter (local host BMC: temp/power/fan/voltage) | Podman only — **no** stack packages |
| `metrics-stack-dashboards-node` | Starter node_exporter Grafana dashboards: overview + CPU/memory/network/disk detail | nothing (pure data) |
| `metrics-stack-dashboards-smartctl` | Starter "smartctl Overview" Grafana dashboard | nothing (pure data) |
| `metrics-stack-dashboards-ipmi` | Starter "IPMI Overview" Grafana dashboard | nothing (pure data) |

Each component package installs and runs standalone, so partial deployments
work: Prometheus without Grafana, an alerting-free stack, or Grafana on a
different host than Prometheus (edit the provisioned datasource — see
[Adding Grafana dashboards](#adding-grafana-dashboards)). Alertmanager
follows the same auto-registration pattern as the exporters: installed
alongside `metrics-stack-prometheus`, its postinstall registers itself as a
scrape target; removed, it deregisters.

Exporter packages are standalone by design: install `metrics-stack-exporter-node`
on any host you want metrics from — a database server, a NAS, a laptop — with
or without the stack itself present on that same host. If
`metrics-stack-prometheus` happens to be installed locally, the exporter's
postinstall auto-registers itself with Prometheus; otherwise it prints the
one-liner to run on your Prometheus server instead. Dashboard packages are
the same pattern used by things like `ceph-grafana-dashboards`: inert files
that are useful *with* a Grafana around, but don't require one to install.

**Upgrading from a pre-2.7 install:** the old monolithic `metrics-stack`
package was split in v2.7.0 with no in-place migration path. Uninstall the
old package first (`apt purge metrics-stack` / `dnf remove metrics-stack`),
then install the new packages — data under
`/var/lib/{prometheus,alertmanager,grafana}` is untouched by removal, so
history and dashboards survive the reinstall.

## Quick start

Every package is install-only-via-`.rpm`/`.deb` — no git-clone-and-run-a-script
path for any of them. Every tagged release is built and
smoke-tested end-to-end in CI (see [Releasing](#releasing)), producing
`.rpm`s and `.deb`s attached to the [GitHub Release](../../releases):

```
# on your monitoring server (Rocky/RHEL/Alma) -- one transaction, so the
# package manager can resolve the metapackage's dependencies from the
# local files:
sudo dnf install ./metrics-stack-<version>-1.noarch.rpm \
  ./metrics-stack-common-<version>-1.noarch.rpm \
  ./metrics-stack-prometheus-<version>-1.noarch.rpm \
  ./metrics-stack-alertmanager-<version>-1.noarch.rpm \
  ./metrics-stack-grafana-<version>-1.noarch.rpm

# on your monitoring server (Ubuntu/Debian)
sudo apt install ./metrics-stack_<version>-1_all.deb \
  ./metrics-stack-common_<version>-1_all.deb \
  ./metrics-stack-prometheus_<version>-1_all.deb \
  ./metrics-stack-alertmanager_<version>-1_all.deb \
  ./metrics-stack-grafana_<version>-1_all.deb

# or skip the metapackage and install only the components a host needs,
# e.g. Prometheus + Alertmanager with no Grafana:
sudo apt install ./metrics-stack-common_<version>-1_all.deb \
  ./metrics-stack-prometheus_<version>-1_all.deb \
  ./metrics-stack-alertmanager_<version>-1_all.deb

# on that same box, or any other host you want metrics from:
sudo apt install ./metrics-stack-exporter-node_<version>-1_all.deb
sudo apt install ./metrics-stack-exporter-smartctl_<version>-1_all.deb
sudo apt install ./metrics-stack-exporter-ipmi_<version>-1_all.deb

# on your monitoring server, once you have exporters registered:
sudo apt install ./metrics-stack-dashboards-node_<version>-1_all.deb
sudo apt install ./metrics-stack-dashboards-smartctl_<version>-1_all.deb
sudo apt install ./metrics-stack-dashboards-ipmi_<version>-1_all.deb
```

Podman is pulled in as a dependency automatically; each package's
post-install step deploys its Quadlet unit(s), validates config where
applicable, and starts everything. Real `%config(noreplace)`/conffile
handling means local edits survive upgrades, and `dnf remove`/`apt purge`
cleanly uninstalls — stopping the service, deregistering the exporter's
Prometheus target, closing the firewall port the install opened, and
reloading systemd so no stale Quadlet-generated unit lingers (your data
under `/var/lib/{prometheus,alertmanager,grafana}` isn't part of any
package manifest, so it survives removal either way). One Debian-specific
caveat: plain `apt remove` (without purge) keeps conffiles on disk per
standard dpkg semantics — and since the Quadlet `.container` unit *is* a
conffile, the service stays defined and would start again on reboot. Use
`apt purge` to remove a package's services for good.

To try out unreleased changes without waiting for a tagged release, build
packages locally instead — see [Releasing](#releasing).

Once the stack is installed:

- Grafana: `http://<host>:3000` (default login `admin`/`admin`, change on first login)
- Prometheus: `http://<host>:9090`
- Alertmanager: `http://<host>:9093`

Only Grafana's port (3000) is opened on the firewall by default (by
`metrics-stack-grafana`); each exporter package opens its own port (e.g.
9100 for node_exporter). Prometheus/Alertmanager stay off the firewall on
the assumption you'll browse them through Grafana or over SSH tunnel/VPN.

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
`alertmanager.service`, `grafana.service`, `node-exporter.service`, etc.) are
identical on both distros. The trade-off is that `dnf upgrade`/`apt upgrade`
now only patches Podman and the OS — bumping a component's version is a
one-line edit + a new package release instead (see
[Upgrading](#upgrading)), which is also exactly what "version control over
the container version" means in practice.

**Ubuntu 22.04 note:** its default Podman package (3.4.4) predates Quadlet,
which needs Podman 4.4+. Ubuntu 24.04's default `universe` Podman (4.9.3)
clears that bar, so this stack targets 24.04+ rather than 22.04+.

## Upgrading

**OS and Podman itself:**

```
sudo dnf upgrade                       # Rocky/RHEL/Alma
sudo apt update && sudo apt upgrade    # Ubuntu/Debian
```

**A component's version (Prometheus, Alertmanager, Grafana, node_exporter,
smartctl_exporter):** edit the `Image=` line in the relevant package's
`.container` file, e.g.:

```
# packages/metrics-stack-prometheus/containers/prometheus.container
Image=docker.io/prom/prometheus:v3.9.0   ->   Image=docker.io/prom/prometheus:v3.10.0
```

An `Image=` bump means cutting a new release (see [Releasing](#releasing))
and running `dnf upgrade metrics-stack-prometheus` / `apt upgrade
metrics-stack-prometheus` (or the relevant component/exporter package name)
once it's out.

Check each image's tag list before bumping:
[prom/prometheus](https://hub.docker.com/r/prom/prometheus/tags),
[prom/alertmanager](https://hub.docker.com/r/prom/alertmanager/tags),
[prom/node-exporter](https://hub.docker.com/r/prom/node-exporter/tags),
[grafana/grafana](https://hub.docker.com/r/grafana/grafana/tags),
[prometheuscommunity/smartctl-exporter](https://hub.docker.com/r/prometheuscommunity/smartctl-exporter/tags).

## Releasing

`.github/workflows/release.yml` runs on every push to `main` and every pull
request as well as on tags, so packaging breakage surfaces when it lands
rather than at the next release — only the final release-publishing job is
tag-gated. Pushing a `v*` tag (e.g. `v1.1.0`) runs the full pipeline:

1. **lint** — shellchecks every tracked shell script.
2. **build** — runs `packaging/build.sh <version>` (version taken from the
   tag; branch/PR runs use a throwaway `0.0.0.ci<run>` version) to produce
   a `.rpm` and `.deb` for every package under `packages/*/` via
   [fpm](https://github.com/jordansissel/fpm), sanity-checks each `.rpm`'s
   file list with `rpm -qlp`, and uploads them as a workflow artifact.
3. **smoke-test-ubuntu** and **smoke-test-rocky** run in parallel, each only
   depending on `build`:
   - **smoke-test-ubuntu** — on a live Ubuntu 24.04 GitHub-hosted runner (a
     real systemd VM, not a container, so `systemctl`/Podman/Quadlet/apt
     dependency resolution all behave as they would on a real box), installs
     the *actual built* `.deb`s (all eleven packages), confirms
     Prometheus/Alertmanager/Grafana/the exporters are healthy, confirms
     Alertmanager and node_exporter/smartctl_exporter/ipmi_exporter
     **auto-registered** themselves as Prometheus targets with no manual
     step, confirms alerting rules loaded and the starter dashboards were
     provisioned, reinstalls the stack components and an exporter to prove
     the upgrade path leaves services running and targets registered,
     purges an exporter and confirms its target file, firewall rule, and
     generated systemd unit were cleaned up, then removes Alertmanager and
     confirms Prometheus and Grafana keep running without it (the point of
     the package split).
   - **smoke-test-rocky** — installs the *actual built* `.rpm`s inside a
     plain `rockylinux:9` container. Deliberately narrower scope than the
     Ubuntu lane: a container has no systemd as PID 1, so the `%post`
     scriptlet's `systemctl` calls would just fail before testing anything
     (identically for a correct or broken package, so not a useful signal).
     Installs with `--setopt=tsflags=noscripts` instead, validating what a
     container *can* meaningfully check — real `dnf`/`Requires: podman`
     dependency resolution against EL9's AppStream repo, that all eleven
     packages install together without file conflicts, correct file
     placement/permissions, and that `%config(noreplace)` markers landed
     correctly. It does not cover service startup or SELinux labeling
     (Rocky enforces SELinux by default; Ubuntu doesn't) — that would need
     a real systemd environment (nested KVM or a self-hosted runner), a
     bigger step taken only if this lighter check turns up a reason to.
4. **release** — tag pushes only, and only if lint and both smoke-test jobs
   pass; attaches every built package to the GitHub Release for that tag.

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

Alerting rules already shipped (see
`packages/metrics-stack-prometheus/prometheus/rules.d/`):

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
| `DiskSmartHealthFailed` | A drive's SMART overall-health check reports FAILED |
| `DiskNvmeCriticalWarning` | NVMe critical-warning bits set (spare/temp/media/read-only) |
| `DiskNvmeSpareLow` | NVMe available spare below the drive's own threshold |
| `DiskNvmeWearHigh` | NVMe endurance used > 90% |
| `DiskMediaErrorsIncreasing` | New NVMe media errors in the last 6h |
| `DiskAtaSectorsIncreasing` | Reallocated/pending sectors growing on an ATA drive (6h) |
| `DiskScsiDefectsIncreasing` | SAS/SCSI grown defect list growing (6h) |
| `DiskUncorrectedErrorsIncreasing` | New uncorrected read/write errors (6h) |
| `DiskTemperatureHigh` | Drive above 60°C for 15m |
| `IpmiSensorCritical` | A BMC sensor (temp/fan/voltage/power) in critical state |
| `IpmiSensorWarning` | A BMC sensor in warning state for 15m |
| `IpmiCollectorDown` | ipmi_exporter can't read the BMC for 30m |

The disk and BMC rules ship with the base Prometheus package but reference
metrics from `metrics-stack-exporter-smartctl` / `metrics-stack-exporter-ipmi`
— with no such exporter registered there are no matching series, so they sit
inert until the moment those metrics appear. No per-exporter wiring needed.

## Clustering Alertmanager (HA)

Alertmanager instances gossip over **TCP+UDP 9094** to form an HA cluster:
notifications are deduplicated and silences replicate across members. Run
this on **each** cluster node, listing the *other* nodes as peers:

```
# on nodeA:
sudo monitoring-configure-cluster --advertise nodeA.example.com nodeB.example.com
# on nodeB:
sudo monitoring-configure-cluster --advertise nodeB.example.com nodeA.example.com
```

This writes the cluster flags to `/etc/alertmanager/cluster.args` (picked up
by the container's entrypoint wrapper — the packaged Quadlet unit itself is
never edited, so upgrades stay clean), opens 9094 tcp+udp on the firewall,
restarts Alertmanager, and prints the cluster status. `--advertise` defaults
to the host's first address; set it explicitly on multi-homed hosts.

For alerting to be truly HA, **every Prometheus must send alerts to every
cluster member** (the cluster deduplicates). Prometheus discovers its
Alertmanagers from drop-in files in `/etc/prometheus/alertmanagers.d/` — the
same pattern as `targets.d/`: the Alertmanager package registers the local
instance, `monitoring-configure-cluster` registers the peers, and remote
instances can be added by hand (see that directory's README.md).

To leave a cluster: `sudo monitoring-configure-cluster --disable` — removes
the flags and peer registration, closes 9094, and restarts standalone.

**Security note:** the gossip protocol is unauthenticated and unencrypted;
run it only over a trusted network or VPN/tunnel between nodes. (Upstream
supports mTLS for cluster traffic, but that's not wired up here.)

## Adding exporters

Prometheus watches `/etc/prometheus/targets.d/*.yml` (30s refresh, no
restart needed) via a bind mount into its container. Add a target group with:

```
sudo monitoring-add-exporter mysql db1.example.com:9104 db2.example.com:9104
```

Remove a job by deleting `/etc/prometheus/targets.d/<job>.yml`. See
`packages/metrics-stack-prometheus/prometheus/targets.d/README.md` for the
file format if you'd rather write it by hand.

**This stack's own exporters are separate packages too:**

- `metrics-stack-exporter-node` — node_exporter, `Network=host` (needs the
  real host's network/proc/sys view, not a container's).
- `metrics-stack-exporter-smartctl` — smartctl_exporter, `Network=host` +
  `--privileged` (smartctl needs raw SG_IO ioctl access to block devices).
- `metrics-stack-exporter-ipmi` — ipmi_exporter, `Network=host` +
  `--privileged` (needs `/dev/ipmi0` to read the local BMC). This is
  **local-host mode only**: it reports the sensors of the physical machine
  it's installed on via the plain `/metrics` endpoint. ipmi_exporter also
  supports a very different remote/fleet mode (one central exporter polling
  many remote BMC IPs via `/ipmi?target=...` with per-target credentials,
  the blackbox_exporter multi-target pattern) — that's out of scope here
  since it needs a materially different Prometheus scrape_config shape
  (`params:` + `relabel_configs`) than this stack's plain `targets.d`
  host:port model.

All three run with `Network=host` specifically so they install and work
standalone, without requiring the stack's shared `metrics` Podman network
(owned by `metrics-stack-common`). When installed on the same host as
`metrics-stack-prometheus`, their postinstall scripts auto-register with
Prometheus via `host.containers.internal:<port>` (how a bridge-networked
container reaches the host); installed on a different host, they print the
`monitoring-add-exporter` command to run on your Prometheus server instead.
(`metrics-stack-alertmanager` registers itself the same way — as
`alertmanager:9093` over the shared network rather than a host port.)

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

The provisioned datasource points at `http://prometheus:9090` over the
shared `metrics` network. Running Grafana on a different host than
Prometheus? Edit `/etc/grafana/provisioning/datasources/prometheus.yml`
(it's a conffile — local edits survive upgrades) to point at your
Prometheus server's address.

Three starter dashboards ship as their own packages rather than being
bundled into `metrics-stack-grafana` — see [Packages](#packages):

- `metrics-stack-dashboards-node` — five dashboards, all templated over
  `$instance` and cross-linked via the top nav bar so you can drill down
  from the summary into a specific resource and back:
  - "Node Overview" — homepage: uptime, CPU/memory/root-fs stat tiles, and
    one at-a-glance graph each for CPU, load, memory, filesystem, disk I/O,
    and network.
  - "Node CPU" — per-core usage, load average, context switches/interrupts,
    forks, running/blocked processes.
  - "Node Memory" — memory breakdown (total/available/free/cached/buffers),
    active/inactive, swap, page faults, slab/page tables, dirty/writeback.
  - "Node Network" — traffic and packet rate per device, receive/transmit
    errors and drops, active TCP connections, an interface info table.
  - "Node Disk" — filesystem and inode usage per mountpoint, disk I/O bytes
    and ops, utilization, read/write latency.
- `metrics-stack-dashboards-smartctl` — "smartctl Overview": overall SMART
  health, temperature, power-on time/cycles, a device info table, a
  templated view over any SMART attribute (`$attribute`, since attribute
  names vary by vendor/drive type), and NVMe-specific wear/error metrics
  (percentage used, available spare, media errors, critical warnings).
  Templated over `$instance` and `$device`.
- `metrics-stack-dashboards-ipmi` — "IPMI Overview": chassis power state,
  live power draw, a BMC info table, SEL entry count, a "sensors not
  nominal" count, temperature/fan/voltage/current sensors, a templated view
  over generic sensor types (`$sensor_type`), and collector health
  (`ipmi_up`). Templated over `$instance`.

## Architecture

```
node-exporter (host network, :9100) ───────────────┐
smartctl-exporter (host network, :9633) ───────────┤
ipmi-exporter (host network, :9290) ───────────────┤
other exporters (containers, native, remote) ──────┼──► Prometheus (:9090)
   registered via targets.d/*.yml                  │        │
                                                    │        ├──► Alertmanager (:9093) ──► email
                                                    │        │
                                                    │        └──◄ Grafana (:3000) queries for graphs
                                                    │
     'metrics' Podman network (from metrics-stack-common) joins Prometheus,
     Alertmanager, and Grafana by container name; exporter packages stay on
     the host network -- both so they see real host interfaces/proc/sys/
     devices, and so they install standalone without the stack packages.
```

## Repository layout

```
packages/
  metrics-stack/                             # metapackage: depends on the three components
    doc/README                               # -> /usr/share/doc/metrics-stack/README
    packaging/manifest.sh                    # read by packaging/build.sh

  metrics-stack-common/
    containers/metrics.network               # shared Podman network (Quadlet)
    packaging/
      manifest.sh
      postinstall.sh                         # %post / postinst
      preremove.sh                           # %preun / prerm (uninstall only, not upgrade)
      postremove.sh                          # %postun / postrm (daemon-reload)

  metrics-stack-prometheus/
    containers/prometheus.container          # Quadlet unit, pinned image tag
    prometheus/
      prometheus.yml                         # main Prometheus config
      rules.d/                               # alerting rules (host + stack health)
      targets.d/                             # drop-in exporter targets (file_sd)
      alertmanagers.d/                       # drop-in Alertmanager instances (file_sd)
    scripts/add-exporter.sh                  # -> monitoring-add-exporter
    packaging/                               # manifest + the same three scriptlets

  metrics-stack-alertmanager/
    containers/alertmanager.container        # Quadlet unit, pinned image tag
    alertmanager/
      alertmanager.yml                       # email routing template
      entrypoint.sh                          # appends cluster flags from cluster.args
    scripts/configure-email.sh               # -> monitoring-configure-email
    scripts/configure-cluster.sh             # -> monitoring-configure-cluster
    packaging/                               # manifest + the same three scriptlets

  metrics-stack-grafana/
    containers/grafana.container             # Quadlet unit, pinned image tag
    grafana/
      provisioning/datasources/prometheus.yml
      provisioning/dashboards/local.yml      # file-based dashboard provider
    scripts/add-dashboard.sh                 # -> monitoring-add-dashboard
    packaging/                               # manifest + the same three scriptlets

  metrics-stack-exporter-node/
    containers/node-exporter.container
    packaging/manifest.sh                    # sets PKG_EXPORTER_* -- see packaging/templates/

  metrics-stack-exporter-smartctl/
    containers/smartctl-exporter.container
    packaging/manifest.sh                    # sets PKG_EXPORTER_* -- see packaging/templates/

  metrics-stack-exporter-ipmi/
    containers/ipmi-exporter.container
    packaging/manifest.sh                    # sets PKG_EXPORTER_* -- see packaging/templates/

  metrics-stack-dashboards-node/
    dashboards/node-overview.json
    dashboards/node-cpu.json
    dashboards/node-memory.json
    dashboards/node-network.json
    dashboards/node-disk.json
    packaging/manifest.sh                    # no scriptlets needed

  metrics-stack-dashboards-smartctl/
    dashboards/smartctl-overview.json
    packaging/manifest.sh                    # no scriptlets needed

  metrics-stack-dashboards-ipmi/
    dashboards/ipmi-overview.json
    packaging/manifest.sh                    # no scriptlets needed

packaging/
  build.sh                                   # generic: builds every packages/*/ into .rpm+.deb
  templates/
    exporter-postinstall.sh                  # shared templates for all standalone exporter packages
    exporter-preremove.sh                    # (node/smartctl/ipmi differ only in 4 PKG_EXPORTER_* values)
    exporter-postremove.sh                   # daemon-reload after removal (no substitutions)

.github/workflows/
  release.yml                                # tag-triggered: build, smoke-test, release
```

## Host paths

| Path | Contents | Owned by |
|---|---|---|
| `/etc/containers/systemd/` | Quadlet unit files (`.network`, `.container`) | all packages |
| `/etc/prometheus/` | `prometheus.yml`, `rules.d/`, `targets.d/` (bind-mounted read-only) | `metrics-stack-prometheus` |
| `/etc/alertmanager/alertmanager.yml` | SMTP config, mode `0640` (bind-mounted read-only) | `metrics-stack-alertmanager` |
| `/etc/grafana/provisioning/` | datasource + dashboard-provider YAML (bind-mounted read-only) | `metrics-stack-grafana` |
| `/var/lib/prometheus/` | Prometheus TSDB data | `metrics-stack-prometheus` |
| `/var/lib/alertmanager/` | Alertmanager state | `metrics-stack-alertmanager` |
| `/var/lib/grafana/` | Grafana's sqlite db + `dashboards/` | `metrics-stack-grafana` (dir), dashboard packages (files) |

## Service names (same on both distros)

`metrics-network` (from `metrics-stack-common`); `prometheus` (from
`metrics-stack-prometheus`); `alertmanager` (from
`metrics-stack-alertmanager`); `grafana` (from `metrics-stack-grafana`);
`node-exporter` (from `metrics-stack-exporter-node`); `smartctl-exporter`
(from `metrics-stack-exporter-smartctl`); `ipmi-exporter`
(from `metrics-stack-exporter-ipmi`) — all generated by Quadlet from each
package's `.container`/`.network` files.

## Notes

- Alertmanager's cluster gossip port (9094 tcp+udp) is always *published* on
  the host (a Quadlet unit can't publish conditionally), but the firewall
  only opens it when `monitoring-configure-cluster` enables clustering — on
  non-clustered hosts with an active firewall it stays unreachable.
- Upgrading a host that had a locally-edited pre-2.8 `prometheus.yml`? Your
  edited file is kept (`noreplace`/conffile semantics), which still works —
  but it has the old static `alerting:` block, so Alertmanager clustering's
  fan-out needs you to merge in the `alertmanagers.d` file_sd change (see
  the shipped `.rpmnew` file, or this repo's
  `packages/metrics-stack-prometheus/prometheus/prometheus.yml`).
- Prometheus retains data for 15 days by default. Tune
  `--storage.tsdb.retention.time` in `prometheus.container`'s `Exec=` line
  if you need longer retention.
- The `:U` mount flag on Alertmanager's config volume chowns
  `/etc/alertmanager` to the container's internal UID on each start so the
  root-only `0640` `alertmanager.yml` stays readable to the Alertmanager
  process without being world-readable on the host.
- No image digests are pinned, only tags — if you need bit-for-bit
  reproducibility, pin `@sha256:...` digests instead of tags in the
  `Image=` lines.
- `smartctl-exporter` needs `--privileged` (via `PodmanArgs=`) and root
  inside the container to issue SG_IO ioctls against raw block devices —
  there's no meaningful rootless mode for it.
- `ipmi-exporter` likewise needs `--privileged` and root to read `/dev/ipmi0`.
  On hardware without a real BMC (VMs, most desktops/laptops), it still
  starts and serves `/metrics` — just with no sensor data.
