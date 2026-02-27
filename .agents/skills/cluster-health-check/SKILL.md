---
name: cluster-health-check
description: Check cluster health — running services, pod status, OTel backends configured, and available UIs
---

# Cluster Health Check

Gives a full status report of the Kubernetes cluster: running services, pod health, which OTel backends are active, and which UIs are accessible.

## Scripts

| Script                          | Purpose                                                                                                                  |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `scripts/show_otel_backends.sh` | Show the active OTel Collector ConfigMap, all backend targets per signal (traces/metrics/logs), and collector pod health |

## Instructions

1. **To check active OTel backends only**, run the script directly:

   ```bash
   bash .agents/skills/cluster-health-check/scripts/show_otel_backends.sh
   ```

   This will print:
   - Active ConfigMap name and profile (`initial` / `demo`)
   - All exporters and their endpoint URLs
   - Pipeline routing (which signal goes to which backend)
   - OTel Collector pod status

2. **For a full cluster health check**, use the workflow: `/cluster-health-check`
   The workflow will:
   - List all application services and their pod status
   - List all observability components across namespaces
   - Check OTel Operator and Instrumentation CR status
   - Show currently configured OTel backends (by reading the active ConfigMap)
   - Show ingress endpoints for accessible UIs

## Configuration

| Parameter       | Default                                    | How to find                                        |
| --------------- | ------------------------------------------ | -------------------------------------------------- |
| `CLUSTER_NAME`  | Read from `observability/setup-cluster.sh` | `grep CLUSTER_NAME observability/setup-cluster.sh` |
| `APP_NAMESPACE` | `apps`                                     | Namespace where app deployments live               |

## Adapting to Other Tech Stacks

- Modify the `APP_NAMESPACE` and namespace list to match your cluster layout
- The OTel Collector backend detection works generically by reading the active ConfigMap
- Ingress endpoint discovery works with any Kubernetes ingress controller
