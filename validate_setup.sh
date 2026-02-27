#!/bin/bash
# validate_setup.sh — CNCF Hyd OTel Demo: Environment Prerequisite Checker
# Run before starting the demo. Hyderabadi edition 🌶️

# NOTE: No `set -e` — we want the script to continue even when checks fail
set -uo pipefail

# ─── Colour helpers ───────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

PASS=0
FAIL=0
WARN=0

MISSING_TOOLS=()
WARN_TOOLS=()

pass()  { echo -e "  ${GREEN}✅ Arre wah! ${RESET} $1"; PASS=$((PASS + 1)); }
fail()  { echo -e "  ${RED}❌ Kya hua bhai! ${RESET} $1"; FAIL=$((FAIL + 1)); }
warn()  { echo -e "  ${YELLOW}⚠️  Theek hai but... ${RESET} $1"; WARN=$((WARN + 1)); }
header(){ echo -e "\n${BOLD}${CYAN}━━━ $1 ━━━${RESET}"; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║   CNCF Hyd — OTel Demo: Environment Validator           ║${RESET}"
echo -e "${BOLD}║   Bhai, pehle ye check karo phir aage badho! 🌶️          ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"

# ─── 1. Operating System ──────────────────────────────────────────────────────
header "Operating System"
OS="$(uname -s)"
case "$OS" in
    Darwin)
        pass "macOS milgaya bhai! ($(sw_vers -productVersion 2>/dev/null || echo 'unknown'))"
        PKG_MANAGER="brew"
        ;;
    Linux)
        pass "Linux hai bhai! ($(uname -r))"
        PKG_MANAGER="apt"
        ;;
    *)
        fail "Ye kaunsa OS hai bhai: $OS — macOS ya Linux chahiye (WSL2 bhi chalega)."
        PKG_MANAGER="unknown"
        ;;
esac

# ─── 2. Docker ────────────────────────────────────────────────────────────────
header "Docker"
if command -v docker &>/dev/null; then
    DOCKER_VER=$(docker version --format '{{.Client.Version}}' 2>/dev/null | sed 's/[^0-9.]//g')
    DOCKER_MAJOR=$(echo "$DOCKER_VER" | cut -d. -f1)
    if [[ -n "$DOCKER_VER" ]] && [[ "$DOCKER_MAJOR" -ge 20 ]]; then
        pass "Docker mil gaya! v$DOCKER_VER — ekdum ready hai bhai"
    else
        fail "Docker purana hai yaar: '$DOCKER_VER' — v20+ chahiye"
        MISSING_TOOLS+=("docker")
    fi

    if docker info &>/dev/null 2>&1; then
        pass "Docker daemon chal raha hai — ekdum fit!"
    else
        fail "Docker daemon soya hua hai! Pehle Docker Desktop start karo bhai."
        MISSING_TOOLS+=("docker-daemon")
    fi
else
    fail "Docker toh mila hi nahi bhai! Install karo pehle."
    MISSING_TOOLS+=("docker")
fi

# ─── 3. k3d ───────────────────────────────────────────────────────────────────
header "k3d (Kubernetes-in-Docker)"
if command -v k3d &>/dev/null; then
    K3D_VER=$(k3d version 2>/dev/null | grep 'k3d version' | sed 's/[^0-9.]//g' | head -1)
    K3D_MAJOR=$(echo "$K3D_VER" | cut -d. -f1)
    if [[ -n "$K3D_VER" ]] && [[ "$K3D_MAJOR" -ge 5 ]]; then
        pass "k3d mila — v$K3D_VER — mazedaar! Cluster banate hai ab!"
    else
        fail "k3d purana hai yaar: v$K3D_VER — v5+ chahiye"
        MISSING_TOOLS+=("k3d")
    fi
else
    fail "k3d nahi mila bhai! Bina iske cluster kaise banayenge? Install karo."
    MISSING_TOOLS+=("k3d")
fi

