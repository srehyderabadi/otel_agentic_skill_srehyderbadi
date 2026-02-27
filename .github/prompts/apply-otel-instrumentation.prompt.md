---
agent: agent
description: Apply OpenTelemetry auto-instrumentation to all Kubernetes app deployments (zero code changes, zero image rebuilds)
---

# Apply OTel Auto-Instrumentation

Installs the OpenTelemetry Operator and injects auto-instrumentation into application pods via a single Kubernetes annotation. **Zero application code changes. Zero Docker image rebuilds.**

## Quick Run (Recommended)

Run the end-to-end script directly in the terminal:

```bash
bash .agents/skills/apply-otel-instrumentation/scripts/add_otel_instrumentation.sh
```

The script is **idempotent** — it skips already-installed components.

---

## Step-by-Step (Manual / Copilot-guided)

### Step 1 — Set kubectl context

```bash
CLUSTER_NAME=$(grep 'CLUSTER_NAME=' observability/setup-cluster.sh | head -1 | cut -d'"' -f2)
kubectl config use-context "k3d-${CLUSTER_NAME}"
echo "✅ Context set: k3d-${CLUSTER_NAME}"
```

### Step 2 — Install cert-manager (idempotent)

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

### Step 3 — Install OpenTelemetry Operator (idempotent)

```bash
OTEL_OP_VERSION="v0.97.1"
if kubectl get deployment -n opentelemetry-operator-system opentelemetry-operator-controller-manager &>/dev/null; then
  echo "✅ OTel Operator already installed — skipping"
else
  kubectl apply -f "https://github.com/open-telemetry/opentelemetry-operator/releases/download/${OTEL_OP_VERSION}/opentelemetry-operator.yaml"
  kubectl rollout status deployment/opentelemetry-operator-controller-manager \
    -n opentelemetry-operator-system --timeout=120s
  echo "✅ OpenTelemetry Operator ready"
fi
```

### Step 4 — Apply Instrumentation CR

```bash
kubectl apply -f ".agents/skills/apply-otel-instrumentation/resources/hyderabadi-instrumentation.yaml"
echo "✅ Instrumentation CR applied"
```

### Step 5 — Annotate all deployments

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

### Step 6 — Wait for rollout and verify

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
echo "✅ OTel auto-instrumentation applied!"
```

---

## Configuration

| Parameter         | Default  | Notes                                         |
| ----------------- | -------- | --------------------------------------------- |
| `INJECT_LANGUAGE` | `python` | Change to `java`, `nodejs`, `dotnet`, or `go` |
| `APP_NAMESPACE`   | `apps`   | Namespace where app deployments live          |

## Adapting to Other Languages

- Change `INJECT_LANGUAGE` (e.g., `java`, `nodejs`, `dotnet`, `go`)
- Update `hyderabadi-instrumentation.yaml` for language-specific exporter settings
- The annotation key auto-adjusts: `instrumentation.opentelemetry.io/inject-<language>`
