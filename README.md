# CNCF Hyderabad — OTel Demo with Agent Skills

A full observability demo that showcases **OpenTelemetry auto-instrumentation** on a Python microservices app running in `k3d`, powered by **AI agent skills** for zero-friction operations.

---

## 📊 Presentation Decks

- [Blind to Boundless: Agentic OpenTelemetry](./presentation/Blind_to_Boundless-Agentic_OTel.pdf) — Main presentation cover
- [Agent Skills vs Direct Scripts](./presentation/directscripts_vs_agentskills.pdf) — Comparison guide

---

## 📋 Prerequisites

Before running this demo, ensure the following tools and utilities are installed and available in your `PATH`.

### ✅ Run the Validation Script First

```bash
bash validate_setup.sh
```

This script checks every required tool, validates versions, and reports pass/fail for your environment. Run it before anything else.

---

### 🔧 Required Tools & Minimum Versions

| Tool / Utility      | Purpose                                      | Install Reference                                                   | Min Version |
| ------------------- | -------------------------------------------- | ------------------------------------------------------------------- | ----------- |
| **Docker**          | Build & run container images                 | [docs.docker.com](https://docs.docker.com/get-docker/)              | 20.x        |
| **k3d**             | Lightweight Kubernetes cluster on Docker     | [k3d.io](https://k3d.io/stable/#installation)                       | 5.x         |
| **kubectl**         | Kubernetes CLI — apply manifests, debug pods | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/)            | 1.24+       |
| **Helm**            | Install OTel Operator & cert-manager         | [helm.sh](https://helm.sh/docs/intro/install/)                      | 3.x         |
| **k6**              | Load testing / traffic generation            | [k6.io/docs](https://grafana.com/docs/k6/latest/set-up/install-k6/) | 0.45+       |
| **Python 3**        | App microservices runtime                    | [python.org](https://www.python.org/downloads/)                     | 3.10+       |
| **pip**             | Python package manager                       | Bundled with Python                                                 | —           |
| **curl**            | HTTP testing & health checks                 | Pre-installed on most systems                                       | —           |
| **jq** _(optional)_ | Pretty-print JSON in terminal                | [stedolan.github.io/jq](https://stedolan.github.io/jq/)             | 1.6+        |

### ☁️ Platform Requirements

| Requirement           | Details                                                 |
| --------------------- | ------------------------------------------------------- |
| **OS**                | macOS or Linux (WSL2 on Windows with Docker Desktop)    |
| **RAM**               | ≥ 8 GB recommended (cluster + observability stack)      |
| **Disk**              | ≥ 5 GB free (for Docker images and k3d volumes)         |
| **Port 80 available** | k3d maps ingress to `localhost:80`                      |
| **Internet access**   | Helm chart pulls (cert-manager, OTel Operator) at setup |

---

## 🏗️ Technology Stack

### Application Layer

| Component           | Technology       | Description                                            |
| ------------------- | ---------------- | ------------------------------------------------------ |
| **biryani-service** | Python + FastAPI | Serves biryani orders; upstream to order-service       |
| **chai-service**    | Python + FastAPI | Serves chai orders; upstream to order-service          |
| **order-service**   | Python + FastAPI | Orchestrates calls to biryani-service and chai-service |

### Kubernetes & Cluster

| Component              | Technology | Description                                                |
| ---------------------- | ---------- | ---------------------------------------------------------- |
| **Kubernetes cluster** | k3d + k3s  | Lightweight local cluster running inside Docker containers |
| **Ingress controller** | Traefik    | Bundled with k3s; routes all UI traffic via `localhost:80` |
| **Namespaces**         | Kubernetes | `apps`, `opentelemetry`, `observability`                   |

### OpenTelemetry

| Component                | Technology                      | Description                                                      |
| ------------------------ | ------------------------------- | ---------------------------------------------------------------- |
| **OTel Operator**        | cert-manager + OTel Operator    | Installed via Helm; manages auto-instrumentation injection       |
| **OTel Collector**       | OpenTelemetry Collector         | Receives OTLP traces & metrics; routes to configured backends    |
| **Instrumentation CR**   | `Instrumentation` (CRD)         | Defines SDK config, propagators, samplers, and exporter endpoint |
| **Auto-instrumentation** | `opentelemetry-distro` (Python) | Injected as init container; zero app code changes                |
| **OTLP Receiver**        | gRPC (4317) + HTTP (4318)       | Collector endpoints used by instrumented pods                    |

### Observability Backends

| Backend             | Role           | Profile   | UI Path                      |
| ------------------- | -------------- | --------- | ---------------------------- |
| **VictoriaMetrics** | Metrics store  | `initial` | Internal; queried by Grafana |
| **Jaeger**          | Trace store    | `initial` | `/jaeger`                    |
| **Prometheus**      | Metrics store  | `demo`    | Internal; queried by Grafana |
| **Tempo**           | Trace store    | `demo`    | Internal; queried by Grafana |
| **Loki**            | Log aggregator | `demo`    | Internal; queried by Grafana |
| **Grafana**         | Unified UI     | Both      | `/grafana`                   |

### Load Testing

| Component           | Technology | Description                                        |
| ------------------- | ---------- | -------------------------------------------------- |
| **Load generator**  | k6         | JavaScript-based scripts for healthy + error loads |
| **healthy_load.js** | k6 script  | 200 req/min hitting biryani + chai endpoints       |
| **error_load.js**   | k6 script  | 150 req/min mixing valid + invalid endpoints       |

### AI Agent Layer

| Component             | Description                                                                         |
| --------------------- | ----------------------------------------------------------------------------------- |
| **Agent Skills**      | Reusable skill definitions in `.agents/skills/` with shell scripts                  |
| **Workflows**         | Slash-command driven operations in `.agents/workflows/`                             |
| **Antigravity Agent** | Google DeepMind AI assistant that executes skills via plain English                 |
| **Copilot Prompts**   | VS Code Copilot Chat prompt files in `.github/prompts/` — same ops, different agent |

---

## 📁 Project Structure

```
.
├── apps/                               # Python microservices source code
│   ├── biryani_service/                # FastAPI biryani service
│   ├── chai_service/                   # FastAPI chai service
│   └── order_service/                  # FastAPI order orchestrator
├── k8s/
│   └── apps_manifests.yaml             # Kubernetes deployment + service manifests for apps
├── observability/                      # Observability stack manifests
│   ├── setup-cluster.sh               # Create k3d cluster with ingress port mapping
│   ├── namespaces.yaml                # Kubernetes namespaces (apps, opentelemetry, observability)
│   ├── otel-collector.yaml            # OTel Collector (both initial and demo ConfigMaps)
│   ├── victoriametrics.yaml           # VictoriaMetrics deployment & service
│   ├── jaeger.yaml                    # Jaeger all-in-one deployment & service
│   ├── prometheus.yaml               # Prometheus deployment & service
│   ├── tempo.yaml                    # Tempo deployment & service
│   ├── loki.yaml                     # Loki deployment & service
│   ├── grafana.yaml                  # Grafana with pre-configured datasources
│   ├── ingress.yaml                  # Traefik ingress rules for all UIs
│   └── README.md                     # Phase 1 & 2 observability setup guide
├── otel-instrumentation/              # OTel Operator model explainer & Instrumentation CR
│   └── README.md                     # Operator model demo guide
├── k6_scripts/                        # k6 load-test scripts
│   ├── healthy_load.js               # Healthy traffic (200 req/min)
│   └── error_load.js                 # Mixed error traffic (150 req/min)
├── .agents/                           # AI agent skills and workflows (Antigravity)
│   ├── skills/
│   │   ├── apply-otel-instrumentation/  # Install OTel Operator + inject instrumentation
│   │   ├── remove-otel-instrumentation/ # Strip instrumentation annotations + delete CR
│   │   ├── switch-otel-config/          # Switch OTel Collector profile (initial ↔ demo)
│   │   └── cluster-health-check/        # Full cluster health + OTel backend report
│   └── workflows/
│       ├── apply-otel-instrumentation.md
│       ├── remove-otel-instrumentation.md
│       ├── switch-otel-config.md
│       └── cluster-health-check.md
├── .github/                           # VS Code Copilot Chat integration
│   ├── copilot-instructions.md        # Always-on workspace context for Copilot
│   ├── skills/                        # 🤖 VS Code Copilot Agent Skills (plain-English auto-select)
│   │   ├── apply-otel-instrumentation/SKILL.md
│   │   ├── remove-otel-instrumentation/SKILL.md
│   │   ├── switch-otel-config/SKILL.md
│   │   └── cluster-health-check/SKILL.md
│   └── prompts/                       # Alternative: manual prompt attach with #
│       ├── apply-otel-instrumentation.prompt.md
│       ├── remove-otel-instrumentation.prompt.md
│       ├── switch-otel-config.prompt.md
│       └── cluster-health-check.prompt.md
├── presentation/                      # Presentation decks
│   ├── Blind_to_Boundless-Agentic_OTel.pdf
│   └── directscripts_vs_agentskills.pdf
├── build_docker.sh                    # Build Docker images & import into k3d
├── run_k6.sh                          # Interactive load test runner
├── validate_setup.sh                  # ✅ Environment prerequisite validation script
├── requirements.txt                   # Python dependencies for local dev
└── SAMPLE_QUERIES.md                  # Sample validation queries for backends
```

---

## 🚀 Quick Start

### Step 1 — Validate Your Environment

```bash
bash validate_setup.sh
```

All checks must pass before proceeding.

### Step 2 — Create the Cluster

```bash
cd observability && ./setup-cluster.sh
```

This creates a k3d cluster named `cncf-hyd` with ingress on port 80.

### Step 3 — Deploy Observability Stack

```bash
cd observability
kubectl apply -f namespaces.yaml

# ── Phase 1 backends (initial profile: VictoriaMetrics + Jaeger) ──
kubectl apply -f victoriametrics.yaml
kubectl apply -f jaeger.yaml

# ── Phase 2 backends (demo profile: Prometheus + Tempo + Loki) ────
kubectl apply -f prometheus.yaml
kubectl apply -f tempo.yaml
kubectl apply -f loki.yaml

# ── Shared: OTel Collector, Grafana, Ingress ──────────────────────
kubectl apply -f otel-collector.yaml
kubectl apply -f grafana.yaml
kubectl apply -f ingress.yaml
```

> All backends are deployed upfront so both `initial` and `demo` OTel profiles work instantly when you switch — no extra `kubectl apply` needed later.

### Step 4 — Build & Deploy App Services

Build Docker images and import them into the k3d cluster:

```bash
./build_docker.sh
```

Deploy to Kubernetes:

```bash
kubectl apply -f k8s/apps_manifests.yaml
```

### Step 5 — Verify Deployment

```bash
# Check running pods
kubectl get pods -n apps

# Check services
kubectl get svc -n apps

# Check ingress
kubectl get ingress -n apps
```

---

## 🤖 Agent Skills & Workflows

This project supports **two AI agents** — pick whichever you use:

### Antigravity (Google DeepMind)

Use plain-English prompts or slash commands in Antigravity chat:

| Slash Command                  | What It Does                                                  |
| ------------------------------ | ------------------------------------------------------------- |
| `/apply-otel-instrumentation`  | Install OTel Operator + inject auto-instrumentation into pods |
| `/remove-otel-instrumentation` | Strip instrumentation annotations + delete Instrumentation CR |
| `/switch-otel-config`          | Switch OTel Collector between `initial` and `demo` profiles   |
| `/cluster-health-check`        | Full cluster health report + active OTel backend status       |

Skills are defined in `.agents/skills/` and workflows in `.agents/workflows/`.

---

### VS Code Copilot Chat (GitHub Copilot)

> **Requires**: VS Code 1.99+ with GitHub Copilot extension enabled.

Four prompt files are available in `.github/prompts/`. Use them in Copilot Chat:

#### 🤖 Agent Skills — Plain English (Recommended)

Four **Agent Skills** are defined in `.github/skills/`. Copilot reads each skill's `name` and `description` to automatically pick the right skill from your plain-English request — no slash commands needed.

**Just ask in plain English in Copilot Chat (Agent mode):**

| What you say (example)                             | Skill that gets selected      |
| -------------------------------------------------- | ----------------------------- |
| "apply otel instrumentation to my apps"            | `apply-otel-instrumentation`  |
| "remove otel from the cluster"                     | `remove-otel-instrumentation` |
| "check cluster health / how many services running" | `cluster-health-check`        |
| "switch to demo otel config"                       | `switch-otel-config`          |

Copilot matches your intent to the right `SKILL.md`, understands the steps, and executes them in the terminal — same experience as Antigravity.

#### 📎 Prompt Files — Manual Attach (Alternative)

If you prefer explicit control, four prompt files are in `.github/prompts/`:

1. Open Copilot Chat → click **📎** → **Prompt...** → select a file, or type `#` followed by the prompt filename.

> `.github/copilot-instructions.md` is loaded **automatically** by Copilot as workspace context — no action needed.

---

## 🔭 OTel Backend Profiles

| Profile     | Traces | Metrics         | Logs | Activate via               |
| ----------- | ------ | --------------- | ---- | -------------------------- |
| **initial** | Jaeger | VictoriaMetrics | —    | Default after stack deploy |
| **demo**    | Tempo  | Prometheus      | Loki | `/switch-otel-config demo` |

> All Grafana datasources (VictoriaMetrics, Jaeger, Prometheus, Tempo, Loki) are **pre-configured** — no manual setup required.

---

## 🌐 Accessing UIs

| Service               | URL                         |
| --------------------- | --------------------------- |
| **Grafana**           | http://localhost:80/grafana |
| **Jaeger**            | http://localhost:80/jaeger  |
| **App (via ingress)** | http://localhost:80/order   |

---

## 🎬 Demo Flow

1. **Baseline:** App running, observability stack up, no OTel instrumentation → Jaeger shows no traces.
2. **Add OTel live:** Use `/apply-otel-instrumentation` → Pods restart with injected Python SDK → Jaeger shows full distributed traces.
3. **Generate load:** Run `./run_k6.sh` → View live metrics in Grafana with Jaeger traces.
4. **Switch backends:** Use `/switch-otel-config demo` → OTel Collector routes to Prometheus + Tempo + Loki.
5. **Load test again:** Run `./run_k6.sh` → View end-to-end metrics in Prometheus/Grafana + Tempo traces + Loki logs.
6. **Clean up:** Use `/remove-otel-instrumentation` → Pods restart clean, no traces emitted.

---

## 📝 Notes

- The OTel Collector accepts OTLP on **gRPC port 4317** and **HTTP port 4318** inside the cluster.
- The OTel Operator requires **cert-manager** — the `apply-otel-instrumentation` skill installs it automatically.
- The `switch-otel-config` skill is idempotent — safe to run multiple times.
- k3d cluster name defaults to `cncf-hyd` (changeable in `observability/setup-cluster.sh`).
