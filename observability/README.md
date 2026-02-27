# Observability Stack — Setup Guide

Kubernetes manifests for the observability stack running on `k3d`.

Demonstrates evolving from a basic metrics/tracing stack (**VictoriaMetrics + Jaeger**) to a full Grafana-native stack (**Prometheus + Tempo + Loki**), using the OTel Collector to route signals transparently — with **zero app code changes**.

---

## Cluster Setup

If you don't already have a `k3d` cluster running, create one with ingress port mapping:

```bash
./setup-cluster.sh
```

---

## Phase 1 — Initial Stack (VictoriaMetrics + Jaeger)

The OTel Collector routes **metrics → VictoriaMetrics** and **traces → Jaeger**. No logs collected.

```bash
kubectl apply -f namespaces.yaml
kubectl apply -f victoriametrics.yaml
kubectl apply -f jaeger.yaml
kubectl apply -f otel-collector.yaml
kubectl apply -f grafana.yaml
kubectl apply -f ingress.yaml
```

**Accessing UIs:**

| Service | URL                                                        |
| ------- | ---------------------------------------------------------- |
| Grafana | [http://localhost:80/grafana](http://localhost:80/grafana) |
| Jaeger  | [http://localhost:80/jaeger](http://localhost:80/jaeger)   |

> [!NOTE]
> The OTel Collector accepts OTLP traces/metrics on ports **4317** (gRPC) and **4318** (HTTP) via the internal cluster service `otel-collector.opentelemetry.svc.cluster.local`.

---

## Phase 2 — Demo Transition (Prometheus + Tempo + Loki)

Switch the OTel Collector to route to the full Grafana-native backend stack.

### Option A — Use the Agent Workflow (recommended)

```
/switch-otel-config demo
```

The `/switch-otel-config` workflow handles everything automatically (updates the ConfigMap reference, applies the manifest, and restarts the collector pod).

### Option B — Manual Steps

1. Deploy the new target backends:

   ```bash
   kubectl apply -f prometheus.yaml
   kubectl apply -f loki.yaml
   kubectl apply -f tempo.yaml
   ```

2. Edit `otel-collector.yaml` — find the `volumes` section and change the ConfigMap name:

   ```yaml
   volumes:
     - name: config-volume
       configMap:
         name: otel-collector-config-demo # ← was: otel-collector-config-initial
   ```

3. Apply the updated Collector deployment:

   ```bash
   kubectl apply -f otel-collector.yaml
   ```

4. Restart the Collector pods to pick up the new config:

   ```bash
   kubectl rollout restart deploy/otel-collector -n opentelemetry
   ```

---

## Backend Routing Summary

| Profile     | Metrics         | Traces | Logs | Activate via                  |
| ----------- | --------------- | ------ | ---- | ----------------------------- |
| **initial** | VictoriaMetrics | Jaeger | —    | Default after `kubectl apply` |
| **demo**    | Prometheus      | Tempo  | Loki | `/switch-otel-config demo`    |

> In Grafana, all datasources (VictoriaMetrics, Jaeger, Prometheus, Tempo, Loki) are **pre-configured** for you.

---

## Files

| File                   | Purpose                                                |
| ---------------------- | ------------------------------------------------------ |
| `setup-cluster.sh`     | Create the k3d cluster with ingress port 80            |
| `namespaces.yaml`      | Create `opentelemetry` and `observability` namespaces  |
| `otel-collector.yaml`  | OTel Collector deployment + ConfigMaps (both profiles) |
| `victoriametrics.yaml` | VictoriaMetrics deployment & service                   |
| `jaeger.yaml`          | Jaeger all-in-one deployment & service                 |
| `prometheus.yaml`      | Prometheus deployment & service                        |
| `tempo.yaml`           | Tempo deployment & service                             |
| `loki.yaml`            | Loki deployment & service                              |
| `grafana.yaml`         | Grafana deployment with pre-configured datasources     |
| `ingress.yaml`         | Traefik ingress rules for all UIs                      |
