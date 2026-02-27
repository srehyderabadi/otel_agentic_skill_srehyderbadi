# 🍚 SRE Hyderabadi — Send & View Telemetry Guide

## Architecture

```
curl → localhost:80 (Traefik Ingress)
         → otel-collector:4318 (OTLP/HTTP)
              ├── Traces  → jaeger:4317  (OTLP gRPC)
              └── Metrics → victoriametrics:8428 (Prometheus Remote Write)
```

All observability UIs are exposed via Traefik ingress on **`localhost:80`** — no port-forward needed.

---

## Step 1 — Send Telemetry

```bash
bash validation_scripts/send_telemetry_demo.sh        # 3 rounds (default)
bash validation_scripts/send_telemetry_demo.sh 10     # richer data
```

Each round sends **2 spans** (HTTP + child `biryani.lookup`) and **3 metrics** (`http_requests_total`, `http_errors_total`, `http_server_duration_ms`). Every 3rd round simulates a **500 error** (pizza not on menu 🍕❌).

---

## Step 2 — Jaeger (Traces)

✅ **No port-forward needed** → Traefik ingress

**http://localhost:80/jaeger/**

1. **Service** dropdown → `sre-hyderabadi-order-service`
2. Click **Find Traces**
3. Red spans = `/order/pizza` errors, blue = successful biryani orders
4. Click any trace to see the 2-span waterfall

> [!TIP]
> Filter by tag `http.status_code=500` to isolate error traces

---

## Step 3 — VictoriaMetrics (Metrics)

✅ **No port-forward needed** → Traefik ingress (StripPrefix middleware active)

**http://localhost:80/victoriametrics/vmui**

| Query                                                         | What it shows       |
| ------------------------------------------------------------- | ------------------- |
| `http_requests_total`                                         | Raw request counter |
| `rate(http_requests_total[1m])`                               | Requests/second     |
| `http_errors_total`                                           | Total 500 errors    |
| `http_server_duration_ms_sum / http_server_duration_ms_count` | Avg latency         |

---

## Step 4 — Grafana (Dashboards)

✅ **No port-forward needed** → Traefik ingress

**http://localhost:80/grafana/** → login: `admin` / `admin`

### Add VictoriaMetrics datasource

1. **Connections → Data Sources → Add new → Prometheus**
2. URL: `http://victoriametrics.victoriametrics.svc.cluster.local:8428`
3. **Save & Test**

### Add Jaeger trace datasource (optional)

1. **Connections → Data Sources → Add new → Jaeger**
2. URL: `http://jaeger.jaeger.svc.cluster.local:16686`
3. **Save & Test** → enables trace/metric correlation

### Sample dashboard panels

| Panel        | Query                                                         |
| ------------ | ------------------------------------------------------------- |
| Request Rate | `rate(http_requests_total[1m])`                               |
| Error Rate   | `rate(http_errors_total[1m])`                                 |
| Avg Latency  | `http_server_duration_ms_sum / http_server_duration_ms_count` |

---

## Quick Reference

| UI                   | URL                                      | Auth        | Access     |
| -------------------- | ---------------------------------------- | ----------- | ---------- |
| Jaeger               | http://localhost:80/jaeger/              | none        | ✅ Ingress |
| VictoriaMetrics vmui | http://localhost:80/victoriametrics/vmui | none        | ✅ Ingress |
| Grafana              | http://localhost:80/grafana/             | admin/admin | ✅ Ingress |