# ─── 4. kubectl ───────────────────────────────────────────────────────────────
header "kubectl"
if command -v kubectl &>/dev/null; then
    KUBECTL_VER=$(kubectl version --client -o json 2>/dev/null | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d['clientVersion']['gitVersion'].lstrip('v'))" 2>/dev/null || \
        kubectl version --client --short 2>/dev/null | sed 's/[^0-9.]//g' | head -1 || echo "")
    KUBECTL_MINOR=$(echo "$KUBECTL_VER" | cut -d. -f2)
    if [[ -n "$KUBECTL_VER" ]] && [[ "${KUBECTL_MINOR:-0}" -ge 24 ]]; then
        pass "kubectl ekdum badhiya! v$KUBECTL_VER — chalo pods dekho!"
    else
        warn "kubectl thoda purana lag raha hai: '$KUBECTL_VER' — v1.24+ recommend karenge"
        WARN_TOOLS+=("kubectl")
    fi
else
    fail "kubectl nahi mila bhai! Kubernetes kaise chalega bina iske?"
    MISSING_TOOLS+=("kubectl")
fi

# ─── 5. Helm ──────────────────────────────────────────────────────────────────
header "Helm"
if command -v helm &>/dev/null; then
    HELM_VER=$(helm version --short 2>/dev/null | sed 's/[^0-9.]//g' | head -1)
    HELM_MAJOR=$(echo "$HELM_VER" | cut -d. -f1)
    if [[ -n "$HELM_VER" ]] && [[ "$HELM_MAJOR" -ge 3 ]]; then
        pass "Helm ready hai bhai! v$HELM_VER — OTel Operator install hoga pakka!"
    else
        fail "Helm ka version chhota hai: v$HELM_VER — v3+ chahiye ustaad"
        MISSING_TOOLS+=("helm")
    fi
else
    fail "Helm nahi mila! OTel Operator kaise install karein bhai?"
    MISSING_TOOLS+=("helm")
fi

# ─── 6. k6 ────────────────────────────────────────────────────────────────────
header "k6 (Load Testing)"
if command -v k6 &>/dev/null; then
    K6_VER=$(k6 version 2>/dev/null | sed 's/[^0-9.]//g' | head -1)
    pass "k6 hai — v$K6_VER — load test ready! Biryani order flooding shuru?"
else
    fail "k6 nahi mila bhai! Load test kaise karein? Traffic kaun dega?"
    MISSING_TOOLS+=("k6")
fi

# ─── 7. Python 3 ──────────────────────────────────────────────────────────────
header "Python 3"
if command -v python3 &>/dev/null; then
    PY_VER=$(python3 --version 2>&1 | sed 's/[^0-9.]//g')
    PY_MINOR=$(echo "$PY_VER" | cut -d. -f2)
    if [[ "${PY_MINOR:-0}" -ge 10 ]]; then
        pass "Python v$PY_VER — arre wah! Services chalenge seedha!"
    else
        warn "Python v$PY_VER — thoda purana hai. v3.10+ better rahega bhai."
        WARN_TOOLS+=("python3")
    fi
else
    fail "Python3 nahi mila! FastAPI services kaise chalayenge bhai?"
    MISSING_TOOLS+=("python3")
fi

if command -v pip3 &>/dev/null || command -v pip &>/dev/null; then
    pass "pip bhi hai — dependencies install ho sakti hai!"
else
    warn "pip nahi mila — thoda dekho, Python ke saath aana chahiye tha."
    WARN_TOOLS+=("pip")
fi

# ─── 8. curl ──────────────────────────────────────────────────────────────────
header "curl"
if command -v curl &>/dev/null; then
    CURL_VER=$(curl --version 2>/dev/null | head -1 | awk '{print $2}')
    pass "curl hai bhai! v$CURL_VER — health checks chalte rahenge!"
else
    fail "curl nahi mila! Bhai ye toh bohot zaroori tha."
    MISSING_TOOLS+=("curl")
fi

# ─── 9. jq (optional) ────────────────────────────────────────────────────────
header "jq (optional — JSON pretty printing)"
if command -v jq &>/dev/null; then
    JQ_VER=$(jq --version 2>/dev/null)
    pass "jq bhi hai — $JQ_VER — ekdum mast, JSON seedha padh jayega!"
else
    warn "jq nahi hai — optional hai bhai, but install kar lo theek rahega."
    WARN_TOOLS+=("jq")
fi

