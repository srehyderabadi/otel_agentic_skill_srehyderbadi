#!/bin/bash
# =============================================================================
# 🔄 REMOVE OTEL — OPERATOR / AUTO-INJECTION MODEL
# =============================================================================
# Removes OTEL instrumentation WITHOUT touching any application code
# or rebuilding Docker images.
#
# What this script does:
#   1. Remove the inject annotation from all 3 Deployments
#      → pods restart without the OTEL init container
#   2. Delete the Instrumentation CR
#      → operator stops injecting into new pods
#   (Optional) Uninstall the OTEL Operator and cert-manager
#              → uncomment the last section for full teardown
# =============================================================================

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
K3D_CLUSTER="cncf-hyd"
kubectl config use-context "k3d-${K3D_CLUSTER}"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🔄 REMOVING OTEL INJECTION — Back to clean mode!            ║"
echo "║  No code changes. No image rebuilds. Just annotation removal. ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# STEP 1: Remove the inject annotation from each Deployment
# ──────────────────────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏷️  STEP 1/3 — Removing inject annotation from Deployments"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    kubectl annotate deployment <name> instrumentation.opentelemetry.io/inject-python-"
echo "    (the trailing '-' removes the annotation in kubectl)"

for svc in biryani-service chai-service order-service; do
  echo ""
  echo "  🗑️  Removing annotation from $svc..."
  kubectl annotate deployment "$svc" -n apps \
    instrumentation.opentelemetry.io/inject-python- \
    --overwrite 2>/dev/null || true
  echo "  ✅ $svc annotation removed"
done

# ──────────────────────────────────────────────────────────────────────────────
# STEP 2: Delete the Instrumentation CR
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 STEP 2/3 — Deleting Instrumentation CR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

kubectl delete instrumentation hyderabadi-instrumentation -n apps --ignore-not-found
echo "✅ Instrumentation CR deleted"

# ──────────────────────────────────────────────────────────────────────────────
# STEP 3: Wait for pods to restart without the init container
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔄 STEP 3/3 — Rolling restart (annotation removal triggers it)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

kubectl rollout restart deployment/biryani-service deployment/chai-service deployment/order-service -n apps
kubectl rollout status deployment/biryani-service -n apps --timeout=90s
kubectl rollout status deployment/chai-service -n apps --timeout=90s
kubectl rollout status deployment/order-service -n apps --timeout=90s

# Confirm the init container is gone
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Verification — Confirming init container is removed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for svc in biryani-service chai-service order-service; do
  POD=$(kubectl get pod -n apps -l app="$svc" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -n "$POD" ]; then
    INIT=$(kubectl get pod "$POD" -n apps -o jsonpath='{.spec.initContainers[*].name}' 2>/dev/null)
    if [ -z "$INIT" ]; then
      echo "  ✅ $svc → pod $POD has NO init containers (OTEL removed)"
    else
      echo "  ⚠️  $svc → pod $POD still has init containers: $INIT"
    fi
  fi
done

echo ""
echo "  🔍 Checking Instrumentation CR..."
if ! kubectl get instrumentation hyderabadi-instrumentation -n apps >/dev/null 2>&1; then
  echo "  ✅ Instrumentation CR 'hyderabadi-instrumentation' is successfully deleted"
else
  echo "  ⚠️  Instrumentation CR 'hyderabadi-instrumentation' still exists!"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  ✅ OTEL INJECTION REMOVED!                                      ║"
echo "║                                                                  ║"
echo "║  📌 What changed?                                                ║"
echo "║     • 0 lines of application code modified                       ║"
echo "║     • 0 Docker images rebuilt                                    ║"
echo "║     • Annotation removed from 3 Deployments                      ║"
echo "║     • Instrumentation CR deleted                                  ║"
echo "║     • Pods restarted without the OTEL init container             ║"
echo "║                                                                  ║"
echo "║  The OTEL Operator is still installed (runs silently).           ║"
echo "║  Use /apply-otel-instrumentation workflow to re-enable any time. ║"
echo "╚══════════════════════════════════════════════════════════════════╝"

# ──────────────────────────────────────────────────────────────────────────────
# OPTIONAL: Full teardown — uninstall operator and cert-manager
# Uncomment the block below ONLY if you want a complete cleanup.
# ──────────────────────────────────────────────────────────────────────────────
# echo ""
# echo "🔥 FULL TEARDOWN — Uninstalling OTEL Operator..."
# OTEL_OP_VERSION="v0.97.1"
# kubectl delete -f "https://github.com/open-telemetry/opentelemetry-operator/releases/download/${OTEL_OP_VERSION}/opentelemetry-operator.yaml" --ignore-not-found
# echo "🔥 Uninstalling cert-manager..."
# kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml --ignore-not-found
# echo "✅ Full teardown complete"
