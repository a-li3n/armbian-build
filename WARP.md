# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Overview

The Armbian Build Framework creates customizable OS images based on Debian or Ubuntu for single-board computers (SBCs) and embedded devices. This specific repository instance is customized for building Luckfox Lyra board variants with WiFi support.

## Build Commands

### Primary Build Entry Point
```bash
./compile.sh
```
The main entry point that sources `lib/single.sh` and calls `cli_entrypoint`. This supports both interactive and non-interactive modes.

### Quick Build Helpers (Luckfox Lyra-specific)
```bash
# Interactive build menu
./start-build.sh

# Build all Luckfox Lyra variants
./build-lyra-images.sh

# Build specific board
./build-lyra-images.sh --board luckfox-lyra-plus

# Build with different OS
./build-lyra-images.sh --board luckfox-lyra-plus --release jammy

# Clean build
./build-lyra-images.sh --clean
```

### Manual Build (Docker - Required on macOS)
```bash
./compile.sh docker \
    BOARD=luckfox-lyra-plus \
    BRANCH=vendor \
    RELEASE=bookworm \
    BUILD_MINIMAL=no \
    BUILD_DESKTOP=no \
    KERNEL_CONFIGURE=no \
    COMPRESS_OUTPUTIMAGE=sha,gpg,img
```

### Development Commands
```bash
# Create patches interactively
./compile.sh CREATE_PATCHES="yes"

# Configure kernel
./compile.sh BOARD=luckfox-lyra-plus BRANCH=vendor KERNEL_CONFIGURE=yes

# Build only kernel
./compile.sh BOARD=luckfox-lyra-plus BRANCH=vendor KERNEL_ONLY=yes

# Clean specific artifacts
./compile.sh CLEAN_LEVEL="alldebs,images,cache"
```

## Architecture

