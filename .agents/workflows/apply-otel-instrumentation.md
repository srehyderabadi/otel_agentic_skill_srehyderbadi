---
description: Apply OpenTelemetry auto-instrumentation to Kubernetes application deployments using the OTel Operator (zero code changes)
---

# Apply OTel Auto-Instrumentation

This skill installs the OpenTelemetry Operator and injects auto-instrumentation into application pods via a single Kubernetes annotation. **Zero application code changes. Zero Docker image rebuilds.**

## Configuration

Before running, identify these values from the workspace:

| Parameter              | Default                                                                               | How to find                                                              |
| ---------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `CLUSTER_NAME`         | Read from `observability/setup-cluster.sh`                                            | `grep CLUSTER_NAME observability/setup-cluster.sh`                       |
| `APP_NAMESPACE`        | `apps`                                                                                | Namespace where app deployments live                                     |
| `SERVICES`             | Auto-discover                                                                         | `kubectl get deployments -n <APP_NAMESPACE> -o name`                     |
| `INSTRUMENTATION_YAML` | `.agents/skills/apply-otel-instrumentation/resources/hyderabadi-instrumentation.yaml` | The Instrumentation CR manifest                                          |
| `INJECT_LANGUAGE`      | `python`                                                                              | Language for the annotation (`python`, `java`, `nodejs`, `dotnet`, `go`) |

## Steps

### 1. Set kubectl context

// turbo

```bash
CLUSTER_NAME=$(grep 'CLUSTER_NAME=' observability/setup-cluster.sh | head -1 | cut -d'"' -f2)
kubectl config use-context "k3d-${CLUSTER_NAME}"
```

### 2. Install cert-manager (idempotent)

```bash
if kubectl get namespace cert-manager &>/dev/null && \
   kubectl get deployment -n cert-manager cert-manager &>/dev/null; then
  echo "✅ cert-manager already installed — skipping"
else
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml
  echo "⏳ Waiting for cert-manager webhooks..."
  kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s
  sleep 10
  echo "✅ cert-manager ready"
fi
```

### 3. Install OpenTelemetry Operator (idempotent)

```bash
OTEL_OP_VERSION="v0.97.1"
if kubectl get deployment -n opentelemetry-operator-system opentelemetry-operator-controller-manager &>/dev/null; then
  echo "✅ OTEL Operator already installed — skipping"
else
  kubectl apply -f "https://github.com/open-telemetry/opentelemetry-operator/releases/download/${OTEL_OP_VERSION}/opentelemetry-operator.yaml"
  echo "⏳ Waiting for OTEL Operator..."
  kubectl rollout status deployment/opentelemetry-operator-controller-manager \
    -n opentelemetry-operator-system --timeout=120s
  echo "✅ OpenTelemetry Operator ready"
fi
```

### 4. Apply the Instrumentation CR

```bash
kubectl apply -f ".agents/skills/apply-otel-instrumentation/resources/hyderabadi-instrumentation.yaml"
echo "✅ Instrumentation CR applied"
```

### 5. Patch deployments with inject annotation

Auto-discover all deployments in the app namespace and annotate them:

```bash
APP_NAMESPACE="apps"
INJECT_LANGUAGE="python"
ANNOTATION_KEY="instrumentation.opentelemetry.io/inject-${INJECT_LANGUAGE}"

for DEPLOY in $(kubectl get deployments -n ${APP_NAMESPACE} -o jsonpath='{.items[*].metadata.name}'); do
  echo "🏷️  Annotating ${DEPLOY}..."
  kubectl patch deployment "${DEPLOY}" -n ${APP_NAMESPACE} --type=merge -p "{
    \"spec\": {
      \"template\": {
        \"metadata\": {
          \"annotations\": {
            \"${ANNOTATION_KEY}\": \"true\"
          }
        }
      }
    }
  }"
  echo "✅ ${DEPLOY} annotated"
done
```

### 6. Wait for rollout and verify

```bash
APP_NAMESPACE="apps"
for DEPLOY in $(kubectl get deployments -n ${APP_NAMESPACE} -o jsonpath='{.items[*].metadata.name}'); do
  kubectl rollout status deployment/${DEPLOY} -n ${APP_NAMESPACE} --timeout=120s
done

echo ""
echo "🔍 Verifying init container injection..."
for DEPLOY in $(kubectl get deployments -n ${APP_NAMESPACE} -o jsonpath='{.items[*].metadata.name}'); do
  POD=$(kubectl get pod -n ${APP_NAMESPACE} -l app="${DEPLOY}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$POD" ]; then
    INIT=$(kubectl get pod "$POD" -n ${APP_NAMESPACE} -o jsonpath='{.spec.initContainers[*].name}' 2>/dev/null)
    echo "  ${DEPLOY} → pod: ${POD} | init containers: ${INIT:-none}"
  fi
done
echo "✅ OTel auto-instrumentation applied successfully!"
```

## Adapting to other tech stacks

- Change `INJECT_LANGUAGE` to `java`, `nodejs`, `dotnet`, or `go`
- Update the `Instrumentation` CR YAML to match the language-specific exporter settings
- The annotation key automatically adjusts: `instrumentation.opentelemetry.io/inject-<language>`
