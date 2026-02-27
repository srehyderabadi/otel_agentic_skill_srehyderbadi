---
name: apply-otel-instrumentation
description: Apply OpenTelemetry auto-instrumentation to Kubernetes application deployments using the OTel Operator (zero code changes, zero image rebuilds)
---

# Apply OTel Auto-Instrumentation

Installs the OpenTelemetry Operator and injects auto-instrumentation into application pods via a single Kubernetes annotation. **Zero application code changes. Zero Docker image rebuilds.**

## Scripts

| Script                                | Purpose                                                                                                |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `scripts/add_otel_instrumentation.sh` | Full end-to-end: installs cert-manager, OTel Operator, applies Instrumentation CR, patches deployments |

## Resources

| File                                        | Purpose                                                                                                           |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `resources/hyderabadi-instrumentation.yaml` | The `Instrumentation` custom resource manifest (defines exporter endpoint, propagators, sampler, Python env vars) |
| `resources/otel_changes_explained.md`       | Detailed walkthrough of every change the operator model makes and how it works                                    |

## Instructions

1. **Set kubectl context** to the target k3d cluster.
2. **Run the script**:
   ```bash
   bash .agents/skills/apply-otel-instrumentation/scripts/add_otel_instrumentation.sh
   ```
   The script is idempotent — it skips already-installed components.
3. **Alternatively**, follow the step-by-step workflow: use `/apply-otel-instrumentation`.

## Configuration

| Parameter         | Default                                    | How to find                                                          |
| ----------------- | ------------------------------------------ | -------------------------------------------------------------------- |
| `CLUSTER_NAME`    | Read from `observability/setup-cluster.sh` | `grep CLUSTER_NAME observability/setup-cluster.sh`                   |
| `APP_NAMESPACE`   | `apps`                                     | Namespace where app deployments live                                 |
| `INJECT_LANGUAGE` | `python`                                   | Language for annotation (`python`, `java`, `nodejs`, `dotnet`, `go`) |

## Adapting to Other Tech Stacks

- Change `INJECT_LANGUAGE` to `java`, `nodejs`, `dotnet`, or `go`
- Update the Instrumentation CR YAML to match language-specific exporter settings
- The annotation key automatically adjusts: `instrumentation.opentelemetry.io/inject-<language>`
