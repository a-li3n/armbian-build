# Luckfox Lyra Armbian Build Guide

This guide will help you build custom Armbian images for all Luckfox Lyra variants with built-in WiFi drivers and pre-installed applications.

## Supported Boards

- **Luckfox Lyra** (RK3506G2, 128MB RAM)
- **Luckfox Lyra Plus** (RK3506G2, 128MB RAM, Ethernet)
- **Luckfox Lyra Ultra W** (RK3506B, 512MB RAM, WiFi/BT onboard, eMMC)
- **Luckfox Lyra Zero W** (RK3506B, 512MB RAM, WiFi/BT onboard)
- **Luckfox Lyra Pi** (RK3506B, 512MB RAM)

## Features

### WiFi Support (USB Adapters)
The images include drivers for the following USB WiFi chipsets:

**Realtek:**
- RTL8188EU, RTL8192CU, RTL8187
- RTL8821CU, RTL8822BU
- RTL88XXau, RTL8192EU

**RALink/MediaTek:**
- RT2800USB, RT2500USB, RT73USB
- MT7601U, MT76x0U, MT76x2U
- MT7663U, MT7921U

### Pre-installed Applications
All images come with the following packages pre-installed:
- **Development Tools:** build-essential, cmake, git, ninja-build, protobuf-compiler
- **System Utilities:** htop, iftop, lsof, tree, rsync, wget, curl
- **Network Tools:** net-tools, iputils-ping, wireless-tools, iw, rfkill
- **Hardware Tools:** i2c-tools, gpiod, libgpiod-dev, spi-tools, mtd-utils, evtest
- **Communication:** minicom, screen, socat, tio, telnet, ssh
- **Python:** python3-pip, python3-venv, python3-serial, python3-spidev, python3-luma.oled
- **Libraries:** libssl-dev, libbluetooth-dev, libulfius-dev, liborcania-dev, libyaml-cpp-dev
- **Other:** vim, nano, zsh, jq, qrencode, ccze, unzip

## Prerequisites

### macOS/Linux Build Machine
Since you're on macOS, you'll need to build using Docker or a Linux VM. Armbian provides Docker support out of the box.

**Requirements:**
- Docker Desktop for Mac (or Vagrant + VirtualBox)
- At least 20GB free disk space
- 8GB RAM recommended
- Fast internet connection

### Install Docker
```bash
# Install Docker Desktop from: https://www.docker.com/products/docker-desktop
# Or via Homebrew:
brew install --cask docker
```

## Quick Start

### 1. Navigate to Build Directory
```bash
cd ~/armbian-build
```

### 2. Build a Single Board
```bash
# Build for Luckfox Lyra Plus (most popular variant)
./build-lyra-images.sh --board luckfox-lyra-plus
```

### 3. Build All Variants
```bash
# Build images for all 5 Lyra variants
./build-lyra-images.sh
```

### 4. Build with Different Options
```bash
# Build with Ubuntu 22.04 instead of Debian
./build-lyra-images.sh --release jammy

# Clean build (removes cache)
./build-lyra-images.sh --clean

# Build specific board with Ubuntu
./build-lyra-images.sh --board luckfox-lyra-ultra-w --release jammy
```

## Manual Build Process

If you prefer to build manually without the helper script:

### Using Docker (Recommended for macOS)
```bash
cd ~/armbian-build

# Build for specific board
./compile.sh docker \
    BOARD=luckfox-lyra-plus \
    BRANCH=vendor \
    RELEASE=bookworm \
    BUILD_MINIMAL=no \
    BUILD_DESKTOP=no \
    KERNEL_CONFIGURE=no \
    COMPRESS_OUTPUTIMAGE=sha,gpg,img
```

### Build Options Explained

- `BOARD`: Board configuration name
  - `luckfox-lyra` - Standard Lyra
  - `luckfox-lyra-plus` - Lyra Plus with Ethernet
  - `luckfox-lyra-ultra-w` - Lyra Ultra W with onboard WiFi
  - `luckfox-lyra-zero-w` - Lyra Zero W with onboard WiFi
  - `luckfox-lyra-pi` - Lyra Pi

- `BRANCH`: Kernel version
  - `vendor` - Rockchip 6.1 vendor kernel (recommended, includes all WiFi drivers)
  - `current` - Mainline 6.12
  - `edge` - Mainline 6.18

- `RELEASE`: Distribution
  - `bookworm` - Debian 12 (recommended)
  - `jammy` - Ubuntu 22.04

- `BUILD_MINIMAL`: 
  - `no` - Full image with all packages (recommended)
  - `yes` - Minimal image

- `BUILD_DESKTOP`:
  - `no` - Command-line only (recommended for embedded)
  - `yes` - Include desktop environment

## Build Time Estimates

- **First build:** 2-4 hours (downloads toolchains, kernel sources)
- **Subsequent builds:** 30-60 minutes (uses cached components)
- **All 5 variants:** 3-6 hours total (first time)

