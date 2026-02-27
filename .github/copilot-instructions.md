# GitHub Copilot Workspace Instructions

This workspace demonstrates **OpenTelemetry auto-instrumentation** on a Kubernetes (k3d) cluster using the OTel Operator — zero application code changes, zero Docker image rebuilds.

## Project Layout

```
.agents/skills/          # Agentic skill definitions (Antigravity AI)
.agents/workflows/       # Step-by-step workflow files (Antigravity AI)
.github/prompts/         # VS Code Copilot Chat prompt files (this tool)
observability/           # Kubernetes manifests: cluster, OTel Collector, ingress
apps/                    # Sample Python microservices
```

## Key Configuration

| Variable        | Value / Where to find                              |
| --------------- | -------------------------------------------------- |
| `CLUSTER_NAME`  | `grep CLUSTER_NAME observability/setup-cluster.sh` |
| `APP_NAMESPACE` | `apps`                                             |
| `OTEL_YAML`     | `observability/otel-collector.yaml`                |

## Available Prompt Files (use `#` in Copilot Chat)

Use these in Copilot Chat by typing `#` and selecting the prompt file, or via **Chat → Attach Context → Prompt**:

| Prompt File                             | What it does                                                |
| --------------------------------------- | ----------------------------------------------------------- |
| `apply-otel-instrumentation.prompt.md`  | Install OTel Operator & annotate all deployments            |
| `remove-otel-instrumentation.prompt.md` | Strip annotations, delete Instrumentation CR, restart pods  |
| `cluster-health-check.prompt.md`        | Full cluster status: pods, backends, ingress, OTel CRs      |
| `switch-otel-config.prompt.md`          | Switch OTel Collector between `initial` and `demo` profiles |

## OTel Collector Profiles

| Profile   | Traces | Metrics         | Logs | Use Case           |
| --------- | ------ | --------------- | ---- | ------------------ |
| `initial` | Jaeger | VictoriaMetrics | —    | Default demo setup |
| `demo`    | Tempo  | Prometheus      | Loki | Full Grafana stack |

## General Rules for Copilot

- Always resolve `CLUSTER_NAME` from `observability/setup-cluster.sh` before running `kubectl` commands.
- Namespace for app workloads is `apps`. Observability components live in their own namespaces (`opentelemetry`, `grafana`, `jaeger`, etc.).
- All scripts are idempotent — safe to re-run.
- The OTel Operator namespace is `opentelemetry-operator-system`.
- Instrumentation CR is named `hyderabadi-instrumentation` in the `apps` namespace.
- When asked to apply/remove OTel instrumentation, prefer running the relevant script in `.agents/skills/` directly in the terminal.
