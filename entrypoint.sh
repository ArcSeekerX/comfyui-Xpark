#!/usr/bin/env bash
# =============================================================================
# ComfyUI entrypoint — wires persistent volume, downloads models, launches UI.
# =============================================================================
set -euo pipefail

COMFY_HOME="${COMFY_HOME:-/opt/ComfyUI}"
WORKSPACE="${WORKSPACE:-/workspace/ComfyUI}"
PORT="${COMFYUI_PORT:-8188}"

# DGX Spark unified-memory friendly defaults (override with COMFYUI_FLAGS env)
DEFAULT_FLAGS="--listen 0.0.0.0 --port ${PORT} \
  --use-sage-attention \
  --bf16-unet --bf16-vae --bf16-text-enc \
  --disable-pinned-memory \
  --reserve-vram 2.0 \
  --preview-method auto \
  --enable-cors-header \
  --enable-manager \
  --enable-assets"
COMFYUI_FLAGS="${COMFYUI_FLAGS:-${DEFAULT_FLAGS}}"

log() { printf '\033[1;36m[entrypoint]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[entrypoint]\033[0m %s\n' "$*" >&2; }

seed_local_models() {
    local local_root="${LOCAL_MODEL_SOURCE:-}"
    local linked=0
    local missing_links=()
    local missing_workflows=()

    if [ "${USE_LOCAL_MODELS:-0}" != "1" ]; then
        return 0
    fi

    if [ -z "$local_root" ] || [ ! -d "$local_root" ]; then
        warn "USE_LOCAL_MODELS=1 but LOCAL_MODEL_SOURCE is unavailable: ${local_root:-<empty>}"
        return 0
    fi

    log "Linking offline models from ${local_root}"
    while IFS='|' read -r source_rel target_rel; do
        [ -n "$source_rel" ] || continue
        src="${local_root}/${source_rel}"
        dst="${WORKSPACE}/${target_rel}"
        if [ -e "$dst" ]; then
            continue
        fi
        if [ -f "$src" ]; then
            mkdir -p "$(dirname "$dst")"
            ln -snf "$src" "$dst"
            linked=$((linked + 1))
        else
            missing_links+=("${source_rel} -> ${target_rel}")
        fi
    done <<'EOF'
Comfy-Org/flux2-dev/split_files/diffusion_models/flux2_dev_fp8mixed.safetensors|models/diffusion_models/flux2_dev_fp8mixed.safetensors
Comfy-Org/flux2-dev/split_files/text_encoders/mistral_3_small_flux2_bf16.safetensors|models/text_encoders/mistral_3_small_flux2_bf16.safetensors
Comfy-Org/flux2-dev/split_files/text_encoders/mistral_3_small_flux2_fp4_mixed.safetensors|models/text_encoders/mistral_3_small_flux2_fp4_mixed.safetensors
Comfy-Org/flux2-dev/split_files/text_encoders/mistral_3_small_flux2_fp8.safetensors|models/text_encoders/mistral_3_small_flux2_fp8.safetensors
Comfy-Org/flux2-dev/split_files/loras/Flux_2-Turbo-LoRA_comfyui.safetensors|models/loras/Flux_2-Turbo-LoRA_comfyui.safetensors
Comfy-Org/flux2-dev/split_files/loras/Flux2TurboComfyv2.safetensors|models/loras/Flux2TurboComfyv2.safetensors
Comfy-Org/flux2-dev/split_files/vae/flux2-vae.safetensors|models/vae/flux2-vae.safetensors
black-forest-labs/FLUX.2-dev/ae.safetensors|models/vae/ae.safetensors
black-forest-labs/FLUX.2-small-decoder/full_encoder_small_decoder.safetensors|models/vae/full_encoder_small_decoder.safetensors
black-forest-labs/FLUX.2-dev/flux2-dev.safetensors|models/checkpoints/flux2-dev.safetensors
black-forest-labs/FLUX.2-klein-base-9b-fp8/flux-2-klein-base-9b-fp8.safetensors|models/diffusion_models/flux-2-klein-base-9b-fp8.safetensors
Comfy-Org/ltx-2/split_files/text_encoders/gemma_3_12B_it.safetensors|models/text_encoders/gemma_3_12B_it.safetensors
Comfy-Org/ltx-2/split_files/text_encoders/gemma_3_12B_it.safetensors|models/text_encoders/comfy_gemma_3_12B_it.safetensors
Comfy-Org/ltx-2/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors|models/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors
Comfy-Org/ltx-2/split_files/text_encoders/gemma_3_12B_it_fp8_scaled.safetensors|models/text_encoders/gemma_3_12B_it_fp8_scaled.safetensors
Comfy-Org/ltx-2/split_files/text_encoders/gemma_3_12B_it_fpmixed.safetensors|models/text_encoders/gemma_3_12B_it_fpmixed.safetensors
Comfy-Org/ltx-2/split_files/loras/gemma-3-12b-it-abliterated_lora_rank64_bf16.safetensors|models/loras/gemma-3-12b-it-abliterated_lora_rank64_bf16.safetensors
Comfy-Org/ltx-2/split_files/loras/gemma-3-12b-it-abliterated_heretic_lora_rank64_bf16.safetensors|models/loras/gemma-3-12b-it-abliterated_heretic_lora_rank64_bf16.safetensors
Comfy-Org/ltx-2/split_files/loras/ltx2-squish.safetensors|models/loras/ltx2-squish.safetensors
Lightricks/LTX-2.3-fp8/ltx-2.3-22b-dev-fp8.safetensors|models/checkpoints/ltx-2.3-22b-dev-fp8.safetensors
Lightricks/LTX-2.3-fp8/ltx-2.3-22b-distilled-fp8.safetensors|models/checkpoints/ltx-2.3-22b-distilled-fp8.safetensors
Lightricks/LTX-2.3/ltx-2.3-22b-dev.safetensors|models/checkpoints/ltx-2.3-22b-dev.safetensors
Lightricks/LTX-2.3/ltx-2.3-22b-distilled.safetensors|models/checkpoints/ltx-2.3-22b-distilled.safetensors
Lightricks/LTX-2.3/ltx-2.3-22b-distilled-1.1.safetensors|models/checkpoints/ltx-2.3-22b-distilled-1.1.safetensors
Lightricks/LTX-2.3/ltx-2.3-22b-distilled-lora-384.safetensors|models/loras/ltx-2.3-22b-distilled-lora-384.safetensors
Lightricks/LTX-2.3/ltx-2.3-22b-distilled-lora-384-1.1.safetensors|models/loras/ltx-2.3-22b-distilled-lora-384-1.1.safetensors
Lightricks/LTX-2.3/ltx-2.3-22b-distilled-lora-384-1.1.safetensors|models/loras/ltxv/ltx2/ltx-2.3-22b-distilled-lora-384-1.1.safetensors
Lightricks/LTX-2.3/ltx-2.3-spatial-upscaler-x1.5-1.0.safetensors|models/latent_upscale_models/ltx-2.3-spatial-upscaler-x1.5-1.0.safetensors
Lightricks/LTX-2.3/ltx-2.3-spatial-upscaler-x2-1.0.safetensors|models/latent_upscale_models/ltx-2.3-spatial-upscaler-x2-1.0.safetensors
Lightricks/LTX-2.3/ltx-2.3-spatial-upscaler-x2-1.1.safetensors|models/latent_upscale_models/ltx-2.3-spatial-upscaler-x2-1.1.safetensors
Lightricks/LTX-2.3/ltx-2.3-temporal-upscaler-x2-1.0.safetensors|models/latent_upscale_models/ltx-2.3-temporal-upscaler-x2-1.0.safetensors
Comfy-Org/ltx-2.3/split_files/loras/ltx-2.3-id-lora-talkvid-3k.safetensors|models/loras/ltx-2.3-id-lora-talkvid-3k.safetensors
Comfy-Org/ltx-2.3/split_files/loras/ltx-2.3-id-lora-celebvhq-3k.safetensors|models/loras/ltx-2.3-id-lora-celebvhq-3k.safetensors
Comfy-Org/ltx-2.3/split_files/loras/ltx_2.3_22b_distilled_1.1_lora_dynamic_fro09_avg_rank_111_bf16.safetensors|models/loras/ltx-2.3-22b-distilled-1.1_lora-dynamic_fro09_avg_rank_111_bf16.safetensors
EOF

    for workflow_path in \
        "models/vae/full_encoder_small_decoder.safetensors" \
        "models/text_encoders/qwen_3_8b_fp8mixed.safetensors" \
        "models/diffusion_models/acestep_v1.5_xl_turbo_bf16.safetensors" \
        "models/text_encoders/qwen_0.6b_ace15.safetensors" \
        "models/text_encoders/qwen_4b_ace15.safetensors" \
        "models/vae/ace_1.5_vae.safetensors" \
        "models/text_encoders/ltx-2.3_text_projection_bf16.safetensors" \
        "models/vae/LTX23_video_vae_bf16.safetensors" \
        "models/vae/LTX23_audio_vae_bf16.safetensors" \
        "models/diffusion_models/ltx-2.3-22b-distilled-1.1_transformer_only_fp8_scaled.safetensors"; do
        if [ ! -e "${WORKSPACE}/${workflow_path}" ]; then
            missing_workflows+=("${workflow_path}")
        fi
    done

    log "Offline model links ready: ${linked} linked"
    if [ "${#missing_links[@]}" -gt 0 ]; then
        warn "Some optional offline link sources were not found under ${local_root}:"
        printf '  - %s\n' "${missing_links[@]}" >&2
    fi
    if [ "${#missing_workflows[@]}" -gt 0 ]; then
        warn "Current offline tree does not cover every bundled workflow. Missing runtime files:"
        printf '  - %s\n' "${missing_workflows[@]}" >&2
    fi
}