## Output Location

After a successful build, images will be in:
```
~/armbian-build/output/images/
```

Example filename:
```
Armbian_24.11.0_Luckfox-lyra-plus_bookworm_vendor_6.1.75.img
```

## Flashing the Image

### Using Balena Etcher (GUI - Easiest)
1. Download from: https://www.balena.io/etcher/
2. Insert SD card
3. Select the `.img` file
4. Select SD card
5. Flash!

### Using dd (Command Line)
```bash
# Find SD card device
diskutil list

# Unmount (replace diskN with your SD card)
diskutil unmountDisk /dev/diskN

# Flash image (BE CAREFUL with disk number!)
sudo dd if=~/armbian-build/output/images/Armbian_*.img of=/dev/rdiskN bs=1m status=progress

# Eject
diskutil eject /dev/diskN
```

## First Boot

1. Insert SD card into Luckfox Lyra board
2. Connect USB-C power (5V/2A recommended)
3. Connect serial console (optional, for debugging)
4. Wait for boot (first boot takes ~2 minutes)

### Default Credentials
- **Username:** root
- **Password:** 1234 (you'll be prompted to change on first login)

## Setting Up WiFi

### Quick Setup (USB WiFi Adapter)
```bash
# 1. Plug in USB WiFi adapter
# 2. Run the setup helper
sudo setup-wifi "YourSSID" "YourPassword"

# 3. Check connection
ip a
```

### Manual Setup
```bash
# Edit wpa_supplicant config
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf

# Add network:
network={
    ssid="YourNetworkName"
    psk="YourPassword"
}

# Restart networking
sudo systemctl restart networking

# Check status
ip a
iw dev wlan0 link
```

### Troubleshooting WiFi
```bash
# Check if adapter is detected
lsusb

# Check loaded modules
lsmod | grep -E "rt|rtl|mt"

# Check available interfaces
iw dev

# View kernel messages
dmesg | grep -E "wlan|wifi|usb"

# Manually load driver (example for RTL8188EU)
sudo modprobe r8188eu

# Scan for networks
sudo iw dev wlan0 scan | grep SSID
```

## Customization

### Adding More Packages
Edit `userpatches/customize-image.sh` and add to the package installation section:
```bash
chroot_sdcard_apt_get_install \
    your-package-name \
    another-package
```

### Kernel Configuration
If you need to modify kernel config:
```bash
./compile.sh BOARD=luckfox-lyra-plus BRANCH=vendor KERNEL_CONFIGURE=yes
```

### Adding WiFi Drivers
Additional WiFi drivers can be enabled by editing:
```
config/kernel/linux-rockchip-rv1106-vendor.config
```

Look for `CONFIG_RT*` or `CONFIG_RTL*` options and enable as needed.

## Board-Specific Notes

### Lyra (Standard)
- 128MB RAM - use lowmem optimization
- No Ethernet, USB WiFi required
- SD card boot only

### Lyra Plus
- 128MB RAM - use lowmem optimization  
- Has Ethernet port (10/100Mbps)
- SD card boot only

### Lyra Ultra W
- 512MB RAM
- Onboard AIC8800 WiFi/BT module
- 8GB eMMC + SD card support

### Lyra Zero W
- 512MB RAM
- Onboard AIC8800 WiFi/BT module
- SD card boot

### Lyra Pi
- 512MB RAM
- Based on Core3506 module
- RMII Ethernet, SDIO

## Advanced: Building for Multiple Boards

To build all variants in one go:
```bash
for board in luckfox-lyra luckfox-lyra-plus luckfox-lyra-ultra-w luckfox-lyra-zero-w luckfox-lyra-pi; do
    echo "Building $board..."
    ./compile.sh docker \
        BOARD=$board \
        BRANCH=vendor \
        RELEASE=bookworm \
        BUILD_MINIMAL=no \
        BUILD_DESKTOP=no
done
```

Or simply use the helper script:
```bash
./build-lyra-images.sh
```

## Resources

- **Armbian Documentation:** https://docs.armbian.com/
- **Luckfox Wiki:** https://wiki.luckfox.com/
- **Armbian Forums:** https://forum.armbian.com/
- **GitHub Issues:** https://github.com/armbian/build/issues

## Support

For issues specific to:
- **Armbian build system:** Armbian forums
- **Luckfox hardware:** Luckfox forums  
- **This custom build:** Check WIFI_SETUP.txt on the built image

## License

This build configuration follows Armbian's GPL-2.0 license.

## Contributing

If you make improvements to the board configs or customization scripts, consider contributing back to the Armbian project!

## Changelog

### 2025-01-28
- Initial setup for all 5 Luckfox Lyra variants
- Added comprehensive WiFi USB adapter support (Realtek & RALink)
- Pre-installed application suite
- Helper scripts for easy WiFi configuration
- Build automation script

---

**Happy Building! 🚀**
