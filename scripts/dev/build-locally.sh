#!/bin/bash
set -e

# Build the firmware in an ARM64 Ubuntu 24.04 container
# Trying to match GitHub Actions environment as closely as possible

# Change to project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$SCRIPT_DIR"

# Get git branch name (sanitized for filename)
BRANCH_NAME="$(git rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's/[^a-zA-Z0-9._-]/_/g')"
# Get short timestamp (YYYYMMDD-HHMM format for human readability)
BUILD_TIMESTAMP="$(date +%Y%m%d-%H%M)"

PROFILE="${1:-extended}"
# Default output file includes branch name and timestamp
if [ -z "$2" ]; then
    OUTPUT_FILE="U1_${PROFILE}_${BRANCH_NAME}_${BUILD_TIMESTAMP}.bin"
else
    OUTPUT_FILE="$2"
fi
BUILD_LOG="${SCRIPT_DIR}/build-$(date +%Y%m%d-%H%M%S).log"
IMAGE_NAME="snapmaker-u1-builder:arm64"

# Logging function with timestamps - writes to both stdout and log file
log_with_timestamp() {
    local msg
    msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    printf "%s\n" "$msg" | tee -a "$BUILD_LOG"
}

# Detect OS and architecture
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

# Normalize architecture names
case "$ARCH" in
    aarch64|arm64) ARCH="arm64" ;;
    *) 
        log_with_timestamp "Non-ARM64 architecture detected: $ARCH"
        ARCH="non-arm64"
        ;;
esac

log_with_timestamp "Detected OS: $OS, Architecture: $ARCH"

# Detect available containerization tool
CONTAINER_TOOL=""
NEEDS_EMULATION=false

if [ "$ARCH" != "arm64" ]; then
    NEEDS_EMULATION=true
    log_with_timestamp "Note: Running on non-ARM64 architecture, will need emulation/virtualization"
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

log_with_timestamp "Using containerization tool: $CONTAINER_TOOL"
printf "\nBuilding firmware...\nProfile: %s\nOutput: %s\nBuild log: %s\n" "$PROFILE" "$OUTPUT_FILE" "$BUILD_LOG"

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
    printf "\n"
    log_with_timestamp "Building builder image (one-time setup)..."
    log_with_timestamp "This will take a few minutes but only happens once..."
    
    case "$CONTAINER_TOOL" in
        podman)
            podman build --platform linux/arm64 -t "$IMAGE_NAME" -f "$SCRIPT_DIR/scripts/dev/builder.Dockerfile" "$SCRIPT_DIR"
            ;;
        docker)
            docker build --platform linux/arm64 -t "$IMAGE_NAME" -f "$SCRIPT_DIR/scripts/dev/builder.Dockerfile" "$SCRIPT_DIR"
            ;;
        container)
            printf "ERROR: Apple's container tool is not yet fully supported in this script.\n"
            show_unsupported
            ;;
    esac
    
    log_with_timestamp "Builder image ready!"
fi

printf "\n"
log_with_timestamp "Starting build..."

# Ensure cache directories exist on host
mkdir -p "$SCRIPT_DIR/firmware" "$SCRIPT_DIR/tmp"

# Run the build in the pre-built ARM64 builder image using native container logging
run_container() {
    local exit_code=0
    
    case "$CONTAINER_TOOL" in
        podman)
            # Use passthrough-tty for real-time unbuffered output when running on a TTY
            podman run --rm \
                --log-driver=passthrough-tty \
                --platform linux/arm64 \
                -v "$SCRIPT_DIR:/workspace:Z" \
                -w /workspace \
                "$IMAGE_NAME" \
                bash -c "$1" 2>&1 | tee -a "$BUILD_LOG" || exit_code=$?
            ;;
        docker)
            # Docker's default json-file log driver provides good real-time output
            docker run --rm \
                --platform linux/arm64 \
                -v "$SCRIPT_DIR:/workspace" \
                -w /workspace \
                "$IMAGE_NAME" \
                bash -c "$1" 2>&1 | tee -a "$BUILD_LOG" || exit_code=$?
            ;;
        container)
            printf "ERROR: Apple's container tool is not yet fully supported.\n"
            show_unsupported
            ;;
    esac
    
    return $exit_code
}

# Log build start
log_with_timestamp "Starting container build for profile: $PROFILE"
log_with_timestamp "Output file: $OUTPUT_FILE"

# Run the build
run_container "
    set -e
    echo '[Container] Downloading firmware if needed...'
    make firmware || true

    echo '[Container] Building firmware...'
    make build PROFILE=$PROFILE OUTPUT_FILE=$OUTPUT_FILE

    echo '[Container] Build complete!'
    ls -lh $OUTPUT_FILE
"

BUILD_STATUS=$?

if [ "$BUILD_STATUS" -eq 0 ]; then
    printf "\n"
    log_with_timestamp "Build complete! Output file: $OUTPUT_FILE"
    log_with_timestamp "Build log saved to: $BUILD_LOG"
else
    printf "\n"
    log_with_timestamp "Build failed! Check log: $BUILD_LOG"
    exit "$BUILD_STATUS"
fi
