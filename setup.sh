#!/usr/bin/env bash
# =============================================================================
# ComfyUI · AEON DGX Spark — interactive setup
# Walks the user through HF token, license accepts, variant choice, launch.
# =============================================================================
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
ENV_FILE=".env"
COMPOSE_FILE="docker-compose.yml"

# ── ANSI ────────────────────────────────────────────────────────────────────
B=$'\033[1m'  D=$'\033[0m'
G=$'\033[1;32m'  Y=$'\033[1;33m'  R=$'\033[1;31m'  C=$'\033[1;36m'

banner() {
cat <<EOF
${B}╔════════════════════════════════════════════════════════════════╗
║       ComfyUI · AEON DGX Spark — Interactive Setup             ║
╚════════════════════════════════════════════════════════════════╝${D}

This script walks you through:
    ${B}1.${D} Choosing local offline models or HuggingFace downloads
    ${B}2.${D} Picking your image variant and launch settings
    ${B}3.${D} Launching the stack

Press ${B}Ctrl-C${D} at any time to abort.

EOF
}

env_get() {
        local key="$1"
        grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | head -1 | \
            sed "s/^${key}=//;s/^\"//;s/\"$//;s/^'//;s/'$//"
}

prompt() {
    # $1 = prompt text, $2 = default
    local reply
    if [ -n "${2:-}" ]; then
        read -r -p "$1 [${2}] " reply
        echo "${reply:-$2}"
    else
        read -r -p "$1 " reply
        echo "$reply"
    fi
}

confirm() {
    # $1 = question, returns 0=yes, 1=no  (default Yes)
    local reply
    read -r -p "$1 [Y/n] " reply
    case "${reply:-Y}" in [Yy]*) return 0 ;; *) return 1 ;; esac
}

# ── Pre-flight ──────────────────────────────────────────────────────────────
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "${R}✗${D} $COMPOSE_FILE not found. Run this script from the repo root." >&2
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "${R}✗${D} docker not found in PATH. Install Docker first." >&2
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "${R}✗${D} docker compose plugin not found. Install Docker Compose plugin first." >&2
    exit 1
fi

if ! docker info 2>/dev/null | grep -q "Runtimes:.*nvidia"; then
    echo "${Y}⚠${D}  Docker doesn't have the nvidia runtime. The container will start but won't see the GPU."
    echo "   Install with: ${C}sudo apt install -y nvidia-container-toolkit && sudo systemctl restart docker${D}"
    if ! confirm "Continue anyway?"; then exit 1; fi
fi

banner

default_local_source="./modelscope"
existing_token="$(env_get HF_TOKEN)"
existing_use_local="$(env_get USE_LOCAL_MODELS)"
existing_local_source="$(env_get LOCAL_MODEL_SOURCE_HOST)"
[ -n "$existing_local_source" ] && default_local_source="$existing_local_source"

# Treat the placeholder from .env.example as "no token"
if [[ "$existing_token" == hf_xxxxxxxxxxxxx* ]]; then existing_token=""; fi

USE_LOCAL_MODELS="0"
LOCAL_MODEL_SOURCE_HOST="$default_local_source"

# ── Step 1: Model source ────────────────────────────────────────────────────
cat <<EOF

${C}━━━ Step 1: Model source ━━━${D}
  ${B}1) Local offline weights${D}  (use already-downloaded files from modelscope/; no HF token, no license clicks)
  ${B}2) HuggingFace downloads${D}  (original online flow)
EOF

if [ -d "$default_local_source" ]; then
    source_default="1"
    echo "${G}✓${D} Found local offline model root: ${C}$default_local_source${D}"
else
    source_default="2"
    echo "${Y}⚠${D}  Default offline model root not found: ${C}$default_local_source${D}"
fi

if [ "$existing_use_local" = "1" ]; then
    source_default="1"
fi

source_choice=$(prompt "Choice" "$source_default")
case "$source_choice" in
    1|offline|local|l|o)
        USE_LOCAL_MODELS="1"
        LOCAL_MODEL_SOURCE_HOST=$(prompt "Offline model root on the host" "$default_local_source")
        if [ ! -d "$LOCAL_MODEL_SOURCE_HOST" ]; then
            echo "${R}✗${D} Offline model root not found: ${C}$LOCAL_MODEL_SOURCE_HOST${D}" >&2
            exit 1
        fi
        echo "${G}✓${D} Offline mode enabled: ${C}$LOCAL_MODEL_SOURCE_HOST${D}"
        ;;
    *)
        USE_LOCAL_MODELS="0"
        echo "${G}✓${D} Using HuggingFace download flow"
        ;;
