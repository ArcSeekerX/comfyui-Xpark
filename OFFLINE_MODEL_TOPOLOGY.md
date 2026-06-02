# Offline Weight Directory Topology

This repository supports an offline model root mounted from `LOCAL_MODEL_SOURCE_HOST`.
The current expected host-side layout is:

```text
modelscope/
├── black-forest-labs/
│   ├── FLUX.2-dev/
│   │   ├── ae.safetensors
│   │   └── flux2-dev.safetensors
│   ├── FLUX.2-klein-base-9b-fp8/
│   │   └── flux-2-klein-base-9b-fp8.safetensors
│   └── FLUX.2-small-decoder/
│       └── full_encoder_small_decoder.safetensors
├── Comfy-Org/
│   ├── flux2-dev/
│   │   └── split_files/
│   │       ├── diffusion_models/
│   │       │   └── flux2_dev_fp8mixed.safetensors
│   │       ├── loras/
│   │       │   ├── Flux2TurboComfyv2.safetensors
│   │       │   └── Flux_2-Turbo-LoRA_comfyui.safetensors
│   │       ├── text_encoders/
│   │       │   ├── mistral_3_small_flux2_bf16.safetensors
│   │       │   ├── mistral_3_small_flux2_fp4_mixed.safetensors
│   │       │   └── mistral_3_small_flux2_fp8.safetensors
│   │       └── vae/
│   │           └── flux2-vae.safetensors
│   └── ltx-2/
│       └── split_files/
│           ├── loras/
│           │   ├── gemma-3-12b-it-abliterated_heretic_lora_rank64_bf16.safetensors
│           │   ├── gemma-3-12b-it-abliterated_lora_rank64_bf16.safetensors
│           │   └── ltx2-squish.safetensors
│           └── text_encoders/
│               ├── gemma_3_12B_it.safetensors
│               ├── gemma_3_12B_it_fp4_mixed.safetensors
│               ├── gemma_3_12B_it_fp8_scaled.safetensors
│               └── gemma_3_12B_it_fpmixed.safetensors
└── Lightricks/
    ├── LTX-2.3/
    │   ├── ltx-2.3-22b-dev.safetensors
    │   ├── ltx-2.3-22b-distilled-1.1.safetensors
    │   ├── ltx-2.3-22b-distilled-lora-384-1.1.safetensors
    │   ├── ltx-2.3-22b-distilled-lora-384.safetensors
    │   ├── ltx-2.3-22b-distilled.safetensors
    │   ├── ltx-2.3-spatial-upscaler-x1.5-1.0.safetensors
    │   ├── ltx-2.3-spatial-upscaler-x2-1.0.safetensors
    │   ├── ltx-2.3-spatial-upscaler-x2-1.1.safetensors
    │   └── ltx-2.3-temporal-upscaler-x2-1.0.safetensors
    └── LTX-2.3-fp8/
        ├── ltx-2.3-22b-dev-fp8.safetensors
        └── ltx-2.3-22b-distilled-fp8.safetensors
