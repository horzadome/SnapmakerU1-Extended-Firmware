#!/bin/bash
set -e

# Build the firmware in an ARM64 Ubuntu 24.04 container
# Trying to match GitHub Actions environment as closely as possible

# Change to project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$SCRIPT_DIR"

PROFILE="${1:-extended}"
OUTPUT_FILE="${2:-U1_${PROFILE}_upgrade.bin}"
BUILD_LOG="${SCRIPT_DIR}/build-$(date +%Y%m%d-%H%M%S).log"
IMAGE_NAME="snapmaker-u1-builder:arm64"

# Detect OS and architecture
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

# Normalize architecture names
case "$ARCH" in
    aarch64|arm64) ARCH="arm64" ;;
    *) 
        printf "Non-ARM64 architecture detected: %s\n" "$ARCH"
        ARCH="non-arm64"
        ;;
esac

printf "Detected OS: %s, Architecture: %s\n" "$OS" "$ARCH"

# Detect available containerization tool
CONTAINER_TOOL=""
NEEDS_EMULATION=false

if [ "$ARCH" != "arm64" ]; then
    NEEDS_EMULATION=true
    printf "Note: Running on non-ARM64 architecture, will need emulation/virtualization\n"
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to show unsupported platform message and exit
show_unsupported() {
    printf "\nThis script doesn't yet know how to build on this combination of OS/Arch/Tools.\n"
    printf "Please install one of these supported tools or improve this script and contribute it to fix the problem for others.\n\n"
    printf "Supported configurations:\n"
    printf "  - Linux (x86_64/ARM64): Podman or Docker with ARM64 support\n"
    printf "  - macOS: Apple's container tool, UTM, or Docker Desktop\n"
    printf "  - Windows: WSL2 with Podman or Docker\n\n"
    printf "See: https://github.com/paxx12/SnapmakerU1/blob/main/CONTRIBUTING.md\n"
    exit 1
}

# Function to check if tool supports ARM64
check_arm64_support() {
    local tool="$1"
    case "$tool" in
        podman)
            # Check if podman can run arm64 (via qemu or native)
            if podman run --rm --platform linux/arm64 alpine uname -m >/dev/null 2>&1; then
                return 0
            fi
            ;;
        docker)
            # Check if docker can run arm64 (via buildx/qemu or native)
            if docker run --rm --platform linux/arm64 alpine uname -m >/dev/null 2>&1; then
                return 0
            fi
            ;;
    esac
    return 1
}

# Detect containerization tool based on OS
case "$OS" in
    linux*)
        # Native Linux - prefer podman over docker
        if command_exists podman; then
            if [ "$NEEDS_EMULATION" = true ]; then
                if check_arm64_support podman; then
                    CONTAINER_TOOL="podman"
                fi
            else
                CONTAINER_TOOL="podman"
            fi
        fi
        
        # Fallback to docker if podman not available or doesn't support ARM64
        if [ -z "$CONTAINER_TOOL" ] && command_exists docker; then
            if [ "$NEEDS_EMULATION" = true ]; then
                if check_arm64_support docker; then
                    CONTAINER_TOOL="docker"
                fi
            else
                CONTAINER_TOOL="docker"
            fi
        fi
        ;;
    darwin*)
        # macOS
        if command_exists container; then
            # Apple's container tool
            CONTAINER_TOOL="container"
        elif command_exists docker && check_arm64_support docker; then
            # Docker Desktop for Mac
            CONTAINER_TOOL="docker"
        elif [ -d "/Applications/UTM.app" ]; then
            printf "UTM is installed but requires manual VM setup.\nPlease see: https://getutm.app/\n\nAlternatively, install Apple's container tool or Docker Desktop.\n"
            show_unsupported
        fi
        ;;
    msys*|mingw*|cygwin*)
        # Windows (not WSL) - WSL shows up as "linux" in uname
        # Check if we're in WSL by looking at /proc/version
        if grep -qi microsoft /proc/version 2>/dev/null || grep -qi wsl /proc/version 2>/dev/null; then
            printf "Running inside WSL\n"
            # In WSL, treat as Linux - check for podman or docker
            if command_exists podman; then
                if [ "$NEEDS_EMULATION" = true ]; then
                    if check_arm64_support podman; then
                        CONTAINER_TOOL="podman"
                    fi
                else
                    CONTAINER_TOOL="podman"
                fi
            fi
            
            if [ -z "$CONTAINER_TOOL" ] && command_exists docker; then
                if [ "$NEEDS_EMULATION" = true ]; then
                    if check_arm64_support docker; then
                        CONTAINER_TOOL="docker"
                    fi
                else
                    CONTAINER_TOOL="docker"
                fi
            fi
        else
            # Native Windows
            printf "Native Windows detected. Please use WSL2 for building.\n"
            show_unsupported
        fi
        ;;
    *)
        show_unsupported
        ;;
