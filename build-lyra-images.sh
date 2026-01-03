#!/bin/bash
#
# Build script for all Luckfox Lyra variants with WiFi support
#

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# List of all Luckfox Lyra board variants
BOARDS=(
    "luckfox-lyra"
    "luckfox-lyra-plus"
    "luckfox-lyra-plus-custom"
    "luckfox-lyra-ultra-w"
    "luckfox-lyra-zero-w"
    "luckfox-lyra-pi"
)

# Build configuration
KERNEL_BRANCH="vendor"       # Use vendor kernel (6.1) with WiFi drivers
RELEASE="trixie"             # Debian Trixie (or use "bookworm" for Debian 12, "jammy" for Ubuntu 22.04)
BUILD_MINIMAL="no"           # Full image with all packages
BUILD_DESKTOP="no"           # CLI only
KERNEL_CONFIGURE="no"        # Use default kernel config

show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Build Armbian images for Luckfox Lyra boards with WiFi support.

Options:
    -b, --board BOARD       Build specific board (default: all)
                           Available: ${BOARDS[@]}
    -r, --release RELEASE   Debian/Ubuntu release (default: trixie)
                           Options: trixie, bookworm, jammy
    -k, --kernel BRANCH     Kernel branch (default: vendor)
                           Options: vendor, current, edge
    -c, --clean            Clean build (remove previous artifacts)
    -h, --help             Show this help message

Examples:
    # Build all Lyra variants
    $0

    # Build specific variant
    $0 --board luckfox-lyra-plus

    # Build with Ubuntu 22.04
    $0 --release jammy

    # Clean build
    $0 --clean

EOF
}

build_board() {
    local board=$1
    
    echo_info "Building image for: $board"
    echo_info "Kernel: $KERNEL_BRANCH | Release: $RELEASE"
    
    ./compile.sh \
        BOARD="$board" \
        BRANCH="$KERNEL_BRANCH" \
        RELEASE="$RELEASE" \
        BUILD_MINIMAL="$BUILD_MINIMAL" \
        BUILD_DESKTOP="$BUILD_DESKTOP" \
        KERNEL_CONFIGURE="$KERNEL_CONFIGURE" \
        COMPRESS_OUTPUTIMAGE="sha,gpg,img"
    
    if [ $? -eq 0 ]; then
        echo_info "Successfully built image for $board"
    else
        echo_error "Failed to build image for $board"
        return 1
    fi
}

# Parse command line arguments
SELECTED_BOARD=""
CLEAN_BUILD="no"

while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--board)
            SELECTED_BOARD="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE="$2"
            shift 2
            ;;
        -k|--kernel)
            KERNEL_BRANCH="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN_BUILD="yes"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate board selection
if [ -n "$SELECTED_BOARD" ]; then
    valid_board=false
    for board in "${BOARDS[@]}"; do
        if [ "$board" == "$SELECTED_BOARD" ]; then
            valid_board=true
            break
        fi
    done
    
    if [ "$valid_board" == "false" ]; then
        echo_error "Invalid board: $SELECTED_BOARD"
        echo_info "Available boards: ${BOARDS[@]}"
        exit 1
    fi
fi

# Clean build if requested
if [ "$CLEAN_BUILD" == "yes" ]; then
    echo_warn "Cleaning previous build artifacts..."
    ./compile.sh CLEAN_LEVEL="alldebs,images,cache"
fi

# Build images
echo_info "========================================="
echo_info "Luckfox Lyra Armbian Build Script"
echo_info "========================================="
echo_info "Configuration:"
echo_info "  Kernel Branch: $KERNEL_BRANCH"
echo_info "  Release: $RELEASE"
echo_info "  WiFi Support: Realtek & RALink USB adapters"
echo_info "  Custom Apps: Installed"
echo_info "========================================="

if [ -n "$SELECTED_BOARD" ]; then
    # Build single board
    build_board "$SELECTED_BOARD"
else
    # Build all boards
    echo_info "Building images for all Luckfox Lyra variants..."
    
    failed_boards=()
    
    for board in "${BOARDS[@]}"; do
        echo_info ""
        echo_info "========================================="
        if ! build_board "$board"; then
            failed_boards+=("$board")
        fi
    done
    
    echo_info ""
    echo_info "========================================="
    echo_info "Build Summary"
    echo_info "========================================="
    
    if [ ${#failed_boards[@]} -eq 0 ]; then
        echo_info "All builds completed successfully!"
    else
        echo_error "Failed builds:"
        for board in "${failed_boards[@]}"; do
            echo_error "  - $board"
        done
        exit 1
    fi
fi

echo_info ""
echo_info "Build complete! Images are in: output/images/"
echo_info ""
echo_info "Next steps:"
echo_info "  1. Flash image to SD card using Balena Etcher or dd"
echo_info "  2. Boot your Luckfox Lyra board"
echo_info "  3. Follow /root/WIFI_SETUP.txt for WiFi configuration"
echo_info ""
