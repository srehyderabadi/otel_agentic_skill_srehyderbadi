#!/bin/bash
# Helper script to switch between OpenTelemetry Collector configurations

CONFIG_TYPE=$1

if [[ "$CONFIG_TYPE" != "initial" && "$CONFIG_TYPE" != "demo" ]]; then
  echo "Usage: ./switch_otel_config.sh [initial|demo]"
  exit 1
fi

TARGET_CONFIG="otel-collector-config-$CONFIG_TYPE"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
OTEL_YAML="$PROJECT_ROOT/observability/otel-collector.yaml"

echo "🔄 Switching OTEL Collector to use: $TARGET_CONFIG"

# Use sed to update the configMap name in the volumes section
# This looks for the line after '# Change this to...' and updates the name
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s/name: otel-collector-config-.*/name: $TARGET_CONFIG/" "$OTEL_YAML"
else
  sed -i "s/name: otel-collector-config-.*/name: $TARGET_CONFIG/" "$OTEL_YAML"
fi

echo "🚀 Applying updated manifest to Kubernetes..."
kubectl apply -f "$OTEL_YAML"

echo "⏳ Waiting for OTEL Collector to restart..."
kubectl rollout status deployment/otel-collector -n opentelemetry --timeout=60s

echo "✅ Successfully switched to $CONFIG_TYPE configuration!"