# ─── 10. Port 80 ──────────────────────────────────────────────────────────────
header "Port 80 Availability"
if lsof -iTCP:80 -sTCP:LISTEN &>/dev/null 2>&1; then
    PORT80_PROC=$(lsof -iTCP:80 -sTCP:LISTEN 2>/dev/null | awk 'NR==2{print $1}')
    PORT80_PID=$(lsof -iTCP:80 -sTCP:LISTEN 2>/dev/null | awk 'NR==2{print $2}')
    warn "Port 80 kisi ne pakad rakha hai: $PORT80_PROC (PID $PORT80_PID) — k3d ingress ke liye — theek hai, fix karo!"
    WARN_TOOLS+=("port-80")
    echo ""
    echo -e "  ${BOLD}${CYAN}Kya karna hai? 2 options hain:${RESET}"
    echo ""
    if echo "$PORT80_PROC" | grep -qi "docker\|com.docke"; then
        echo -e "  ${YELLOW}ℹ️  Docker Desktop port 80 use kar raha hai.${RESET}"
        echo -e "  ${YELLOW}   Docker Desktop → Settings → General:${RESET}"
        echo -e "  ${YELLOW}   'Enable host networking' ya 'Use port 80' option off karo.${RESET}"
        echo ""
    fi
    echo -e "  ${GREEN}Option A${RESET} — Port 80 free karo ${BOLD}(recommended)${RESET}:"
    echo -e "    ${YELLOW}sudo kill -9 $PORT80_PID${RESET}     # $PORT80_PROC hatao"
    echo -e "    ${YELLOW}bash validate_setup.sh${RESET}        # dobara check karo"
    echo ""
    echo -e "  ${GREEN}Option B${RESET} — Port 8080 use karo ${BOLD}(agar 80 nahi chhoot raha)${RESET}:"
    echo -e "  ${CYAN}  Change 1 — observability/setup-cluster.sh (line 5):${RESET}"
    echo -e "    ${RED}- PORT=\"80\"${RESET}"
    echo -e "    ${GREEN}+ PORT=\"8080\"${RESET}"
    echo ""
    echo -e "  ${CYAN}  Change 2 — validate_setup.sh (line 180):${RESET}"
    echo -e "    ${RED}- if lsof -iTCP:80 -sTCP:LISTEN${RESET}"
    echo -e "    ${GREEN}+ if lsof -iTCP:8080 -sTCP:LISTEN${RESET}"
    echo ""
    echo -e "  ${YELLOW}  Note: Option B ke baad URLs http://localhost:8080 se chalenge.${RESET}"
    echo ""
else
    pass "Port 80 free hai bhai — k3d ingress aaram se lagega!"
fi

# ─── 11. Disk Space ───────────────────────────────────────────────────────────
header "Disk Space"
if command -v df &>/dev/null; then
    if [[ "$OS" == "Darwin" ]]; then
        FREE_GB=$(df -g / 2>/dev/null | awk 'NR==2{print $4}')
    else
        FREE_GB=$(df -BG / 2>/dev/null | awk 'NR==2{gsub(/G/,"",$4); print $4}')
    fi
    if [[ "${FREE_GB:-0}" -ge 5 ]]; then
        pass "${FREE_GB} GB free — jai ho! Images ke liye kaafi jagah hai!"
    else
        warn "Sirf ${FREE_GB} GB free hai bhai — thoda aur chahiye (5 GB+). Docker images bhi nahi aayenge."
        WARN_TOOLS+=("disk-space")
    fi
fi

# ─── 12. Internet ─────────────────────────────────────────────────────────────
header "Internet Connectivity (Helm chart pulls)"
if curl -sf --max-time 5 https://helm.sh > /dev/null 2>&1; then
    pass "Internet chal raha hai — Helm charts download honge bhai!"
else
    warn "Internet nahi lag raha — Helm charts pull nahi honge. Network check karo ustaad."
    WARN_TOOLS+=("internet")
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║                  Validation Summary                     ║${RESET}"
echo -e "${BOLD}╠══════════════════════════════════════════════════════════╣${RESET}"
printf  "  ${GREEN}✅ Arre wah (Passed)${RESET}:    %d checks\n" "$PASS"
printf  "  ${YELLOW}⚠️  Theek hai but (Warn)${RESET}: %d checks\n" "$WARN"
printf  "  ${RED}❌ Kya hua (Failed)${RESET}:   %d checks\n" "$FAIL"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"