log "ComfyUI for DGX Spark (sm_121a, CUDA 13)"
log "Python : $(python --version 2>&1)"
log "Torch  : $(python -c 'import torch; print(torch.__version__, "cuda", torch.version.cuda)')"
log "Arches : $(python -c 'import torch; print(torch.cuda.get_arch_list())')"
log "GPU    : $(python -c 'import torch; print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else "none")')"
log "Sage   : $(python -c "import sageattention,inspect; v=getattr(sageattention,'__version__',None); print(v or ('installed @ '+inspect.getfile(sageattention)))" 2>/dev/null || echo 'unavailable')"
log "Manager: $(python -c "import comfyui_manager; print('pip pkg present @ ' + comfyui_manager.__file__)" 2>/dev/null || echo 'pip pkg missing')"

# -----------------------------------------------------------------------------
# 1. Bootstrap persistent workspace volume
# -----------------------------------------------------------------------------
log "Bootstrapping workspace at ${WORKSPACE}"
mkdir -p "${WORKSPACE}"/{models,custom_nodes,output,input,user/default/workflows,temp,.cache/huggingface}
mkdir -p "${WORKSPACE}"/models/{diffusion_models,text_encoders,vae,loras,clip,clip_vision,controlnet,upscale_models,latent_upscale_models,embeddings,unet,checkpoints,style_models,gligen,hypernetworks,configs,photomaker,sams,ipadapter,inpaint,facerestore_models,facedetection,insightface}

