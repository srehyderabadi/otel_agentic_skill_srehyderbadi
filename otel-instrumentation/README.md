# 🔭 OTEL Instrumentation — Operator Model

## Zero code changes. Zero image rebuilds.

---

## 📁 Contents

| File                              | Purpose                                                                                            |
| --------------------------------- | -------------------------------------------------------------------------------------------------- |
| `hyderabadi-instrumentation.yaml` | The `Instrumentation` CR manifest (also in `.agents/skills/apply-otel-instrumentation/resources/`) |

> [!IMPORTANT]
> All instrumentation scripts and resources live inside the **agent skills** directory structure:
>
> ```
> .agents/skills/
> ├── apply-otel-instrumentation/    ← Install OTel Operator + inject instrumentation
> │   ├── scripts/add_otel_instrumentation.sh
> │   └── resources/
> │       ├── hyderabadi-instrumentation.yaml  (Instrumentation CR)
> │       └── otel_changes_explained.md
> ├── remove-otel-instrumentation/   ← Strip annotations + delete CR
> │   └── scripts/remove_otel_instrumentation.sh
> ├── switch-otel-config/            ← Switch OTel Collector between initial / demo profiles
> │   └── scripts/switch_otel_config.sh
> └── cluster-health-check/          ← Full cluster health + active OTel backend report
>     └── scripts/show_otel_backends.sh
> ```
>
> Use agent workflows from chat:
>
> | Slash Command                  | What It Does                                        |
> | ------------------------------ | --------------------------------------------------- |
> | `/apply-otel-instrumentation`  | Install operator + inject instrumentation into pods |
> | `/remove-otel-instrumentation` | Strip annotations + delete Instrumentation CR       |
> | `/switch-otel-config`          | Switch OTel Collector profile (initial ↔ demo)      |
> | `/cluster-health-check`        | Full cluster health report + OTel backend status    |

---

## 📊 What changes with the Operator model

| #   | Change                         | Where         | App Code? | Image Rebuild? |
| --- | ------------------------------ | ------------- | --------- | -------------- |
| 1   | Install cert-manager           | cluster       | ❌        | ❌             |
| 2   | Install OTel Operator          | cluster       | ❌        | ❌             |
| 3   | Apply `Instrumentation` CR     | K8s           | ❌        | ❌             |
| 4   | Add `inject-python` annotation | 3× Deployment | ❌        | ❌             |

**Total app files changed: 0. Docker images rebuilt: 0.**

The operator injects a Python OTel SDK init container at pod startup via a `MutatingAdmissionWebhook`. Your image stays exactly as-is.

---

## 🎬 Demo Flow

**Phase 1 — No OTEL:** Run `/remove-otel-instrumentation`, then open Jaeger → no traces.

**Phase 2 — Add OTEL live:** Run `/apply-otel-instrumentation`, then verify injection:

```bash
kubectl describe pod -l app=order-service -n apps | grep -A5 "Init Containers:"
```

Open Jaeger → Full distributed traces appear! 🎉

**Phase 3 — Switch backends:** Run `/switch-otel-config demo` → OTel Collector routes to Prometheus + Tempo + Loki.

**Phase 4 — Health check:** Run `/cluster-health-check` → Full report of running services, OTel backends, and ingress endpoints.