# ─── Install guidance (only for missing/warned tools) ─────────────────────────
print_macos_instructions() {
    # Only show Homebrew header if a brew-installable tool needs attention
    local brew_tools=(docker k3d kubectl helm k6 python3 pip curl jq)
    local needs_brew=false
    for t in "${MISSING_TOOLS[@]+${MISSING_TOOLS[@]}}" "${WARN_TOOLS[@]+${WARN_TOOLS[@]}}"; do
        for bt in "${brew_tools[@]}"; do
            [[ "$t" == "$bt" ]] && needs_brew=true && break 2
        done
    done
    if $needs_brew; then
        echo -e "\n${BOLD}${CYAN}━━━ 🍎 macOS — Ye tools install karo bhai ━━━${RESET}"
        echo -e "  ${CYAN}Homebrew use karo — macOS ka best package manager:${RESET}"
        echo -e "  ${YELLOW}/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${RESET}\n"
    fi

    for tool in "${MISSING_TOOLS[@]+${MISSING_TOOLS[@]}}" "${WARN_TOOLS[@]+${WARN_TOOLS[@]}}"; do
        case "$tool" in
            docker)
                echo -e "  ${RED}▸ Docker${RESET}"
                echo -e "    Option A (recommended — Docker Desktop with GUI):"
                echo -e "    ${YELLOW}https://www.docker.com/products/docker-desktop/${RESET}"
                echo -e "    Option B (CLI only):"
                echo -e "    ${YELLOW}brew install --cask docker${RESET}\n"
                ;;
            docker-daemon)
                echo -e "  ${RED}▸ Docker Daemon chhod ke gaya hai${RESET}"
                echo -e "    Docker Desktop open karo:"
                echo -e "    ${YELLOW}open -a Docker${RESET}\n"
                ;;
            k3d)
                echo -e "  ${RED}▸ k3d${RESET}"
                echo -e "    ${YELLOW}brew install k3d${RESET}"
                echo -e "    Ya phir: ${YELLOW}curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash${RESET}\n"
                ;;
            kubectl)
                echo -e "  ${YELLOW}▸ kubectl${RESET}"
                echo -e "    ${YELLOW}brew install kubectl${RESET}\n"
                ;;
            helm)
                echo -e "  ${RED}▸ Helm${RESET}"
                echo -e "    ${YELLOW}brew install helm${RESET}\n"
                ;;
            k6)
                echo -e "  ${RED}▸ k6${RESET}"
                echo -e "    ${YELLOW}brew install k6${RESET}"
                echo -e "    Ya: ${YELLOW}https://grafana.com/docs/k6/latest/set-up/install-k6/${RESET}\n"
                ;;
            python3)
                echo -e "  ${YELLOW}▸ Python 3${RESET}"
                echo -e "    ${YELLOW}brew install python@3.11${RESET}"
                echo -e "    Ya: ${YELLOW}https://www.python.org/downloads/macos/${RESET}\n"
                ;;
            pip)
                echo -e "  ${YELLOW}▸ pip${RESET}"
                echo -e "    ${YELLOW}python3 -m ensurepip --upgrade${RESET}\n"
                ;;
            curl)
                echo -e "  ${RED}▸ curl${RESET}"
                echo -e "    ${YELLOW}brew install curl${RESET}\n"
                ;;
            jq)
                echo -e "  ${YELLOW}▸ jq (optional)${RESET}"
                echo -e "    ${YELLOW}brew install jq${RESET}\n"
                ;;
            port-80)
                echo -e "  ${RED}▸ Port 80 occupied hai — 2 options hain bhai:${RESET}\n"
                echo -e "  ${BOLD}Option A — Port 80 free karo (recommended):${RESET}"
                echo -e "    ${YELLOW}sudo lsof -iTCP:80 -sTCP:LISTEN${RESET}   # kaun hai dekho"
                echo -e "    ${YELLOW}sudo kill -9 <PID>${RESET}                # usko hatao"
                echo -e "    ${YELLOW}bash validate_setup.sh${RESET}            # dobara check karo\n"
                echo -e "  ${BOLD}Option B — Port 8080 use karo (agar 80 nahi chhoot raha):${RESET}"
                echo -e "  ${CYAN}Change 1 — observability/setup-cluster.sh (line 5):${RESET}"
                echo -e "    ${RED}- PORT=\"80\"${RESET}"
                echo -e "    ${GREEN}+ PORT=\"8080\"${RESET}\n"
                echo -e "  ${CYAN}Change 2 — validate_setup.sh (lines 179-180):${RESET}"
                echo -e "    ${RED}- header \"Port 80 Availability\"${RESET}"
                echo -e "    ${RED}- if lsof -iTCP:80 -sTCP:LISTEN ...${RESET}"
                echo -e "    ${GREEN}+ header \"Port 8080 Availability\"${RESET}"
                echo -e "    ${GREEN}+ if lsof -iTCP:8080 -sTCP:LISTEN ...${RESET}"
                echo -e "  ${YELLOW}Note: After this, URLs will be http://localhost:8080 instead of :80${RESET}\n"
                ;;
            disk-space)
                echo -e "  ${YELLOW}▸ Disk space khaali karo${RESET}"
                echo -e "    ${YELLOW}docker system prune -a${RESET}\n"
                ;;
            internet)
                echo -e "  ${YELLOW}▸ Internet check karo${RESET}"
                echo -e "    Network ya proxy settings dekho. Helm charts ke liye internet chahiye.\n"
                ;;
        esac
    done
}

