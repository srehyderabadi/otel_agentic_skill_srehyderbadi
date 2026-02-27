# 🔭 OpenTelemetry Instrumentation — Operator Model

## _Zero code changes. Zero Docker rebuilds. Pure Kubernetes._

> This document walks through **every single change** required to add OpenTelemetry
> to the Hyderabadi Restaurant microservices using the **OTEL Operator auto-injection**
> model. The app code is **never touched**.

---

## 📊 Change Summary at a Glance

| #   | What Changes                   | Where         | Code Change? | Rebuild? |
| --- | ------------------------------ | ------------- | ------------ | -------- |
| 1   | Install cert-manager           | K8s cluster   | ❌ No        | ❌ No    |
| 2   | Install OTEL Operator          | K8s cluster   | ❌ No        | ❌ No    |
| 3   | Apply `Instrumentation` CR     | K8s manifest  | ❌ No        | ❌ No    |
| 4   | Add `inject-python` annotation | 3× Deployment | ❌ No        | ❌ No    |

**Total application files changed: 0**
**Docker images rebuilt: 0**
**Lines of Python modified: 0**

---

## 🔴 BEFORE — Plain Deployment (no OTEL)

```yaml
# k8s/apps_manifests.yaml — order-service Deployment (BEFORE)
spec:
  template:
    metadata:
      labels:
        app: order-service
    spec:
      containers:
        - name: order-service
          image: order-service:latest # ← same image, unchanged
          ports:
            - containerPort: 8000
```

The app has **no idea** what OTEL is. No SDK installed. No traces. No metrics.

---

## 🟢 AFTER — Same Deployment + 1 annotation (with OTEL)

```yaml
# k8s/apps_manifests.yaml — order-service Deployment (AFTER)
spec:
  template:
    metadata:
      labels:
        app: order-service
      annotations:
        # ── THE ONLY CHANGE: one annotation ───────────────────────────
        instrumentation.opentelemetry.io/inject-python: "true"
    spec:
      containers:
        - name: order-service
          image: order-service:latest # ← STILL the same image!
          ports:
            - containerPort: 8000
```

That single annotation triggers the OTEL Operator's **MutatingWebhook** to inject
an init container before the app container starts.

---

## 🏗️ How the Operator Model Works (the magic behind the annotation)

```
  kubectl apply / kubectl patch
         │
         ▼
  ┌─────────────────────────────────────────────────────┐
  │  Kubernetes API Server                              │
  │            │                                        │
  │            │  MutatingAdmissionWebhook              │
  │            ▼                                        │
  │  ┌──────────────────────────────────┐               │
  │  │  OTEL Operator Webhook           │               │
  │  │  • Sees inject-python annotation │               │
  │  │  • Reads Instrumentation CR      │               │
  │  │  • MUTATES the Pod spec:         │               │
  │  │    - Adds initContainer          │               │
  │  │    - Injects PYTHONPATH env var  │               │
  │  │    - Injects OTEL_* env vars     │               │
  │  └──────────────────────────────────┘               │
  └─────────────────────────────────────────────────────┘
         │
         ▼
  Pod starts with 2 containers:
  ┌──────────────────────────────────────────┐
  │ initContainer: opentelemetry-auto-instr  │  ← injected by operator
  │   • copies SDK into /otel-auto-instr/    │
  │   • runs once, then exits                │
  └──────────────────────────────────────────┘
  ┌──────────────────────────────────────────┐
  │ container: order-service                 │  ← your original image
  │   • PYTHONPATH=/otel-auto-instr/...      │  ← injected env var
  │   • OTEL_EXPORTER_OTLP_ENDPOINT=...      │  ← from Instrumentation CR
  │   • OTEL_SERVICE_NAME=order-service      │  ← from Instrumentation CR
  │   • FastAPI auto-instrumented ✅         │
  │   • HTTPX auto-instrumented ✅           │
  │   • Logging auto-instrumented ✅         │
  └──────────────────────────────────────────┘
```

---

