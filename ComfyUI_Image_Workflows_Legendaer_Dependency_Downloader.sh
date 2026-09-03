#!/usr/bin/env bash

# ============================================================
# ComfyUI Workflow Dependency Installer
# Intended for Vast.ai / Linux
# ============================================================

set -Eeuo pipefail

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

COMFY="/workspace/ComfyUI"

CUSTOM_NODES="$COMFY/custom_nodes"
CHECKPOINTS="$COMFY/models/checkpoints"
VAE_SDXL="$COMFY/models/vae/SDXL"
CONTROLNET_SDXL="$COMFY/models/controlnet/SDXL"
UPSCALERS="$COMFY/models/upscale_models"
SAMS="$COMFY/models/sams"
BBOX="$COMFY/models/ultralytics/bbox"
SEGM="$COMFY/models/ultralytics/segm"


# ------------------------------------------------------------
# Error handling
# ------------------------------------------------------------

trap 'echo
echo "============================================================"
echo "ERROR: Installation failed on line $LINENO."
echo "============================================================"
exit 1' ERR


# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------

print_section() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}


# Clone a repository if it doesn't exist.
# If it already exists, try to update it instead.
clone_repo() {
    local repo="$1"
    local folder="$2"
    local destination="$CUSTOM_NODES/$folder"

    if [ -d "$destination/.git" ]; then
        echo
        echo "Updating: $folder"

        if ! git -C "$destination" pull --ff-only; then
            echo "WARNING: Could not update $folder."
            echo "Existing installation will be kept."
        fi
    else
        echo
        echo "Installing: $folder"
        git clone --depth=1 "$repo" "$destination"
    fi
}


# Download a file only if it doesn't already exist.
#
# Usage:
# download_file "filename" "URL"
download_file() {
    local filename="$1"
    local url="$2"

    if [ -f "$filename" ]; then
        echo
        echo "Already installed: $(basename "$filename")"
        echo "Skipping download."
        return 0
    fi

    echo
    echo "Downloading: $(basename "$filename")"

    # Download to temporary file first.
    # This prevents broken/partial downloads from being mistaken
    # for completed models.
    local temp_file="${filename}.part"

    rm -f "$temp_file"

    if wget \
        --tries=3 \
        --timeout=30 \
        --show-progress \
        -O "$temp_file" \
        "$url"
    then
        mv "$temp_file" "$filename"
        echo "Installed: $(basename "$filename")"
    else
        rm -f "$temp_file"
        echo "ERROR: Failed to download $(basename "$filename")"
        return 1
    fi
}


# Install requirements.txt for a custom node if it has one.
install_requirements() {
    local folder="$1"
    local destination="$CUSTOM_NODES/$folder"

    if [ -f "$destination/requirements.txt" ]; then
        echo
        echo "Installing Python requirements for: $folder"

        "$PYTHON" -m pip install \
            --disable-pip-version-check \
            -r "$destination/requirements.txt"
    fi
}


# ------------------------------------------------------------
# Check dependencies
# ------------------------------------------------------------

print_section "Checking system dependencies"

for command in git wget python3; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "ERROR: '$command' is not installed."
        exit 1
    fi
done

echo "git:     OK"
echo "wget:    OK"
echo "python3: OK"


# ------------------------------------------------------------
# Locate Python
# ------------------------------------------------------------

# Vast.ai installations differ slightly.
# Prefer ComfyUI's own virtual environment if one exists.

if [ -x "$COMFY/venv/bin/python" ]; then
    PYTHON="$COMFY/venv/bin/python"

elif [ -x "$COMFY/.venv/bin/python" ]; then
    PYTHON="$COMFY/.venv/bin/python"

else
    PYTHON="$(command -v python3)"
fi

echo
echo "Using Python:"
echo "$PYTHON"


# ------------------------------------------------------------
# CivitAI API token
# ------------------------------------------------------------

print_section "CivitAI authentication"

read -r -s -p "Enter your CivitAI API token: " CIVITAI_TOKEN
echo

if [ -z "$CIVITAI_TOKEN" ]; then
    echo "ERROR: No CivitAI API token was entered."
    exit 1
fi

echo "CivitAI token received."


# ------------------------------------------------------------
# Verify ComfyUI
# ------------------------------------------------------------

print_section "Checking ComfyUI"

if [ ! -d "$COMFY" ]; then
    echo "ERROR: ComfyUI directory does not exist:"
    echo "$COMFY"
    exit 1
fi

echo "ComfyUI found:"
echo "$COMFY"


# ------------------------------------------------------------
# Create required directories
# ------------------------------------------------------------

print_section "Creating model directories"

DIRECTORIES=(
    "$CUSTOM_NODES"
    "$CHECKPOINTS"
    "$VAE_SDXL"
    "$CONTROLNET_SDXL"
    "$UPSCALERS"
    "$SAMS"
    "$BBOX"
    "$SEGM"
)

for directory in "${DIRECTORIES[@]}"; do
    mkdir -p "$directory"
    echo "Ready: $directory"