print_linux_instructions() {
    echo -e "\n${BOLD}${CYAN}━━━ 🐧 Linux — Ye tools install karo bhai ━━━${RESET}"
    echo -e "  ${CYAN}Debian/Ubuntu (apt) ke commands hain. Apne distro ke hisaab se adjust karo.${RESET}\n"

    for tool in "${MISSING_TOOLS[@]+${MISSING_TOOLS[@]}}" "${WARN_TOOLS[@]+${WARN_TOOLS[@]}}"; do
        case "$tool" in
            docker)
                echo -e "  ${RED}▸ Docker${RESET}"
                echo -e "    ${YELLOW}curl -fsSL https://get.docker.com | sudo sh${RESET}"
                echo -e "    ${YELLOW}sudo usermod -aG docker \$USER && newgrp docker${RESET}\n"
                ;;
            docker-daemon)
                echo -e "  ${RED}▸ Docker Daemon start karo${RESET}"
                echo -e "    ${YELLOW}sudo systemctl start docker && sudo systemctl enable docker${RESET}\n"
                ;;
            k3d)
                echo -e "  ${RED}▸ k3d${RESET}"
                echo -e "    ${YELLOW}curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash${RESET}\n"
                ;;
            kubectl)
                echo -e "  ${YELLOW}▸ kubectl${RESET}"
                echo -e "    ${YELLOW}curl -LO https://dl.k8s.io/release/\$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl${RESET}"
                echo -e "    ${YELLOW}chmod +x kubectl && sudo mv kubectl /usr/local/bin/${RESET}\n"
                ;;
            helm)
                echo -e "  ${RED}▸ Helm${RESET}"
                echo -e "    ${YELLOW}curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash${RESET}\n"
                ;;
            k6)
                echo -e "  ${RED}▸ k6${RESET}"
                echo -e "    ${YELLOW}sudo apt-get install -y gnupg && curl -s https://dl.k6.io/key.gpg | sudo apt-key add -${RESET}"
                echo -e "    ${YELLOW}echo 'deb https://dl.k6.io/deb stable main' | sudo tee /etc/apt/sources.list.d/k6.list${RESET}"
                echo -e "    ${YELLOW}sudo apt-get update && sudo apt-get install k6${RESET}\n"
                ;;
            python3)
                echo -e "  ${YELLOW}▸ Python 3${RESET}"
                echo -e "    ${YELLOW}sudo apt-get install -y python3.11 python3.11-venv${RESET}\n"
                ;;
            pip)
                echo -e "  ${YELLOW}▸ pip${RESET}"
                echo -e "    ${YELLOW}sudo apt-get install -y python3-pip${RESET}\n"
                ;;
            curl)
                echo -e "  ${RED}▸ curl${RESET}"
                echo -e "    ${YELLOW}sudo apt-get install -y curl${RESET}\n"
                ;;
            jq)
                echo -e "  ${YELLOW}▸ jq (optional)${RESET}"
                echo -e "    ${YELLOW}sudo apt-get install -y jq${RESET}\n"
                ;;
            port-80)
                echo -e "  ${RED}▸ Port 80 occupied hai — 2 options hain bhai:${RESET}\n"
                echo -e "  ${BOLD}Option A — Port 80 free karo (recommended):${RESET}"
                echo -e "    ${YELLOW}sudo ss -tlnp | grep ':80'${RESET}         # kaun hai dekho"
                echo -e "    ${YELLOW}sudo kill -9 <PID>${RESET}                 # usko hatao"
                echo -e "    ${YELLOW}bash validate_setup.sh${RESET}             # dobara check karo\n"
                echo -e "  ${BOLD}Option B — Port 8080 use karo (agar 80 nahi chhoot raha):${RESET}"
                echo -e "  ${CYAN}Change 1 — observability/setup-cluster.sh (line 5):${RESET}"
                echo -e "    ${RED}- PORT=\"80\"${RESET}"
                echo -e "    ${GREEN}+ PORT=\"8080\"${RESET}\n"
                echo -e "  ${CYAN}Change 2 — validate_setup.sh (lines 179-180):${RESET}"
                echo -e "    ${RED}- header \"Port 80 Availability\"${RESET}"
                echo -e "    ${RED}- if lsof -iTCP:80 -sTCP:LISTEN ...${RESET}"
                echo -e "    ${GREEN}+ header \"Port 8080 Availability\"${RESET}"
                echo -e "    ${GREEN}+ if lsof -iTCP:8080 -sTCP:LISTEN ...${RESET}"
                echo -e "  ${YELLOW}Note: After this, URLs will be http://localhost:8080 instead of :80${RESET}\n"
                ;;
            disk-space)
                echo -e "  ${YELLOW}▸ Disk space badhao${RESET}"
                echo -e "    ${YELLOW}docker system prune -a${RESET}"
                echo -e "    ${YELLOW}sudo apt-get autoremove -y && sudo apt-get clean${RESET}\n"
                ;;
            internet)
                echo -e "  ${YELLOW}▸ Internet dekho bhai${RESET}"
                echo -e "    ${YELLOW}nslookup helm.sh${RESET}"
                echo -e "    Proxy ho toh: ${YELLOW}export https_proxy=http://your-proxy:port${RESET}\n"
                ;;
        esac
    done
}

