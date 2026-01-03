#!/bin/bash
#
# Quick Start Script for Luckfox Lyra Armbian Builds
# This script verifies prerequisites and provides an interactive menu
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     Luckfox Lyra Armbian Build System                       ║
║     Custom Images with WiFi & Application Support           ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF

echo ""

# Check if Docker is installed
check_docker() {
    echo -e "${CYAN}Checking prerequisites...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}✗ Docker not found!${NC}"
        echo ""
        echo "Docker is required to build Armbian on macOS."
        echo ""
        echo "Please install Docker Desktop:"
        echo "  1. Download from: https://www.docker.com/products/docker-desktop"
        echo "  2. Or install via Homebrew: brew install --cask docker"
        echo ""
        exit 1
    else
        echo -e "${GREEN}✓ Docker found${NC}"
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        echo -e "${YELLOW}⚠ Docker is installed but not running${NC}"
        echo ""
        echo "Please start Docker Desktop and try again."
        echo ""
        exit 1
    else
        echo -e "${GREEN}✓ Docker is running${NC}"
    fi
    
    # Check disk space (at least 20GB recommended)
    available_space=$(df -g . | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 20 ]; then
        echo -e "${YELLOW}⚠ Warning: Low disk space (${available_space}GB available)${NC}"
        echo "  At least 20GB free space is recommended."
    else
        echo -e "${GREEN}✓ Sufficient disk space (${available_space}GB available)${NC}"
    fi
    
    echo ""
}

# Show board menu
show_board_menu() {
    echo -e "${CYAN}Select Board to Build:${NC}"
    echo ""
    echo "  1) Luckfox Lyra (Standard)"
    echo "     └─ RK3506G2, 128MB RAM, SD card"
    echo ""
    echo "  2) Luckfox Lyra Plus"
    echo "     └─ RK3506G2, 128MB RAM, Ethernet, SD card"
    echo ""
    echo "  3) Luckfox Lyra Ultra W"
    echo "     └─ RK3506B, 512MB RAM, WiFi/BT, 8GB eMMC"
    echo ""
    echo "  4) Luckfox Lyra Zero W"
    echo "     └─ RK3506B, 512MB RAM, WiFi/BT, SD card"
    echo ""
    echo "  5) Luckfox Lyra Pi"
    echo "     └─ RK3506B, 512MB RAM, RMII, SDIO"
    echo ""
    echo "  6) Build ALL variants (recommended for first build)"
    echo ""
    echo "  0) Exit"
    echo ""
}

# Show OS menu
show_os_menu() {
    echo -e "${CYAN}Select Operating System:${NC}"
    echo ""
    echo "  1) Debian 13 (Trixie) - Recommended"
    echo "  2) Debian 12 (Bookworm)"
    echo "  3) Ubuntu 22.04 (Jammy)"
    echo ""
}

# Main interactive menu
main_menu() {
    check_docker
    
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    show_board_menu
    echo -n "Enter your choice [1-6, 0 to exit]: "
    read board_choice
    
    case $board_choice in
        0)
            echo "Exiting..."
            exit 0
            ;;
        1)
            BOARD="luckfox-lyra"
            ;;
        2)
            BOARD="luckfox-lyra-plus"
            ;;
        3)
            BOARD="luckfox-lyra-ultra-w"
            ;;
        4)
            BOARD="luckfox-lyra-zero-w"
            ;;
        5)
            BOARD="luckfox-lyra-pi"
            ;;
        6)
            BOARD="all"
            ;;
        *)
            echo -e "${RED}Invalid choice!${NC}"
            exit 1
            ;;
    esac
    
    if [ "$BOARD" != "all" ]; then
        echo ""
        echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
        show_os_menu
        echo -n "Enter your choice [1-3]: "
        read os_choice
        
        case $os_choice in
            1)
                RELEASE="trixie"
                ;;
            2)
                RELEASE="bookworm"
                ;;
            3)
                RELEASE="jammy"
                ;;
            *)
                echo -e "${RED}Invalid choice!${NC}"
                exit 1
                ;;
        esac
    else
        RELEASE="trixie"  # Default for all builds
    fi
    
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Build Configuration:${NC}"
    if [ "$BOARD" == "all" ]; then
        echo "  Boards: All 5 Luckfox Lyra variants"
    else
        echo "  Board: $BOARD"
    fi
    echo "  OS: $RELEASE"
    echo "  Kernel: vendor (6.1 with WiFi drivers)"
    echo "  Features: WiFi support + Pre-installed apps"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}This will take 2-4 hours for the first build.${NC}"
    echo -e "${YELLOW}Subsequent builds will be faster (30-60 minutes).${NC}"
    echo ""
    echo -n "Continue? [y/N]: "
    read confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Build cancelled."
        exit 0
    fi
    
    echo ""
    echo -e "${GREEN}Starting build...${NC}"
    echo ""
    
    # Start the build
    if [ "$BOARD" == "all" ]; then
        ./build-lyra-images.sh --release "$RELEASE"
    else
        ./build-lyra-images.sh --board "$BOARD" --release "$RELEASE"
    fi
}

# Show help
show_help() {
    cat << EOF
Luckfox Lyra Armbian Build System - Quick Start

Usage:
  $0              Interactive menu
  $0 --help       Show this help message

For advanced options, see:
  - ./build-lyra-images.sh --help
  - LUCKFOX_LYRA_BUILD_GUIDE.md

EOF
}

# Parse arguments
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    show_help
    exit 0
fi

# Run main menu
main_menu
