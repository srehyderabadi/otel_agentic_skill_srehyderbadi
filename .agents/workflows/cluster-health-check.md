---
description: Check cluster health — running services, pod status, OTel backends configured, and available UIs
---

# Cluster Health Check

This skill gives a full status report of the Kubernetes cluster: running services, pod health, which OTel backends are active, and which UIs are accessible.

## Configuration

| Parameter                  | Default                                            | How to find                                        |
| -------------------------- | -------------------------------------------------- | -------------------------------------------------- |
| `CLUSTER_NAME`             | Read from `observability/setup-cluster.sh`         | `grep CLUSTER_NAME observability/setup-cluster.sh` |
| `APP_NAMESPACE`            | `apps`                                             | Namespace where app deployments live               |
| `OBSERVABILITY_NAMESPACES` | Auto-discover from `observability/namespaces.yaml` | All namespaces defined in the file                 |

## Steps

### 1. Set kubectl context

// turbo

```bash
CLUSTER_NAME=$(grep 'CLUSTER_NAME=' observability/setup-cluster.sh | head -1 | cut -d'"' -f2)
kubectl config use-context "k3d-${CLUSTER_NAME}"
echo "📋 Cluster: ${CLUSTER_NAME}"
```

### 2. List all application services and their status

// turbo

```bash
echo ""
echo "═══════════════════════════════════════════════"
echo "  📦 APPLICATION SERVICES (apps namespace)"
echo "═══════════════════════════════════════════════"
kubectl get deployments -n apps -o wide 2>/dev/null || echo "  No deployments found in apps namespace"
echo ""
kubectl get pods -n apps -o wide 2>/dev/null || echo "  No pods found in apps namespace"
```

### 3. List all observability components

// turbo

```bash
echo ""
echo "═══════════════════════════════════════════════"
echo "  🔭 OBSERVABILITY COMPONENTS"
echo "═══════════════════════════════════════════════"
for NS in opentelemetry grafana jaeger victoriametrics prometheus loki tempo; do
  PODS=$(kubectl get pods -n ${NS} --no-headers 2>/dev/null)
  if [ -n "$PODS" ]; then
    echo ""
    echo "  📌 Namespace: ${NS}"
    echo "$PODS" | while IFS= read -r line; do echo "     $line"; done
  fi
done
```

### 4. Check OTel Operator and Instrumentation CR status

// turbo

```bash
echo ""
echo "═══════════════════════════════════════════════"
echo "  🎛️  OTEL OPERATOR STATUS"
echo "═══════════════════════════════════════════════"
if kubectl get deployment -n opentelemetry-operator-system opentelemetry-operator-controller-manager &>/dev/null; then
  echo "  ✅ OTel Operator: INSTALLED"
  kubectl get deployment -n opentelemetry-operator-system --no-headers 2>/dev/null | while IFS= read -r line; do echo "     $line"; done
else
  echo "  ❌ OTel Operator: NOT INSTALLED"
fi

echo ""
echo "  📋 Instrumentation CRs:"
INSTR=$(kubectl get instrumentation --all-namespaces --no-headers 2>/dev/null)
if [ -n "$INSTR" ]; then
  echo "$INSTR" | while IFS= read -r line; do echo "     $line"; done
else
  echo "     (none found — OTel injection is not active)"
fi
```

### 5. Show currently configured OTel backends

// turbo

```bash
echo ""
echo "═══════════════════════════════════════════════"
echo "  📊 ACTIVE OTEL COLLECTOR BACKENDS"
echo "═══════════════════════════════════════════════"
ACTIVE_CM=$(kubectl get deployment otel-collector -n opentelemetry -o jsonpath='{.spec.template.spec.volumes[0].configMap.name}' 2>/dev/null)
if [ -n "$ACTIVE_CM" ]; then
  echo "  ConfigMap: ${ACTIVE_CM}"
  echo ""
  CONFIG=$(kubectl get configmap "${ACTIVE_CM}" -n opentelemetry -o jsonpath='{.data.config\.yaml}' 2>/dev/null)

  echo "  Pipelines:"
  echo "$CONFIG" | grep -A1 'traces:' | head -3 | while IFS= read -r line; do echo "     $line"; done
  echo "$CONFIG" | grep -A1 'metrics:' | head -3 | while IFS= read -r line; do echo "     $line"; done
  echo "$CONFIG" | grep -A1 'logs:' | head -3 | while IFS= read -r line; do echo "     $line"; done

  echo ""
  echo "  Exporter endpoints:"
  echo "$CONFIG" | grep 'endpoint:' | while IFS= read -r line; do echo "    $line"; done
else
  echo "  ❌ OTel Collector not found"
fi
```

### 6. Show ingress endpoints

// turbo

```bash
echo ""
echo "═══════════════════════════════════════════════"
echo "  🌐 ACCESSIBLE UIs (via Ingress)"
echo "═══════════════════════════════════════════════"
INGRESS_RULES=$(kubectl get ingress --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {range .spec.rules[*].http.paths[*]}{.path} -> {.backend.service.name}:{.backend.service.port.number} {end}{"\n"}{end}' 2>/dev/null)
if [ -n "$INGRESS_RULES" ]; then
  echo "$INGRESS_RULES" | while IFS= read -r line; do echo "  $line"; done
else
  echo "  No ingress rules found"
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "  ✅ HEALTH CHECK COMPLETE"
echo "═══════════════════════════════════════════════"
```

## Adapting to other tech stacks

- Modify the `APP_NAMESPACE` and namespace list to match your cluster layout
- The OTel Collector backend detection works generically by reading the active ConfigMap
- Ingress endpoint discovery works with any Kubernetes ingress controller
