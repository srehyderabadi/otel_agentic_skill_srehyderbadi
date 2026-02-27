---
name: remove-otel-instrumentation
description: Remove OpenTelemetry auto-instrumentation from Kubernetes application deployments (zero code changes, zero image rebuilds)
---

# Remove OTel Auto-Instrumentation

Removes OTel injection from application pods by stripping annotations, deleting the Instrumentation CR, and rolling-restarting pods. **Zero application code changes. Zero Docker image rebuilds.**

## Scripts

| Script                                   | Purpose                                                                             |
| ---------------------------------------- | ----------------------------------------------------------------------------------- |
| `scripts/remove_otel_instrumentation.sh` | End-to-end removal: strips annotations, deletes CR, restarts pods, verifies cleanup |

## Instructions

1. **Set kubectl context** to the target k3d cluster.
2. **Run the script**:
   ```bash
   bash .agents/skills/remove-otel-instrumentation/scripts/remove_otel_instrumentation.sh
   ```
3. **Alternatively**, follow the step-by-step workflow: use `/remove-otel-instrumentation`.

> [!NOTE]
> The OTel Operator remains installed (runs silently). Run `/apply-otel-instrumentation` to re-enable at any time.

## Configuration

| Parameter         | Default                                    | How to find                                        |
| ----------------- | ------------------------------------------ | -------------------------------------------------- |
| `CLUSTER_NAME`    | Read from `observability/setup-cluster.sh` | `grep CLUSTER_NAME observability/setup-cluster.sh` |
| `APP_NAMESPACE`   | `apps`                                     | Namespace where app deployments live               |
| `INJECT_LANGUAGE` | `python`                                   | Must match what was used during apply              |

## Adapting to Other Tech Stacks

- Change `INJECT_LANGUAGE` to match what was used during apply (`java`, `nodejs`, `dotnet`, `go`)
- The annotation key automatically adjusts
