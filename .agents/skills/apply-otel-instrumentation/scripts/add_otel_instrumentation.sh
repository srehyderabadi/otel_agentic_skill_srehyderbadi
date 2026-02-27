#!/bin/bash
# =============================================================================
# 🔭 ADD OTEL — OPERATOR / AUTO-INJECTION MODEL
# =============================================================================
# Zero code changes. Zero Docker image rebuilds.
# The OTEL Operator injects the SDK as an init container via a single
# annotation on each Deployment's pod template.
#
# What this script does:
#   1. Install cert-manager  (required by the OTEL Operator)
#   2. Install OpenTelemetry Operator  (watches for Instrumentation CRs)
#   3. Apply the Instrumentation CR   (tells the operator HOW to inject Python)
#   4. Patch each Deployment with the inject annotation
#   5. Wait for rollout — done!
#
# No application code changed. No requirements.txt changed.
# No Docker image rebuilt. Just K8s resources + one annotation.
# =============================================================================

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
K3D_CLUSTER="cncf-hyd"
kubectl config use-context "k3d-${K3D_CLUSTER}"

# Internal endpoint for OTEL Collector
OTEL_COLLECTOR_ENDPOINT="http://otel-collector.opentelemetry.svc.cluster.local:4318"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🔭 OTEL OPERATOR — Auto-Inject Python Instrumentation       ║"
echo "║  Zero code changes. Zero image rebuilds. Pure K8s magic!     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# STEP 1: Install cert-manager (prerequisite for OTEL Operator)
# ──────────────────────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 STEP 1/5 — Installing cert-manager"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    (cert-manager manages the TLS webhook certs for the operator)"

if kubectl get namespace cert-manager &>/dev/null && \
   kubectl get deployment -n cert-manager cert-manager &>/dev/null; then
  echo "✅ cert-manager already installed — skipping"
else
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml
  echo "⏳ Waiting for cert-manager webhooks to be ready..."
  kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s
  # Give the webhook a few extra seconds to register
  sleep 10
  echo "✅ cert-manager ready"
fi

# ──────────────────────────────────────────────────────────────────────────────
# STEP 2: Install OpenTelemetry Operator
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎛️  STEP 2/5 — Installing OpenTelemetry Operator"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    (the operator watches for Instrumentation CRs and mutates pods)"

if kubectl get deployment -n opentelemetry-operator-system opentelemetry-operator-controller-manager &>/dev/null; then
  echo "✅ OTEL Operator already installed — skipping"
else
  OTEL_OP_VERSION="v0.97.1"
  kubectl apply -f "https://github.com/open-telemetry/opentelemetry-operator/releases/download/${OTEL_OP_VERSION}/opentelemetry-operator.yaml"
  echo "⏳ Waiting for OTEL Operator to be ready..."
  kubectl rollout status deployment/opentelemetry-operator-controller-manager \
    -n opentelemetry-operator-system --timeout=120s
  echo "✅ OpenTelemetry Operator ready"
fi

# ──────────────────────────────────────────────────────────────────────────────
# STEP 3: Apply the Instrumentation CR
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 STEP 3/5 — Applying Instrumentation CR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    (this tells the operator: use Python auto-instrumentation,"
echo "     send everything to the OTEL Collector via gRPC)"

# The Instrumentation CR lives in the same namespace as the services
# (default namespace). The operator reads it and uses it to configure
# the inject init container.
kubectl apply -f "$(dirname "$0")/../resources/hyderabadi-instrumentation.yaml"

echo "✅ Instrumentation CR applied"

# ──────────────────────────────────────────────────────────────────────────────
# STEP 4: Patch Deployments with the inject annotation
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏷️  STEP 4/5 — Adding inject annotation to Deployments"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    (this single annotation is the ONLY change to the app manifests)"
echo "    annotation: instrumentation.opentelemetry.io/inject-python: 'true'"

for svc in biryani-service chai-service order-service; do
  echo ""
  echo "  🏷️  Annotating $svc..."
  kubectl patch deployment "$svc" -n apps --type=merge -p '{
    "spec": {
      "template": {
        "metadata": {
          "annotations": {
            "instrumentation.opentelemetry.io/inject-python": "true"
          }
        }
      }
    }
  }'
  echo "  ✅ $svc annotated"
done

# ──────────────────────────────────────────────────────────────────────────────
# STEP 5: Wait for rollout
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔄 STEP 5/5 — Rolling restart triggered by annotation patch"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    (each pod will restart with the OTEL init container injected)"

kubectl rollout status deployment/biryani-service -n apps --timeout=120s
kubectl rollout status deployment/chai-service -n apps --timeout=120s
kubectl rollout status deployment/order-service -n apps --timeout=120s

# ──────────────────────────────────────────────────────────────────────────────
# Verify: show what inject looks like
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Verification — Confirming init container injection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for svc in biryani-service chai-service order-service; do
  POD=$(kubectl get pod -n apps -l app="$svc" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$POD" ]; then
    INIT=$(kubectl get pod "$POD" -n apps -o jsonpath='{.spec.initContainers[*].name}' 2>/dev/null)
    echo "  $svc → pod: $POD | init containers: ${INIT:-none}"
  fi
done

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  ✅ OTEL OPERATOR INJECTION COMPLETE!                            ║"
echo "║                                                                  ║"
echo "║  📌 What changed?                                                ║"
echo "║     • 0 lines of application code modified                       ║"
echo "║     • 0 Docker images rebuilt                                    ║"
echo "║     • 1 annotation added per Deployment                          ║"
echo "║     • 1 Instrumentation CR created                               ║"
echo "║                                                                  ║"
echo "║  📊 Check Jaeger UI for distributed traces                       ║"
echo "║  📈 Check VictoriaMetrics for HTTP metrics                       ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
