# alertmanagers.d — drop-in Alertmanager instances

Prometheus watches this directory (`refresh_interval: 30s`, no restart
needed) for `file_sd_configs` files naming the Alertmanager instances to
send alerts to — the same drop-in pattern as `targets.d/`, but for the
`alerting:` section instead of scraping.

Normally nothing here is written by hand:

- `local.yml` — added by the `metrics-stack-alertmanager` package when it's
  installed on this host (target `alertmanager:9093`, resolved over the
  shared `metrics` Podman network); removed when that package is.
- `peers.yml` — added by `monitoring-configure-cluster` when Alertmanager
  HA clustering is enabled, so alerts fan out to every cluster member
  (the cluster deduplicates via gossip); removed by
  `monitoring-configure-cluster --disable`.

To point this Prometheus at a remote Alertmanager by hand, drop in a file:

```yaml
# my-remote-alertmanager.yml
- targets:
    - alerts.example.com:9093
```

Remove an instance by deleting its file. Changes are picked up within 30
seconds — check `/api/v1/alertmanagers` on the Prometheus web UI to confirm.
