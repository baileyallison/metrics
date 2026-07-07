# targets.d — drop-in exporter targets

Prometheus watches this directory (`refresh_interval: 30s`, no restart needed)
for `file_sd_configs` target files. Add a new exporter by dropping a YAML or
JSON file here, either by hand or via:

```
monitoring-add-exporter <job-name> <host:port> [host:port ...]
```

Example — `monitoring-add-exporter mysql db1.example.com:9104 db2.example.com:9104`
writes `mysql.yml`:

```yaml
# managed by metrics-stack: monitoring-add-exporter
- targets:
    - db1.example.com:9104
    - db2.example.com:9104
  labels:
    job: mysql
```

Remove an exporter by deleting its file. Changes are picked up automatically
within 30 seconds — check `/api/v1/targets` on the Prometheus web UI to confirm.