# Symlink ComfyUI's data dirs to the persistent volume
for d in models custom_nodes output input user temp; do
    if [ -e "${COMFY_HOME}/${d}" ] && [ ! -L "${COMFY_HOME}/${d}" ]; then
        # Move any pre-existing content into the volume on first start
        if [ -d "${COMFY_HOME}/${d}" ] && [ -z "$(ls -A "${COMFY_HOME}/${d}" 2>/dev/null)" ]; then
            rm -rf "${COMFY_HOME}/${d}"
        else
            log "Migrating existing ${COMFY_HOME}/${d} into volume"
            rsync -a "${COMFY_HOME}/${d}/" "${WORKSPACE}/${d}/" 2>/dev/null || true
            rm -rf "${COMFY_HOME}/${d}"
        fi
    fi
    ln -snf "${WORKSPACE}/${d}" "${COMFY_HOME}/${d}"
done

# -----------------------------------------------------------------------------
# 2. Seed bundled custom nodes into the persistent volume (idempotent)
#    — only copies a node if its target directory does not exist yet, so users
#      can delete/replace nodes without them being re-added on every start.
# -----------------------------------------------------------------------------
if [ -d /opt/bundled_custom_nodes ]; then
    for src in /opt/bundled_custom_nodes/*/; do
        node_name="$(basename "${src}")"
        dst="${WORKSPACE}/custom_nodes/${node_name}"
        if [ ! -e "${dst}" ]; then
            log "Seeding custom node: ${node_name}"
            cp -a "${src}" "${dst}"
        fi
    done
fi

# -----------------------------------------------------------------------------
# 3. Install requirements.txt from any custom node (idempotent — fast no-op
#    after first start because pip caches resolved markers).
# -----------------------------------------------------------------------------
log "Installing requirements from custom nodes"
for req in "${WORKSPACE}"/custom_nodes/*/requirements.txt; do
    [ -f "${req}" ] || continue
    log "  -> $(dirname "${req}" | xargs basename)"
    pip install -q --no-deps -r "${req}" 2>/dev/null || \
      pip install -q -r "${req}" 2>/dev/null || \
      warn "  partial failure installing ${req}"