esac

token=""
if [ "$USE_LOCAL_MODELS" = "1" ]; then
    echo
    echo "${G}✓${D} HF token and gated-license steps will be skipped."
    echo "   The container will link existing offline weights into ${C}./workspace/models/${D} on startup."
elif [ -n "$existing_token" ]; then
    masked="${existing_token:0:8}…${existing_token: -4}"
    echo "${G}✓${D} Found existing HF_TOKEN in .env (${masked})"
    if confirm "Use this token?"; then
        token="$existing_token"
    fi
fi

if [ "$USE_LOCAL_MODELS" != "1" ] && [ -z "$token" ]; then
cat <<EOF

${C}━━━ Step 1A: HuggingFace token ━━━${D}
This is needed to download model weights from HuggingFace under your account.
Each model's license is accepted by *you* on HuggingFace; this image never
acts as a redistributor.

  ${B}1.${D} If you don't have a HuggingFace account, sign up:
       ${C}https://huggingface.co/join${D}

  ${B}2.${D} Open: ${C}https://huggingface.co/settings/tokens${D}
  ${B}3.${D} Click ${B}"+ Create new token"${D}
  ${B}4.${D} Set ${B}Token type: Read${D}
  ${B}5.${D} Name it (e.g. "${B}dgx-spark${D}") and click Create
  ${B}6.${D} Copy the token (looks like ${C}hf_AbCd1234...${D})

EOF
    while true; do
        # -s hides the input so the token doesn't echo to the terminal/scrollback
        read -r -s -p "Paste your HF token here (input hidden, press Enter): " token
        echo
        if [ -z "$token" ]; then
            echo "${Y}⚠${D}  No token entered."
            if confirm "Continue without a token (you'll need to use :slim variant)?"; then
                token=""; break
            fi
            continue
        fi
        if [[ "$token" =~ ^hf_[A-Za-z0-9_]{20,}$ ]]; then
            echo "${G}✓${D} Token format looks valid (${token:0:8}…${token: -4})"
            break
        fi
        echo "${R}✗${D} That doesn't look like an HF token (should start with ${B}hf_${D} and be 20+ chars). Try again."
    done
fi

# ── Step 2: Gated repos ─────────────────────────────────────────────────────
if [ "$USE_LOCAL_MODELS" != "1" ]; then
cat <<EOF

${C}━━━ Step 1B: Accept gated-model licenses ━━━${D}
Three Black Forest Labs repos require a one-time "Agree and access" click
under your HF account. Without this, those specific files return 403:

  ${B}1.${D} ${C}https://huggingface.co/black-forest-labs/FLUX.2-dev${D}
        (Flux 2 t2i — workflow 01)
  ${B}2.${D} ${C}https://huggingface.co/black-forest-labs/FLUX.2-klein-base-9b-fp8${D}
        (Flux 2 Klein 9B — workflow 08)
  ${B}3.${D} ${C}https://huggingface.co/black-forest-labs/FLUX.2-small-decoder${D}
        (Flux 2 VAE — workflows 01 + 08)

Open each URL → sign in → click ${B}"Agree and access repository"${D} → done.

(Other models — Mistral, Gemma, LTX 2.3, ACE-Step, Qwen — are not gated;
 your token can pull them right away.)

EOF
read -r -p "Have you accepted the licenses? [y/N/skip] " gated
case "${gated:-N}" in
    [Yy]*)  echo "${G}✓${D} OK — proceeding" ;;
    skip*)  echo "${Y}⚠${D}  Skipping — workflows 01 and 08 will fail to download until you accept" ;;
    *)      echo "${Y}⚠${D}  Not accepted yet — workflows 01 and 08 will 403. Accept later, then run:"
            echo "   ${C}rm workspace/.models_seeded && docker compose up -d --force-recreate${D}" ;;
esac
else
        echo
        echo "${C}━━━ Step 1B: Accept gated-model licenses ━━━${D}"
        echo "${G}✓${D} Skipped in offline mode"
fi

# ── Step 3: Image variant ───────────────────────────────────────────────────
cat <<EOF

${C}━━━ Step 3: Image variant ━━━${D}
    ${B}1) :latest${D}  (default — full image behavior)
    ${B}2) :slim${D}    (same runtime stack, no bundled first-start download expectation)

If offline mode is enabled, setup.sh will disable first-start downloading and
use your local weights regardless of the selected tag.
EOF

choice=$(prompt "Choice" "1")
case "$choice" in
    2|slim|s)   IMAGE_TAG="slim" ;;
    *)          IMAGE_TAG="latest" ;;
