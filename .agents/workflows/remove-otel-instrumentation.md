---
description: Remove OpenTelemetry auto-instrumentation from Kubernetes application deployments (zero code changes, zero image rebuilds)
---

# Remove OTel Auto-Instrumentation

This skill removes OTel injection from application pods by removing annotations and deleting the Instrumentation CR. **Zero application code changes. Zero Docker image rebuilds.**

## Configuration

| Parameter                 | Default                                    | How to find                                        |
| ------------------------- | ------------------------------------------ | -------------------------------------------------- |
| `CLUSTER_NAME`            | Read from `observability/setup-cluster.sh` | `grep CLUSTER_NAME observability/setup-cluster.sh` |
| `APP_NAMESPACE`           | `apps`                                     | Namespace where app deployments live               |
| `INJECT_LANGUAGE`         | `python`                                   | Must match what was used during apply              |
| `INSTRUMENTATION_CR_NAME` | `hyderabadi-instrumentation`               | `kubectl get instrumentation -n apps`              |

## Steps

### 1. Set kubectl context

// turbo

```bash
CLUSTER_NAME=$(grep 'CLUSTER_NAME=' observability/setup-cluster.sh | head -1 | cut -d'"' -f2)
kubectl config use-context "k3d-${CLUSTER_NAME}"
```

### 2. Remove inject annotation from all deployments

```bash
APP_NAMESPACE="apps"
INJECT_LANGUAGE="python"
ANNOTATION_KEY="instrumentation.opentelemetry.io/inject-${INJECT_LANGUAGE}"

for DEPLOY in $(kubectl get deployments -n ${APP_NAMESPACE} -o jsonpath='{.items[*].metadata.name}'); do
  echo "🗑️  Removing annotation from ${DEPLOY}..."
  kubectl annotate deployment "${DEPLOY}" -n ${APP_NAMESPACE} \
    ${ANNOTATION_KEY}- \
    --overwrite 2>/dev/null || true
  echo "✅ ${DEPLOY} annotation removed"
done
```

### 3. Delete the Instrumentation CR

```bash
APP_NAMESPACE="apps"
INSTRUMENTATION_CR_NAME=$(kubectl get instrumentation -n ${APP_NAMESPACE} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "${INSTRUMENTATION_CR_NAME}" ]; then
  kubectl delete instrumentation "${INSTRUMENTATION_CR_NAME}" -n ${APP_NAMESPACE} --ignore-not-found
  echo "✅ Instrumentation CR '${INSTRUMENTATION_CR_NAME}' deleted"
else
  echo "ℹ️  No Instrumentation CR found — nothing to delete"
fi
```

### 4. Rolling restart and verify

```bash
APP_NAMESPACE="apps"
DEPLOYS=$(kubectl get deployments -n ${APP_NAMESPACE} -o jsonpath='{.items[*].metadata.name}')
kubectl rollout restart deployment ${DEPLOYS} -n ${APP_NAMESPACE}

for DEPLOY in ${DEPLOYS}; do
  kubectl rollout status deployment/${DEPLOY} -n ${APP_NAMESPACE} --timeout=90s
done

echo ""
echo "🔍 Verifying init containers are removed..."
for DEPLOY in ${DEPLOYS}; do
  POD=$(kubectl get pod -n ${APP_NAMESPACE} -l app="${DEPLOY}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$POD" ]; then
    INIT=$(kubectl get pod "$POD" -n ${APP_NAMESPACE} -o jsonpath='{.spec.initContainers[*].name}' 2>/dev/null)
    if [ -z "$INIT" ]; then
      echo "  ✅ ${DEPLOY} → pod ${POD} has NO init containers (OTel removed)"
    else
      echo "  ⚠️  ${DEPLOY} → pod ${POD} still has init containers: ${INIT}"
    fi
  fi
done

echo ""
if ! kubectl get instrumentation -n ${APP_NAMESPACE} &>/dev/null; then
  echo "✅ Instrumentation CR successfully deleted"
else
  echo "⚠️  Instrumentation CR still exists"
fi
echo "✅ OTel auto-instrumentation removal complete!"
```

> [!NOTE]
> The OTel Operator remains installed (runs silently). Run the `apply-otel-instrumentation` workflow to re-enable at any time.

## Adapting to other tech stacks

- Change `INJECT_LANGUAGE` to match what was used during apply (`java`, `nodejs`, `dotnet`, `go`)
- The annotation key automatically adjusts
