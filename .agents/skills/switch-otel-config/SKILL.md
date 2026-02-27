---
name: switch-otel-config
description: Switch OTel Collector configuration between initial and demo profiles (changes which backends receive telemetry)
---

# Switch OTel Collector Configuration

Switches the OTel Collector between two configuration profiles that route telemetry to different backends.

## Available Profiles

| Profile     | Traces | Metrics         | Logs | Use Case           |
| ----------- | ------ | --------------- | ---- | ------------------ |
| **initial** | Jaeger | VictoriaMetrics | —    | Default demo setup |
| **demo**    | Tempo  | Prometheus      | Loki | Full Grafana stack |

## Scripts

| Script                          | Purpose                                                                                                    |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `scripts/switch_otel_config.sh` | Updates the ConfigMap reference in `otel-collector.yaml`, applies the manifest, and restarts the collector |

## Instructions

1. **Set kubectl context** to the target k3d cluster.
2. **Run the script**:
   ```bash
   bash .agents/skills/switch-otel-config/scripts/switch_otel_config.sh [initial|demo]
   ```
3. **Alternatively**, follow the step-by-step workflow: use `/switch-otel-config`.

## Configuration

| Parameter        | Default                                    | How to find                                        |
| ---------------- | ------------------------------------------ | -------------------------------------------------- |
| `CLUSTER_NAME`   | Read from `observability/setup-cluster.sh` | `grep CLUSTER_NAME observability/setup-cluster.sh` |
| `OTEL_YAML`      | `observability/otel-collector.yaml`        | OTel Collector deployment manifest                 |
| `TARGET_PROFILE` | User specifies: `initial` or `demo`        | Ask the user which profile to switch to            |

## Adapting to Other Tech Stacks

- Add more profiles by creating additional `ConfigMap` manifests in `otel-collector.yaml`
- Each profile can target any OTLP-compatible backend (Datadog, New Relic, Elastic, etc.)
- The sed command pattern matches `otel-collector-config-*` — just name your ConfigMaps following that convention