### Build Flow
The build system follows this execution path:
1. **compile.sh** - Entry point that validates environment and sources `lib/single.sh`
2. **lib/single.sh** - Initializes logging, traps, and calls `cli_entrypoint`
3. **lib/functions/cli/entrypoint.sh** - Parses CLI arguments, loads configuration
4. **lib/functions/main/** - Main build orchestration functions
5. **lib/functions/compilation/** - Kernel/U-Boot compilation and patching
6. **lib/functions/image/** - Image creation and rootfs assembly

### Key Directory Structure
```
lib/
├── functions/          # Modular build functions organized by concern
│   ├── artifacts/      # Build artifact management (kernel, u-boot, rootfs)
│   ├── bsp/           # Board support package functions
│   ├── cli/           # Command-line interface and argument parsing
│   ├── compilation/   # Kernel and bootloader compilation
│   ├── configuration/ # Build configuration and validation
│   ├── general/       # General utilities (extensions, debootstrap)
│   ├── host/          # Host system preparation and Docker
│   ├── image/         # Image creation and rootfs assembly
│   ├── logging/       # Build logging infrastructure
│   ├── main/          # Main build orchestration
│   └── rootfs/        # Rootfs customization
├── library-functions.sh # Core library functions
└── single.sh          # Entry point for compile.sh

config/
├── boards/            # Board-specific configurations (*.csc, *.conf, *.wip, *.tvb)
├── kernel/            # Kernel configurations per family/version
├── sources/           # Source repository definitions
├── bootscripts/       # Boot script templates
├── bootenv/           # Boot environment configurations
├── distributions/     # Distribution-specific settings (Debian/Ubuntu)
├── desktop/           # Desktop environment configurations
└── cli/              # CLI package lists

extensions/            # Optional build extensions (hooks/plugins)
patch/                # Kernel and U-Boot patches organized by family/version
userpatches/          # User customizations (override any config)
├── customize-image.sh # Post-build rootfs customization hook
└── (optional files)  # Can override any config/board/kernel files

output/
├── images/           # Final built images
├── debs/            # Generated .deb packages
└── debug/           # Build logs and debug artifacts
```

### Configuration Hierarchy
The build system uses a layered configuration approach:
1. **Framework defaults** - Base configurations in `config/`
2. **Board configs** - Board-specific settings in `config/boards/`
3. **User patches** - Overrides in `userpatches/` take highest precedence
4. **CLI parameters** - Command-line arguments override everything

### Board Configuration Files
Board files (`.csc`, `.conf`, `.wip`, `.tvb`) define:
- **BOARD_NAME**: Human-readable board name
- **BOARDFAMILY**: SoC family (e.g., "rockchip", "sunxi")
- **KERNEL_TARGET**: Supported kernel branches ("vendor", "current", "edge")
- **BOOT_SOC**: Specific SoC model for bootloader selection
- **BOOTCONFIG**: U-Boot defconfig name
- **BOOT_FDT_FILE**: Device tree blob filename
- **enable_extension**: Enable optional build features

### Extension System
Extensions are bash scripts in `extensions/` that hook into build phases. They can:
- Add packages to the image
- Modify kernel/bootloader configuration
- Customize the rootfs
- Provide specialized hardware support

Enable extensions in board configs: `enable_extension "extension-name"`

### Customization via userpatches/
The `userpatches/` directory allows project-specific overrides:
- **customize-image.sh**: Called during rootfs assembly, can install packages, create files, configure system
- **lib/**: Override framework functions
- **config/boards/**: Add custom board configurations
- **kernel-config/**: Provide custom kernel configurations
- **atf/**, **u-boot/**, **kernel/**: Provide custom patches

## Key Build Parameters

### Required Parameters
- **BOARD**: Board configuration name (from `config/boards/`)
- **BRANCH**: Kernel version (`vendor`, `current`, `edge`)
- **RELEASE**: Distribution release (`bookworm`, `jammy`, `noble`, etc.)

### Common Optional Parameters
- **BUILD_MINIMAL**: `yes` for minimal image, `no` for full (default: `no`)
- **BUILD_DESKTOP**: `yes` to include desktop environment (default: `no`)
- **KERNEL_CONFIGURE**: `yes` to interactively configure kernel (default: `no`)
- **KERNEL_ONLY**: `yes` to build only kernel package (default: `no`)
- **CREATE_PATCHES**: `yes` to enable patch creation mode (default: `no`)
- **COMPRESS_OUTPUTIMAGE**: Compression options (`sha`, `gpg`, `img`, `xz`, `gz`)
- **CLEAN_LEVEL**: What to clean (`make`, `debs`, `alldebs`, `images`, `cache`, `sources`)

### Luckfox Lyra Boards
This repository is customized for these board variants:
- **luckfox-lyra**: RK3506G2, 128MB RAM
- **luckfox-lyra-plus**: RK3506G2, 128MB RAM, Ethernet
- **luckfox-lyra-ultra-w**: RK3506B, 512MB RAM, onboard WiFi/BT, eMMC
- **luckfox-lyra-zero-w**: RK3506B, 512MB RAM, onboard WiFi/BT
- **luckfox-lyra-pi**: RK3506B, 512MB RAM

All boards use `BRANCH=vendor` (Rockchip 6.1 kernel) for WiFi driver support.

## Testing

### Validation Workflow
1. Build image for target board
2. Flash to SD card using Balena Etcher or `dd`
3. Boot the board with serial console connected (optional but recommended)
4. Check system boots successfully
5. Test hardware-specific features (WiFi, Ethernet, GPIO, etc.)
6. Run any board-specific test scripts

### No Automated Test Framework
This repository does not have a unified test framework. Testing is manual and board-specific. Check board documentation for specific test procedures.

### Linting/Type Checking
```bash
# Bash scripts can be checked with shellcheck (if available)
shellcheck compile.sh lib/*.sh

# Python tools can be checked with pylint/mypy (if available)
# However, this is not enforced by the build system
```

## Best Practices

### Build Environment Setup

#### Host Requirements
- **Linux**: Native builds supported (Ubuntu/Debian recommended)
- **macOS**: Must use Docker (automatically detected by build system)
- **Windows**: WSL2 or Docker required
- **Disk Space**: Minimum 50GB free, recommended 100GB+
- **RAM**: Minimum 4GB, recommended 8GB+ for parallel builds
- **Dependencies**: Install via `./compile.sh` which auto-installs required packages

#### Initial Setup
```bash
git clone --depth=1 --branch=main https://github.com/armbian/build
cd build
./compile.sh  # First run installs dependencies
```

### Userpatches Directory Structure

The `userpatches/` directory is the correct place for all customizations:

```
userpatches/
├── customize-image.sh       # Main image customization hook (MANDATORY for package installs)
├── config-default.conf      # Build defaults (BOARD, BRANCH, RELEASE)
├── lib/                     # Override framework functions
├── kernel-config/           # Custom kernel configs
├── u-boot/                  # U-Boot patches
├── kernel/                  # Kernel patches
└── config/
    └── boards/              # Custom board configs
```

### Build Commands Best Practices

#### Interactive Build (Recommended for First-Time Users)
```bash
./compile.sh
# Follow prompts to select board, branch, release, desktop
```

#### Non-Interactive Build (Recommended for Automation)
```bash
./compile.sh docker \
    BOARD=boardname \
    BRANCH=vendor \
    RELEASE=bookworm \
    BUILD_MINIMAL=no \
    BUILD_DESKTOP=no \
    KERNEL_CONFIGURE=no \
    COMPRESS_OUTPUTIMAGE=sha,img
```

#### Build Parameter Guidelines
- **Always specify**: `BOARD`, `BRANCH`, `RELEASE`
- **Docker on macOS**: Always prefix with `docker` parameter
- **Use config file**: Create `userpatches/config-default.conf` to avoid repeating parameters
- **Compression**: Use `COMPRESS_OUTPUTIMAGE=sha,img` (avoid xz/gz for faster iteration)
- **Clean builds**: Use `CLEAN_LEVEL=cache,sources` only when needed (slow)

#### Development Workflow
```bash
# Kernel configuration
./compile.sh BOARD=boardname BRANCH=vendor KERNEL_CONFIGURE=yes

# Create patches interactively
./compile.sh CREATE_PATCHES=yes

# Build only kernel
./compile.sh KERNEL_ONLY=yes

# Clean specific artifacts
./compile.sh CLEAN_LEVEL=make        # Clean build artifacts only
./compile.sh CLEAN_LEVEL=debs        # Clean built packages
./compile.sh CLEAN_LEVEL=images      # Clean output images
./compile.sh CLEAN_LEVEL=cache       # Full cache clean (slow!)
```

### Image Customization (customize-image.sh)

#### Critical Rules for customize-image.sh

1. **Always use framework functions** - Never use raw chroot or apt commands:
   ```bash
   # CORRECT
   chroot_sdcard_apt_get_update
   chroot_sdcard_apt_get_install package1 package2
   
   # WRONG - Will fail silently or cause errors
   chroot $SDCARD apt-get update
   apt-get install package1
   ```

2. **Use display_alert for logging** - Makes debugging easier:
   ```bash
   display_alert "Installing" "application packages" "info"
   display_alert "Configuration failed" "check logs" "err"
   ```

3. **Use $SDCARD variable** - Never hardcode paths:
   ```bash
   # CORRECT
   cat <<-EOF > "${SDCARD}"/etc/myconfig
   mkdir -p "${SDCARD}"/usr/local/bin
   
   # WRONG
   cat <<-EOF > /tmp/sdcard/etc/myconfig
   ```

4. **Use case statements** for board/release-specific customizations:
   ```bash
   case $BOARD in
       boardname*)
           # Board-specific customizations
           ;;
   esac
   
   case $RELEASE in
       bookworm|trixie)
           # Debian-specific
           ;;
       jammy|noble)
           # Ubuntu-specific
           ;;
   esac
   ```

5. **Always wrap main logic in Main() function**:
   ```bash
   Main() {
       # Your customization logic
   }
   
   Main "$@"
   ```

6. **Set proper permissions** for created files:
   ```bash
   chmod 600 "${SDCARD}"/etc/sensitive.conf
   chmod +x "${SDCARD}"/usr/local/bin/script
   ```

7. **Use heredocs for multi-line files**:
   ```bash
   cat <<-EOF > "${SDCARD}"/etc/config
   line1
   line2
   EOF
   
   # For scripts with variables to preserve, use quoted heredoc
   cat <<-'EOF' > "${SDCARD}"/script.sh
   #!/bin/bash
   echo $VARIABLE  # This $ is literal, not expanded
   EOF
   ```

#### Available Framework Functions in customize-image.sh

- `chroot_sdcard_apt_get_update` - Update apt cache
- `chroot_sdcard_apt_get_install <packages>` - Install packages
- `chroot_sdcard_apt_get_remove <packages>` - Remove packages
- `chroot_sdcard` - Execute arbitrary command in chroot
- `display_alert <message> <submessage> <level>` - Log messages (info/wrn/err)
- `add_apt_sources <source>` - Add custom apt sources
- `check_if_installed <package>` - Check if package installed on host

#### Common Mistakes to Avoid

1. **Installing packages outside customize-image.sh** - Always use the hook
2. **Forgetting apt-get update** - Always call `chroot_sdcard_apt_get_update` before install
3. **Not checking return codes** - Framework functions handle errors, but check critical operations
4. **Hardcoding paths** - Always use `${SDCARD}` variable
5. **Creating files with wrong ownership** - Files created on host are owned by build user; chroot commands run as root
6. **Modifying system files directly** - Use framework overlays when possible

### Extensions System

#### When to Use Extensions vs customize-image.sh
- **customize-image.sh**: Image-specific customizations (packages, configs, scripts)
- **Extensions**: Reusable features across multiple boards (e.g., Docker support, cloudimg)

#### Using Existing Extensions
```bash
# In board config file
enable_extension "docker-ce"
enable_extension "grub-with-dtb"
```

#### Creating Custom Extensions
Place in `userpatches/extensions/myextension.sh`:
```bash
function extension_prepare_config__myextension() {
    # Runs during config phase
}

function post_install_kernel_debs__myextension() {
    # Runs after kernel installation
}
```

### Patching Best Practices

#### Creating Patches
1. Run `./compile.sh CREATE_PATCHES=yes`
2. Build proceeds until source extraction, then pauses
3. Modify source in the directory shown
4. Press Enter to continue - patches auto-generated in `output/patch/`
5. Move patches to `userpatches/kernel/<family>-<version>/` or `patch/kernel/<family>-<version>/`

#### Patch Organization
```
userpatches/
└── kernel/
    └── rockchip-vendor-6.1/
        ├── 0001-my-feature.patch
        └── 0002-my-other-feature.patch
```

#### Patch Naming
- Use numeric prefixes: `0001-`, `0002-`, etc.
- Descriptive names: `0001-add-custom-dts.patch`
- Patches applied in alphanumeric order

### Board Configuration Files

#### Required Variables
```bash
BOARD_NAME="Human Readable Name"
BOARDFAMILY="rockchip"          # SoC family
KERNEL_TARGET="vendor,current"  # Supported branches
BOOT_SOC="rk3506"               # Specific SoC
BOOTCONFIG="boardname_defconfig"
BOOT_FDT_FILE="rockchip/boardname.dtb"
```

#### Optional but Recommended
```bash
MODULES="module1 module2"        # Kernel modules to load
MODULES_BLACKLIST="badmodule"    # Modules to blacklist
DEFAULT_CONSOLE="serial"         # or "both"
SERIALCON="ttyS0"               # Serial console device
```

### Testing and Validation

#### Pre-Deployment Checklist
1. **Build completes without errors** - Check `output/logs/`
2. **Image boots successfully** - Test on hardware or emulator
3. **Packages installed** - SSH in and verify with `dpkg -l` or `which`
4. **Services running** - Check with `systemctl status`
5. **Hardware functions** - Test WiFi, GPIO, peripherals
6. **Logs clean** - Check `dmesg`, `journalctl -xe`

#### Debugging Build Failures
```bash
# Check detailed logs
cat output/logs/log-build-*.log
cat output/debug/output.log

# Search for errors
grep -i error output/logs/*.log
grep -i failed output/logs/*.log

# Check customization script output
grep -A 20 "customize-image.sh" output/logs/*.log
```

### Performance Optimization

#### Faster Iteration
1. **Disable compression**: `COMPRESS_OUTPUTIMAGE=img` (no xz/gz)
2. **Use incremental builds**: Don't use `CLEAN_LEVEL` unless needed
3. **Build kernel separately**: `KERNEL_ONLY=yes` when only changing kernel
4. **Cache sources**: Never clean `cache/sources/` unless necessary

#### Parallel Builds
```bash
# Framework automatically uses available CPU cores
# Adjust with:
PARALLEL_BUILD=4  # Limit parallel jobs
```

### Common Issues Specific to customize-image.sh

#### Issue: Packages not installed in image
**Cause**: Using wrong function in customize-image.sh  
**Solution**: Use `chroot_sdcard_apt_get_install` not `chroot $SDCARD apt-get install`

#### Issue: Changes not applied
**Cause**: Incremental build using old cache  
**Solution**: `./compile.sh CLEAN_LEVEL=cache` and rebuild

#### Issue: Script runs but changes missing
**Cause**: Syntax error or incorrect variable usage  
**Solution**: Check logs with `grep "customize-image" output/logs/*.log`

## Development Practices

### Creating Patches
1. Run `./compile.sh CREATE_PATCHES="yes"`
2. Follow prompts to build until source directory pause
3. Make changes in the specified source directory
4. Press Enter to continue - patches will be generated in `output/patch/`
5. Move patches to appropriate location in `patch/` directory:
   - Kernel: `patch/kernel/<family>-<version>/`
   - U-Boot: `patch/u-boot/<family>/`

### Adding New Board Support
1. Create board config in `config/boards/<boardname>.csc`
2. Define all required variables (see existing boards as examples)
3. Add device tree if not in kernel source
4. Test build and boot process
5. Document any special requirements

### Customizing Images (Luckfox Lyra)
The customization logic is in `userpatches/customize-image.sh`:
- Installs comprehensive package suite (development tools, utilities, networking)
- Configures WiFi drivers and firmware for USB adapters
- Creates helper scripts (`setup-wifi`)
- Sets up wpa_supplicant configuration

To add packages:
```bash
chroot_sdcard_apt_get_install \
    your-package-name \
    another-package
```

### Working with Git
```bash
# This repository uses git for version control
# To see what you've changed (patches/configs)
git --no-pager diff

# To see uncommitted files
git --no-pager status

# When committing, include co-author attribution
git commit -m "Your commit message

Co-Authored-By: Warp <agent@warp.dev>"
```

## Platform-Specific Notes

### macOS Development
- **Docker is required** - Native builds not supported on macOS
- Install Docker Desktop or use `brew install --cask docker`
- Requires Bash 5.x: `brew install bash coreutils git`
- Build system automatically uses Docker when on macOS
- Cannot run as root on macOS

### Build Time Expectations
- **First build**: 2-4 hours (downloads toolchains, sources, builds everything)
- **Subsequent builds**: 30-60 minutes (uses cached artifacts)
- **All 5 Luckfox variants**: 3-6 hours total (first time)

### Disk Space Requirements
- Minimum: 50GB free space
- Recommended: 100GB+ for multiple board variants
- Cache grows over time with multiple builds

## Output Artifacts

### Image Location
Built images are in: `output/images/`

Example filename: `Armbian_24.11.0_Luckfox-lyra-plus_bookworm_vendor_6.1.75.img`

### Other Outputs
- **output/debs/**: Kernel and U-Boot .deb packages
- **output/debug/**: Build logs (useful for debugging failures)
- **cache/sources/**: Downloaded and patched source code (reused across builds)
- **cache/toolchain/**: Cross-compilation toolchains

## Documentation References

- **Main docs**: https://docs.armbian.com/Developer-Guide_Overview/
- **Contributing**: CONTRIBUTING.md in this repository
- **Luckfox Lyra guide**: LUCKFOX_LYRA_BUILD_GUIDE.md (project-specific)
- **Forums**: https://forum.armbian.com
- **GitHub**: https://github.com/armbian/build

## Common Issues and Solutions

### Build Failures
- Check `output/debug/` for detailed logs
- Ensure Docker is running (macOS)
- Verify disk space is sufficient
- Try clean build: `./compile.sh CLEAN_LEVEL="cache"`

### Patch Application Failures
- Patches may fail if kernel version changes
- Check patch context in `patch/` directory
- May need to regenerate patches with `CREATE_PATCHES=yes`

### Cross-Architecture Notes
- Build system handles cross-compilation automatically
- Toolchains downloaded on first build
- Can build ARM images on x86_64 hosts via QEMU/chroot