## CHANGE 1 — Install cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml
```

**Why:** The OTEL Operator uses a Kubernetes **MutatingAdmissionWebhook** which requires
a valid TLS certificate. cert-manager creates and rotates that certificate automatically.
Without it, the operator's webhook cannot register with the API server.

**What it creates:** Deployments in the `cert-manager` namespace. Does not touch your app at all.

---

## CHANGE 2 — Install OpenTelemetry Operator

```bash
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/download/v0.97.1/opentelemetry-operator.yaml
```

**Why:** This installs:

- The **Operator Deployment** — watches for `Instrumentation` and `OpenTelemetryCollector` CRDs
- The **MutatingWebhook** — intercepts pod creation to inject the init container
- The **CRDs** — `Instrumentation`, `OpenTelemetryCollector`

**What it creates:** Deployments in `opentelemetry-operator-system`. Does not touch your app at all.

---

## CHANGE 3 — Apply the `Instrumentation` CR

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: hyderabadi-instrumentation
  namespace: default
spec:
  exporter:
    endpoint: http://<OBSERVABILITY_INGRESS_IP>:80

  propagators:
    - tracecontext # W3C Trace Context — links spans across services
    - baggage # Pass K/V metadata across service boundaries

  sampler:
    type: parentbased_traceidratio
    argument: "1" # 100% sampling — see everything in the demo

  python:
    env:
      - name: OTEL_TRACES_EXPORTER
        value: otlp
      - name: OTEL_METRICS_EXPORTER
        value: otlp
      - name: OTEL_LOGS_EXPORTER
        value: otlp
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: http/protobuf
      - name: OTEL_PYTHON_LOG_CORRELATION
        value: "true"
```

**Why:** This CR is the **configuration blueprint** for instrumentation. The operator reads it
whenever it sees the `inject-python: "true"` annotation and uses it to decide:

- Where to send traces/metrics/logs (the `exporter.endpoint`)
- Which propagation format to use
- What sampling rate to apply
- Any extra Python-specific env vars

---

## CHANGE 4 — Add `inject-python` annotation to each Deployment

This is done as a live `kubectl patch` — **no YAML file is edited**:

```bash
kubectl patch deployment order-service --type=merge -p '{
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
```

**Why:** This annotation tells the OTEL Operator's MutatingWebhook: _"when creating pods for
this deployment, inject the Python auto-instrumentation init container."_

The webhook then automatically adds:

- An `initContainer` that copies the OTEL SDK into a shared volume
- `PYTHONPATH` env var pointing to the shared OTEL SDK volume
- `OTEL_SERVICE_NAME` set to the deployment name
- `OTEL_EXPORTER_OTLP_ENDPOINT` from the Instrumentation CR
- `OTEL_TRACES_EXPORTER`, `OTEL_METRICS_EXPORTER`, `OTEL_LOGS_EXPORTER`

**Applied to all 3 services:**

```bash
kubectl patch deployment biryani-service ... (same patch)
kubectl patch deployment chai-service    ... (same patch)
kubectl patch deployment order-service   ... (same patch)
```

---

## ↩️ Removing OTEL — Equally Simple

```bash
# Remove annotation (pods restart without OTEL init container)
kubectl annotate deployment biryani-service instrumentation.opentelemetry.io/inject-python-
kubectl annotate deployment chai-service    instrumentation.opentelemetry.io/inject-python-
kubectl annotate deployment order-service   instrumentation.opentelemetry.io/inject-python-

# Delete Instrumentation CR
kubectl delete instrumentation hyderabadi-instrumentation -n default
```

That's it. **No code rollback. No image rebuild.** The pods restart and the init container
is simply not injected this time.

---

## 🎬 Demo Script: Before vs After

### Phase 1 — "Look ma, no observability"

```bash
# Use the agent workflow: /remove-otel-instrumentation
bash .agents/skills/remove-otel-instrumentation/scripts/remove_otel_instrumentation.sh

curl http://localhost:80/order/biryani/chicken
curl http://localhost:80/order/chai/irani
curl http://localhost:80/order/pizza/margherita  # ← 500 error

# Show Jaeger → No traces
# Show VictoriaMetrics → No metrics
```

### Phase 2 — "Add OTEL with zero code changes"

```bash
# Use the agent workflow: /apply-otel-instrumentation
bash .agents/skills/apply-otel-instrumentation/scripts/add_otel_instrumentation.sh
```

**During the 60s wait — show the audience:**

1. `kubectl get instrumentation` — the CR
2. `kubectl describe pod -l app=order-service | grep -A5 "Init Containers"` — the injected init container
3. `kubectl get pod -l app=order-service -o yaml | grep OTEL` — the env vars the operator injected

```bash
curl http://localhost:80/order/biryani/chicken
curl http://localhost:80/order/chai/irani
curl http://localhost:80/order/pizza/margherita  # ← error span!

# Show Jaeger → Full distributed traces! order-service → biryani-service
# Show VictoriaMetrics → HTTP duration/count metrics
```

---

## ✅ Verification Commands

```bash
# 1. Check the operator is running
kubectl get pods -n opentelemetry-operator-system

# 2. Check the Instrumentation CR exists
kubectl get instrumentation -n default

# 3. Check pods have the init container (shows OTEL was injected)
kubectl describe pod -l app=order-service | grep -A5 "Init Containers:"

# 4. Check the OTEL env vars were injected
kubectl get pod -l app=order-service -o jsonpath='{.items[0].spec.containers[0].env}' | python3 -m json.tool | grep OTEL

# 5. Check traces in Jaeger
open http://localhost:80/jaeger
```
