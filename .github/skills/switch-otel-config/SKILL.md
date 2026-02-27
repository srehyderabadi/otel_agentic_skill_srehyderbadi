---
name: switch-otel-config
description: Switch the OTel Collector configuration between the initial profile (Jaeger + VictoriaMetrics) and the demo profile (Tempo + Prometheus + Loki) — changes which backends receive telemetry without redeploying
---

# Switch OTel Collector Configuration

Switches the OTel Collector between two configuration profiles that route telemetry to different backends.

## Available Profiles

| Profile   | Traces | Metrics         | Logs | Use Case           |
| --------- | ------ | --------------- | ---- | ------------------ |
| `initial` | Jaeger | VictoriaMetrics | —    | Default demo setup |
| `demo`    | Tempo  | Prometheus      | Loki | Full Grafana stack |

## Quick Run

```bash
bash .agents/skills/switch-otel-config/scripts/switch_otel_config.sh [initial|demo]
```

Example:

```bash
bash .agents/skills/switch-otel-config/scripts/switch_otel_config.sh demo
```

## Step-by-Step

### 1. Set kubectl context

```bash
CLUSTER_NAME=$(grep 'CLUSTER_NAME=' observability/setup-cluster.sh | head -1 | cut -d'"' -f2)
kubectl config use-context "k3d-${CLUSTER_NAME}"
```

### 2. Check current profile

```bash
OTEL_YAML="observability/otel-collector.yaml"
CURRENT=$(grep 'name: otel-collector-config-' "${OTEL_YAML}" | tail -1 | sed 's/.*name: otel-collector-config-//')
echo "📋 Current OTel Collector profile: ${CURRENT}"
```

### 3. Switch to target profile

Ask the user which profile they want (`initial` or `demo`) if not already specified, then run:

```bash
TARGET_PROFILE="demo"   # Replace with: initial | demo
OTEL_YAML="observability/otel-collector.yaml"

if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s/name: otel-collector-config-.*/name: otel-collector-config-${TARGET_PROFILE}/" "${OTEL_YAML}"
else
  sed -i "s/name: otel-collector-config-.*/name: otel-collector-config-${TARGET_PROFILE}/" "${OTEL_YAML}"
fi
echo "✅ Updated to profile: ${TARGET_PROFILE}"
```

### 4. Apply and restart

```bash
OTEL_YAML="observability/otel-collector.yaml"
kubectl apply -f "${OTEL_YAML}"
kubectl rollout status deployment/otel-collector -n opentelemetry --timeout=60s
echo "✅ OTel Collector restarted with new config"
```

### 5. Verify active backends

```bash
ACTIVE_CM=$(kubectl get deployment otel-collector -n opentelemetry \
  -o jsonpath='{.spec.template.spec.volumes[0].configMap.name}')
echo "📋 Active ConfigMap: ${ACTIVE_CM}"
echo ""
echo "📊 Configured exporters:"
kubectl get configmap "${ACTIVE_CM}" -n opentelemetry \
  -o jsonpath='{.data.config\.yaml}' | grep -E '(endpoint|exporters)' | head -10
echo "✅ Switch complete!"
```

## Configuration

| Parameter        | Default                             | Notes                              |
| ---------------- | ----------------------------------- | ---------------------------------- |
| `TARGET_PROFILE` | User specifies: `initial` or `demo` | Ask before running Step 3          |
| `OTEL_YAML`      | `observability/otel-collector.yaml` | OTel Collector deployment manifest |