esac
echo "${G}✓${D} Selected: ${B}:${IMAGE_TAG}${D}"

# Warn if no token + :latest (won't be able to pull anything)
if [ "$USE_LOCAL_MODELS" != "1" ] && [ -z "$token" ] && [ "$IMAGE_TAG" = "latest" ]; then
    echo "${Y}⚠${D}  You picked :latest but didn't provide a token — auto-download will 401 on every file."
    if confirm "Switch to :slim instead?"; then IMAGE_TAG="slim"; fi
fi

# ── Step 4: Port + abliterated snapshot toggle ──────────────────────────────
echo
PORT=$(prompt "Port for the ComfyUI web UI" "8188")
SKIP_MODEL_DOWNLOAD="0"
SKIP_ABLITERATED="0"
if [ "$USE_LOCAL_MODELS" = "1" ]; then
    SKIP_MODEL_DOWNLOAD="1"
    SKIP_ABLITERATED="1"
    echo "${G}✓${D} Offline mode: first-start downloader disabled"
elif [ "$IMAGE_TAG" = "latest" ]; then
    if confirm "Skip the optional ~70 GB huihui-ai abliterated full-LLM snapshots?"; then
        SKIP_ABLITERATED="1"
    fi
fi

# ── Step 5: Write .env ──────────────────────────────────────────────────────
cat > "$ENV_FILE" <<EOF
# Generated by setup.sh on $(date -Iseconds)
HF_TOKEN=$token
COMFYUI_PORT=$PORT
IMAGE_TAG=$IMAGE_TAG
USE_LOCAL_MODELS=$USE_LOCAL_MODELS
LOCAL_MODEL_SOURCE_HOST=$LOCAL_MODEL_SOURCE_HOST
SKIP_MODEL_DOWNLOAD=$SKIP_MODEL_DOWNLOAD
SKIP_ABLITERATED=$SKIP_ABLITERATED
FORCE_MODEL_DOWNLOAD=0
EOF
chmod 600 "$ENV_FILE"
echo
echo "${G}✓${D} Wrote ${C}.env${D} (chmod 600)"
echo
if [ -n "$token" ]; then
    echo "    HF_TOKEN          = ${token:0:8}…${token: -4}"
else
    echo "    HF_TOKEN          = (empty)"
fi
echo "    COMFYUI_PORT      = $PORT"
echo "    IMAGE_TAG         = $IMAGE_TAG"
echo "    USE_LOCAL_MODELS  = $USE_LOCAL_MODELS"
echo "    LOCAL_MODEL_ROOT  = $LOCAL_MODEL_SOURCE_HOST"
echo "    SKIP_MODEL_DOWNLOAD = $SKIP_MODEL_DOWNLOAD"
echo "    SKIP_ABLITERATED  = $SKIP_ABLITERATED"

# ── Step 6: Launch ──────────────────────────────────────────────────────────
echo
if confirm "Pull image and launch the stack now?"; then
    echo
    echo "${C}▶${D} docker compose pull"
    docker compose pull
    echo
    echo "${C}▶${D} docker compose up -d"
    docker compose up -d

    HOST=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$HOST" ] && HOST="localhost"
    cat <<EOF

${G}╔════════════════════════════════════════════════════════════════╗
║  Stack started.                                                ║
╚════════════════════════════════════════════════════════════════╝${D}

Watch progress:    ${C}docker compose logs -f comfyui${D}

When you see ${B}'Launching ComfyUI on port $PORT'${D} (and on :latest, after
the model download finishes), open the UI at:
    ${C}http://$HOST:$PORT${D}

Offline mode note:
    - If ${B}USE_LOCAL_MODELS=1${D}, the container links files from
        ${C}${LOCAL_MODEL_SOURCE_HOST}${D} into ${C}./workspace/models/${D}.
    - No HuggingFace token or gated-license flow is used.

Workflow tips:
  - ${B}01_flux2_text_to_image${D}            — Flux 2 image gen (smallest, fastest)
  - ${B}02_ltx2.3_T2V_I2V_distilled${D}       — LTX 2.3 video, abliterated Gemma
  - ${B}09_acestep_ancient_sufi_xl${D}        — ACE-Step audio + Ollama prompt expansion

If a workflow says "missing models" — click ${B}Install Missing Models${D} in
the UI top bar.  Downloads land server-side in ${C}./workspace/models/${D},
never on the client browser (great for remote-accessed Sparks).

EOF
else
    echo
    echo "Launch later with: ${C}docker compose up -d${D}"
fi