esac

# If no suitable tool found, provide instructions
if [ -z "$CONTAINER_TOOL" ]; then
    show_unsupported
fi

printf "Using containerization tool: %s\n\nBuilding firmware...\nProfile: %s\nOutput: %s\nBuild log: %s\n" "$CONTAINER_TOOL" "$PROFILE" "$OUTPUT_FILE" "$BUILD_LOG"

# Build the builder container image if it doesn't exist
image_exists() {
    case "$CONTAINER_TOOL" in
        podman)
            podman image exists "$IMAGE_NAME"
            ;;
        docker)
            docker image inspect "$IMAGE_NAME" >/dev/null 2>&1
            ;;
        container)
            # Apple's container tool - check differently
            container list | grep -q "$IMAGE_NAME"
            ;;
    esac
}

if ! image_exists; then
    printf "\n==> Building builder image (one-time setup)...\n==> This will take a few minutes but only happens once...\n"
    
    case "$CONTAINER_TOOL" in
        podman)
            podman build --platform linux/arm64 -t "$IMAGE_NAME" -f "$SCRIPT_DIR/scripts/dev/Dockerfile.builder" "$SCRIPT_DIR"
            ;;
        docker)
            docker build --platform linux/arm64 -t "$IMAGE_NAME" -f "$SCRIPT_DIR/scripts/dev/Dockerfile.builder" "$SCRIPT_DIR"
            ;;
        container)
            printf "ERROR: Apple's container tool is not yet fully supported in this script.\n"
            show_unsupported
            ;;
    esac
    
    printf "==> Builder image ready!\n"
fi

printf "\n"
printf "==> Starting build...\n"

# Ensure cache directories exist on host
mkdir -p "$SCRIPT_DIR/firmware" "$SCRIPT_DIR/tmp"

# Run the build in the pre-built ARM64 builder image
run_container() {
    case "$CONTAINER_TOOL" in
        podman)
            podman run --rm -it \
                --platform linux/arm64 \
                -v "$SCRIPT_DIR:/workspace:Z" \
                -w /workspace \
                "$IMAGE_NAME" \
                bash -c "$1"
            ;;
        docker)
            docker run --rm -it \
                --platform linux/arm64 \
                -v "$SCRIPT_DIR:/workspace" \
                -w /workspace \
                "$IMAGE_NAME" \
                bash -c "$1"
            ;;
        container)
            printf "ERROR: Apple's container tool is not yet fully supported.\n"
            show_unsupported
            ;;
    esac
}

run_container "
    set -e
    printf '==> Downloading firmware if needed...\n'
    make firmware || true

    printf '==> Building firmware...\n'
    make build PROFILE=$PROFILE OUTPUT_FILE=$OUTPUT_FILE

    printf '==> Build complete!\n'
    ls -lh $OUTPUT_FILE
" 2>&1 | tee "$BUILD_LOG"

BUILD_STATUS=${PIPESTATUS[0]}

if [ "$BUILD_STATUS" -eq 0 ]; then
    printf "\nBuild complete! Output file: %s\nBuild log saved to: %s\n" "$OUTPUT_FILE" "$BUILD_LOG"
else
    printf "\nBuild failed! Check log: %s\n" "$BUILD_LOG"
    exit "$BUILD_STATUS"
fi