# Print install guidance only if something needs attention
MISSING_COUNT=${#MISSING_TOOLS[@]:-0}
WARN_COUNT=${#WARN_TOOLS[@]:-0}
if [[ "$MISSING_COUNT" -gt 0 || "$WARN_COUNT" -gt 0 ]]; then
    if [[ "$OS" == "Darwin" ]]; then
        print_macos_instructions
    elif [[ "$OS" == "Linux" ]]; then
        print_linux_instructions
    fi
fi

# ─── Final verdict ────────────────────────────────────────────────────────────
echo ""
if [[ "$FAIL" -gt 0 ]]; then
    echo -e "${RED}${BOLD}Bhai, machine ready nahi hai abhi!${RESET} ❌ wale tools install karo pehle, phir:"
    echo -e "  ${CYAN}bash validate_setup.sh${RESET}"
    echo -e "\nKya hua? Fix karo aur wapis aao! 😤\n"
    exit 1
elif [[ "$WARN" -gt 0 ]]; then
    echo -e "${YELLOW}${BOLD}Chalne ka chance hai bhai,${RESET} but ⚠️  warnings dekh lo ek baar."
    echo -e "Demo mostly kaam karega — go for it! 🤞\n"
    exit 0
else
    echo -e "${GREEN}${BOLD}Arre bhai ARRE BHAI! Ekdum mast machine hai teri!${RESET} 🎉🌶️"
    echo -e "${GREEN}Sab kuch hai — Docker, k3d, kubectl, Helm, k6, Python — poora setup!${RESET}"
    echo -e "\n${BOLD}Ab seedha yahan ja:${RESET}"
    echo -e "  ${CYAN}cd observability && ./setup-cluster.sh${RESET}"
    echo -e "\n${BOLD}Demo start karo ustaad — biryani aur chai ka order aa raha hai! 🍛☕${RESET}\n"
    exit 0
fi