done


# ============================================================
# CUSTOM NODES
# ============================================================

print_section "Installing custom nodes"

clone_repo \
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git" \
    "ComfyUI-Impact-Pack"

clone_repo \
    "https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git" \
    "ComfyUI-Impact-Subpack"

clone_repo \
    "https://github.com/yolain/ComfyUI-Easy-Use.git" \
    "ComfyUI-Easy-Use"

clone_repo \
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git" \
    "ComfyUI_UltimateSDUpscale"

clone_repo \
    "https://github.com/rgthree/rgthree-comfy.git" \
    "rgthree-comfy"

clone_repo \
    "https://github.com/alexopus/ComfyUI-Image-Saver.git" \
    "ComfyUI-Image-Saver"

clone_repo \
    "https://github.com/kijai/ComfyUI-KJNodes.git" \
    "ComfyUI-KJNodes"

clone_repo \
    "https://github.com/willmiao/ComfyUI-Lora-Manager.git" \
    "ComfyUI-Lora-Manager"


# ============================================================
# INSTALL CUSTOM NODE PYTHON REQUIREMENTS
# ============================================================

print_section "Installing custom-node Python requirements"

CUSTOM_NODE_FOLDERS=(
    "ComfyUI-Impact-Pack"
    "ComfyUI-Impact-Subpack"
    "ComfyUI-Easy-Use"
    "ComfyUI_UltimateSDUpscale"
    "rgthree-comfy"
    "ComfyUI-Image-Saver"
    "ComfyUI-KJNodes"
    "ComfyUI-Lora-Manager"
)

for node in "${CUSTOM_NODE_FOLDERS[@]}"; do
    install_requirements "$node"
done


# ============================================================
# CHECKPOINT
# ============================================================

print_section "Installing checkpoint"

download_file \
    "$CHECKPOINTS/civitai_checkpoint_2883731.safetensors" \
    "https://civitai.com/api/download/models/2883731?token=${CIVITAI_TOKEN}"


# ============================================================
# SDXL VAE
# ============================================================

print_section "Installing SDXL VAE"

download_file \
    "$VAE_SDXL/sdxl_vae.safetensors" \
    "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors?download=true"


# ============================================================
# SDXL CONTROLNET / CONTROL-LORA
# ============================================================

print_section "Installing SDXL Control-LoRAs"

download_file \
    "$CONTROLNET_SDXL/control-lora-canny-rank256.safetensors" \
    "https://huggingface.co/stabilityai/control-lora/resolve/main/control-LoRAs-rank256/control-lora-canny-rank256.safetensors?download=true"


download_file \
    "$CONTROLNET_SDXL/control-lora-depth-rank256.safetensors" \
    "https://huggingface.co/stabilityai/control-lora/resolve/main/control-LoRAs-rank256/control-lora-depth-rank256.safetensors?download=true"


# ============================================================
# UPSCALER
# ============================================================

print_section "Installing upscaler"

download_file \
    "$UPSCALERS/4x_foolhardy_Remacri.pth" \
    "https://huggingface.co/FacehugmanIII/4x_foolhardy_Remacri/resolve/main/4x_foolhardy_Remacri.pth?download=true"


# ============================================================
# SAM
# ============================================================

print_section "Installing SAM model"

# Impact Pack expects the actual SAM model checkpoint inside
# ComfyUI/models/sams, rather than the Segment Anything Git repo.

download_file \
    "$SAMS/sam_vit_b_01ec64.pth" \
    "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth"


# ============================================================
# ULTRALYTICS BBOX DETECTORS
# ============================================================

print_section "Installing BBOX detectors"

download_file \
    "$BBOX/hand_yolov9c.pt" \
    "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov9c.pt?download=true"


download_file \
    "$BBOX/face_yolov9c.pt" \
    "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov9c.pt?download=true"


download_file \
    "$BBOX/civitai_bbox_582143.pt" \
    "https://civitai.com/api/download/models/582143?fileId=497517&token=${CIVITAI_TOKEN}"


# ============================================================
# ULTRALYTICS SEGMENTATION MODELS
# ============================================================

print_section "Installing segmentation detectors"

download_file \
    "$SEGM/civitai_segm_2350456.pt" \
    "https://civitai.com/api/download/models/2350456?fileId=2240838&token=${CIVITAI_TOKEN}"


# ============================================================
# FINISHED
# ============================================================

print_section "Installation complete"

echo "All workflow dependencies have been installed."
echo
echo "ComfyUI:"
echo "  $COMFY"
echo
echo "Installed:"
echo "  - Custom nodes"
echo "  - Custom-node Python dependencies"
echo "  - Checkpoint"
echo "  - SDXL VAE"
echo "  - SDXL Control-LoRAs"
echo "  - Remacri upscaler"
echo "  - SAM model"
echo "  - YOLO BBOX detectors"
echo "  - Segmentation detector"
echo
echo "Restart ComfyUI before loading the workflow."
echo