done

# -----------------------------------------------------------------------------
# 4. Seed default workflows
# -----------------------------------------------------------------------------
if [ -d /opt/default_workflows ]; then
    for wf in /opt/default_workflows/*.json; do
        [ -f "${wf}" ] || continue
        wf_name="$(basename "${wf}")"
        dst="${WORKSPACE}/user/default/workflows/${wf_name}"
        if [ ! -e "${dst}" ]; then
            log "Seeding workflow: ${wf_name}"
            mkdir -p "$(dirname "${dst}")"
            cp -a "${wf}" "${dst}"
        fi
    done
fi

# -----------------------------------------------------------------------------
# 5. Link pre-downloaded offline models into the persistent workspace.
#    This avoids copying large weight files and keeps the original modelscope/
#    tree as the source of truth.
# -----------------------------------------------------------------------------
seed_local_models

# -----------------------------------------------------------------------------
# 6. Download models — only on first start, or when explicitly forced.
#    Skip with SKIP_MODEL_DOWNLOAD=1, force with FORCE_MODEL_DOWNLOAD=1.
# -----------------------------------------------------------------------------
SENTINEL="${WORKSPACE}/.models_seeded"
if [ "${SKIP_MODEL_DOWNLOAD:-0}" = "1" ]; then
    log "SKIP_MODEL_DOWNLOAD=1 — skipping model fetch"
elif [ -f "${SENTINEL}" ] && [ "${FORCE_MODEL_DOWNLOAD:-0}" != "1" ]; then
    log "Models already seeded (delete ${SENTINEL} or set FORCE_MODEL_DOWNLOAD=1 to re-fetch)"
else
    log "Downloading models — this can take a while on first start..."
    if python /usr/local/bin/download_models.py --workspace "${WORKSPACE}"; then
        touch "${SENTINEL}"
        log "Model fetch complete"
    else
        warn "Model fetch reported errors; ComfyUI will still start. See log above."
    fi
fi

# -----------------------------------------------------------------------------
# 7. Launch ComfyUI
# -----------------------------------------------------------------------------
log "Launching ComfyUI on port ${PORT}"
log "Flags: ${COMFYUI_FLAGS}"
cd "${COMFY_HOME}"
exec python main.py ${COMFYUI_FLAGS}
