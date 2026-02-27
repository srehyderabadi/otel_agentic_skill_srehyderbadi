#!/bin/bash
# show_otel_backends.sh
# Reports which OTel Collector config is active and what backend targets are configured per signal.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Resolve cluster name
CLUSTER_NAME=$(grep 'CLUSTER_NAME=' "$PROJECT_ROOT/observability/setup-cluster.sh" 2>/dev/null | head -1 | cut -d'=' -f2 | tr -d '"' || echo "cncf-hyd")
OTEL_NAMESPACE="opentelemetry"
OTEL_DEPLOYMENT="otel-collector"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  📡 OTEL BACKEND STATUS — Active config & targets            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Set kubectl context
kubectl config use-context "k3d-${CLUSTER_NAME}" 2>/dev/null

# ── Step 1: Find active ConfigMap ────────────────────────────────────────────
ACTIVE_CM=$(kubectl get deployment "$OTEL_DEPLOYMENT" -n "$OTEL_NAMESPACE" \
  -o jsonpath='{.spec.template.spec.volumes[0].configMap.name}' 2>/dev/null)

if [[ -z "$ACTIVE_CM" ]]; then
  echo "  ❌ Could not find OTel Collector deployment in namespace '$OTEL_NAMESPACE'"
  exit 1
fi

# Infer profile name from ConfigMap name
if [[ "$ACTIVE_CM" == *"initial"* ]]; then
  PROFILE="initial"
elif [[ "$ACTIVE_CM" == *"demo"* ]]; then
  PROFILE="demo"
else
  PROFILE="custom"
fi

echo "  ┌─────────────────────────────────────────────────┐"
echo "  │  Active ConfigMap : $ACTIVE_CM"
echo "  │  Profile          : $PROFILE"
echo "  └─────────────────────────────────────────────────┘"
echo ""

# ── Step 2: Fetch config.yaml from the ConfigMap ─────────────────────────────
CONFIG=$(kubectl get configmap "$ACTIVE_CM" -n "$OTEL_NAMESPACE" \
  -o jsonpath='{.data.config\.yaml}' 2>/dev/null)

if [[ -z "$CONFIG" ]]; then
  echo "  ❌ ConfigMap '$ACTIVE_CM' not found or has no 'config.yaml' key"
  exit 1
fi

# ── Step 3: Parse exporters per pipeline ─────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📤  EXPORTERS (backend targets)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$CONFIG" | awk '
  /^exporters:/ { in_exporters=1; next }
  in_exporters && /^[a-z]/ && !/^  / { in_exporters=0 }
  in_exporters && /^  [a-zA-Z]/ { gsub(/:/, "", $1); exporter=$1; next }
  in_exporters && /endpoint:/ {
    gsub(/[" ]/, "", $2);
    printf "  %-35s → %s\n", exporter, $2
  }
'
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔀  PIPELINES (signal → exporters)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$CONFIG" | awk '
  /^service:/ { in_service=1; next }
  /^  pipelines:/ { in_pipelines=1; next }
  in_pipelines && /^    [a-z]/ { pipeline=$1; gsub(/:/, "", pipeline); next }
  in_pipelines && /exporters:/ {
    gsub(/exporters: /, "")
    printf "  %-10s → %s\n", pipeline, $0
  }
'
echo ""

# ── Step 4: Collector pod health ──────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🟢  COLLECTOR POD STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
DEPLOY_STATUS=$(kubectl get deployment "$OTEL_DEPLOYMENT" -n "$OTEL_NAMESPACE" \
  --no-headers -o custom-columns="READY:.status.readyReplicas,DESIRED:.spec.replicas" 2>/dev/null)
READY=$(echo "$DEPLOY_STATUS" | awk '{print $1}')
DESIRED=$(echo "$DEPLOY_STATUS" | awk '{print $2}')
if [[ "$READY" == "$DESIRED" && -n "$READY" ]]; then
  echo "  ✅ $OTEL_DEPLOYMENT  ready=${READY}/${DESIRED}  (Running)"
else
  echo "  ⚠️  $OTEL_DEPLOYMENT  ready=${READY:-0}/${DESIRED:-?}  (Not fully ready)"
fi
echo ""
echo "✅  Done."
