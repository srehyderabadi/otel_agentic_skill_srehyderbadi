---
name: cluster-health-check
description: Check Kubernetes cluster health — list running application services, pod status, active OTel backends, OTel Operator status, Instrumentation CRs, and accessible UI ingress endpoints
---

# Cluster Health Check

Gives a full status report of the Kubernetes cluster: running services, pod health, which OTel backends are active, and which UIs are accessible.

## Quick Run (OTel Backends Only)

```bash
bash .agents/skills/cluster-health-check/scripts/show_otel_backends.sh
```

## Full Health Check

### 1. Set kubectl context

```bash
CLUSTER_NAME=$(grep 'CLUSTER_NAME=' observability/setup-cluster.sh | head -1 | cut -d'"' -f2)
kubectl config use-context "k3d-${CLUSTER_NAME}"
echo "📋 Cluster: ${CLUSTER_NAME}"
```

### 2. Application services

```bash
echo ""
echo "═══════════════════════════════════════════════"
echo "  📦 APPLICATION SERVICES (apps namespace)"
echo "═══════════════════════════════════════════════"
kubectl get deployments -n apps -o wide 2>/dev/null || echo "  No deployments found"
echo ""
kubectl get pods -n apps -o wide 2>/dev/null || echo "  No pods found"
```

### 3. Observability components

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

### 4. OTel Operator and Instrumentation CRs

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

### 5. Active OTel Collector backends

```bash
echo ""
echo "═══════════════════════════════════════════════"
echo "  📊 ACTIVE OTEL COLLECTOR BACKENDS"
echo "═══════════════════════════════════════════════"
ACTIVE_CM=$(kubectl get deployment otel-collector -n opentelemetry \
  -o jsonpath='{.spec.template.spec.volumes[0].configMap.name}' 2>/dev/null)
if [ -n "$ACTIVE_CM" ]; then
  echo "  ConfigMap: ${ACTIVE_CM}"
  CONFIG=$(kubectl get configmap "${ACTIVE_CM}" -n opentelemetry -o jsonpath='{.data.config\.yaml}' 2>/dev/null)
  echo "  Exporter endpoints:"
  echo "$CONFIG" | grep 'endpoint:' | while IFS= read -r line; do echo "    $line"; done
else
  echo "  ❌ OTel Collector not found"
fi
```

### 6. Ingress endpoints

```bash
echo ""
echo "═══════════════════════════════════════════════"
echo "  🌐 ACCESSIBLE UIs (via Ingress)"
echo "═══════════════════════════════════════════════"
kubectl get ingress --all-namespaces \
  -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {range .spec.rules[*].http.paths[*]}{.path} -> {.backend.service.name}:{.backend.service.port.number} {end}{"\n"}{end}' 2>/dev/null \
  | while IFS= read -r line; do echo "  $line"; done

echo ""
echo "═══════════════════════════════════════════════"
echo "  ✅ HEALTH CHECK COMPLETE"
echo "═══════════════════════════════════════════════"
```
