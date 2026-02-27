---
description: Switch OTel Collector configuration between initial and demo profiles (changes which backends receive telemetry)
---

# Switch OTel Collector Configuration

This skill switches the OTel Collector between two configuration profiles that route telemetry to different backends.

## Available Profiles

| Profile     | Traces | Metrics         | Logs | Use Case           |
| ----------- | ------ | --------------- | ---- | ------------------ |
| **initial** | Jaeger | VictoriaMetrics | —    | Default demo setup |
| **demo**    | Tempo  | Prometheus      | Loki | Full Grafana stack |

## Configuration

| Parameter        | Default                                    | How to find                                        |
| ---------------- | ------------------------------------------ | -------------------------------------------------- |
| `CLUSTER_NAME`   | Read from `observability/setup-cluster.sh` | `grep CLUSTER_NAME observability/setup-cluster.sh` |
| `OTEL_YAML`      | `observability/otel-collector.yaml`        | OTel Collector deployment manifest                 |
| `TARGET_PROFILE` | User specifies: `initial` or `demo`        | Ask the user which profile to switch to            |

## Steps

### 1. Set kubectl context

// turbo

```bash
CLUSTER_NAME=$(grep 'CLUSTER_NAME=' observability/setup-cluster.sh | head -1 | cut -d'"' -f2)
kubectl config use-context "k3d-${CLUSTER_NAME}"
```

### 2. Determine current profile

// turbo

```bash
OTEL_YAML="observability/otel-collector.yaml"
CURRENT=$(grep 'name: otel-collector-config-' "${OTEL_YAML}" | tail -1 | sed 's/.*name: otel-collector-config-//')
echo "📋 Current OTel Collector profile: ${CURRENT}"
```

### 3. Switch to target profile

Ask the user which profile they want (`initial` or `demo`) if not already specified.

```bash
TARGET_PROFILE="<initial_or_demo>"  # Replace with the user's choice
OTEL_YAML="observability/otel-collector.yaml"

# Update the configMap reference in the deployment volumes section
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s/name: otel-collector-config-.*/name: otel-collector-config-${TARGET_PROFILE}/" "${OTEL_YAML}"
else
  sed -i "s/name: otel-collector-config-.*/name: otel-collector-config-${TARGET_PROFILE}/" "${OTEL_YAML}"
fi
echo "✅ Updated ${OTEL_YAML} to use profile: ${TARGET_PROFILE}"
```

### 4. Apply and restart

```bash
OTEL_YAML="observability/otel-collector.yaml"
kubectl apply -f "${OTEL_YAML}"
echo "⏳ Waiting for OTel Collector to restart..."
kubectl rollout status deployment/otel-collector -n opentelemetry --timeout=60s
echo "✅ OTel Collector restarted with new config"
```

### 5. Report active backends

// turbo

```bash
echo ""
echo "🔍 Verifying active configuration..."
kubectl get configmap -n opentelemetry -o name
ACTIVE_CM=$(kubectl get deployment otel-collector -n opentelemetry -o jsonpath='{.spec.template.spec.volumes[0].configMap.name}')
echo ""
echo "📋 Active ConfigMap: ${ACTIVE_CM}"
echo ""
echo "📊 Configured exporters:"
kubectl get configmap "${ACTIVE_CM}" -n opentelemetry -o jsonpath='{.data.config\.yaml}' | grep -E '(endpoint|exporters)' | head -10
echo ""
echo "✅ Switch complete!"
```

## Adapting to other tech stacks

- Add more profiles by creating additional `ConfigMap` manifests in `otel-collector.yaml`
- Each profile can target any OTLP-compatible backend (Datadog, New Relic, Elastic, etc.)
- The sed command pattern matches `otel-collector-config-*` — just name your ConfigMaps following that convention
