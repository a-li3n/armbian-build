# Armbian Build Framework - Comprehensive Best Practices

This document outlines best practices when building custom Armbian images. These practices are derived from official Armbian documentation and real-world experience building images for embedded systems.

## Build Environment Setup

### Host Requirements
- **Linux**: Native builds supported (Ubuntu/Debian recommended)
- **macOS**: Must use Docker (automatically detected by build system)
- **Windows**: WSL2 or Docker required
- **Disk Space**: Minimum 50GB free, recommended 100GB+
- **RAM**: Minimum 4GB, recommended 8GB+ for parallel builds
- **Dependencies**: Install via `./compile.sh` which auto-installs required packages

### Initial Setup
```bash
git clone --depth=1 --branch=main https://github.com/armbian/build
cd build
./compile.sh  # First run installs dependencies
```

## Userpatches Directory Structure

The `userpatches/` directory is the **correct and only** place for all project-specific customizations. Never modify files in the main `lib/`, `config/`, or `patch/` directories directly.

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

## Build Commands Best Practices

### Interactive Build (Recommended for First-Time Users)
```bash
./compile.sh
# Follow prompts to select board, branch, release, desktop
```

### Non-Interactive Build (Recommended for Automation)
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

### Build Parameter Guidelines
- **Always specify**: `BOARD`, `BRANCH`, `RELEASE`
- **Docker on macOS**: Always prefix with `docker` parameter
- **Use config file**: Create `userpatches/config-default.conf` to avoid repeating parameters
- **Compression**: Use `COMPRESS_OUTPUTIMAGE=sha,img` (avoid xz/gz for faster iteration during development)
- **Clean builds**: Use `CLEAN_LEVEL=cache,sources` only when needed (extremely slow)

### Development Workflow Commands
```bash
# Kernel configuration
./compile.sh BOARD=boardname BRANCH=vendor KERNEL_CONFIGURE=yes

# Create patches interactively
./compile.sh CREATE_PATCHES=yes

# Build only kernel (faster iteration)
./compile.sh KERNEL_ONLY=yes

# Clean specific artifacts
./compile.sh CLEAN_LEVEL=make        # Clean build artifacts only
./compile.sh CLEAN_LEVEL=debs        # Clean built packages
./compile.sh CLEAN_LEVEL=images      # Clean output images
./compile.sh CLEAN_LEVEL=cache       # Full cache clean (slow! avoid unless necessary)
```

## Image Customization (customize-image.sh)

### Critical Rules for customize-image.sh

The `userpatches/customize-image.sh` script is the **ONLY** correct way to install packages and customize images. This hook runs during image assembly with proper chroot context.

#### 1. Always use framework functions - Never use raw chroot or apt commands

```bash
# ✅ CORRECT
chroot_sdcard_apt_get_update
chroot_sdcard_apt_get_install package1 package2

# ❌ WRONG - Will fail silently or cause errors
chroot $SDCARD apt-get update
apt-get install package1
```

**Why this matters**: The framework functions handle proper chroot setup, error handling, logging, and environment variables. Raw commands will either fail silently or break the image.

#### 2. Use display_alert for logging

```bash
display_alert "Installing" "application packages" "info"
display_alert "Configuration failed" "check logs" "err"
display_alert "Customizing" "WiFi setup" "info"
```

**Why this matters**: Makes debugging much easier. These alerts appear in build logs with proper formatting and timestamps.

#### 3. Use $SDCARD variable - Never hardcode paths

```bash
# ✅ CORRECT
cat <<-EOF > "${SDCARD}"/etc/myconfig
mkdir -p "${SDCARD}"/usr/local/bin

# ❌ WRONG
cat <<-EOF > /tmp/sdcard/etc/myconfig
```

**Why this matters**: The build system sets `$SDCARD` to the correct temporary mount point. Hardcoded paths will fail.

#### 4. Use case statements for board/release-specific customizations

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

**Why this matters**: Allows a single script to handle multiple boards and distributions cleanly.

#### 5. Always wrap main logic in Main() function

```bash
Main() {
    # Your customization logic here
}

Main "$@"
```

**Why this matters**: Framework convention. Ensures proper variable scoping and allows the script to be sourced without executing.

#### 6. Set proper permissions for created files

```bash
chmod 600 "${SDCARD}"/etc/wpa_supplicant/wpa_supplicant.conf  # Sensitive
chmod 644 "${SDCARD}"/etc/network/interfaces.d/wlan0          # World-readable
chmod +x "${SDCARD}"/usr/local/bin/setup-script               # Executable
```

**Why this matters**: Security and functionality. Wrong permissions will cause services to fail or create security vulnerabilities.

#### 7. Use heredocs for multi-line files

```bash
# Standard heredoc (variables are expanded)
cat <<-EOF > "${SDCARD}"/etc/config
setting1=$VALUE
setting2=fixed
EOF

# Quoted heredoc (preserves literal text, variables NOT expanded)
cat <<-'EOF' > "${SDCARD}"/usr/local/bin/script.sh
#!/bin/bash
echo $VARIABLE  # This $ is literal, not expanded during creation
EOF
```

**Why this matters**: Clean, readable way to create configuration files. Quoted heredocs preserve shell variables for runtime execution.

### Available Framework Functions

These functions are available in `customize-image.sh`:

- `chroot_sdcard_apt_get_update` - Update apt package cache
- `chroot_sdcard_apt_get_install <packages>` - Install packages
- `chroot_sdcard_apt_get_remove <packages>` - Remove packages
- `chroot_sdcard <command>` - Execute arbitrary command in chroot
- `display_alert <message> <submessage> <level>` - Log messages (levels: info, wrn, err)
- `add_apt_sources <source>` - Add custom apt sources
- `check_if_installed <package>` - Check if package installed on host system

### Common Mistakes to Avoid

1. **Installing packages outside customize-image.sh**
   - ❌ Don't manually chroot and install after build
   - ✅ Use the customize-image.sh hook

2. **Forgetting apt-get update**
   - ❌ Directly calling `chroot_sdcard_apt_get_install` without update
   - ✅ Always call `chroot_sdcard_apt_get_update` first

3. **Not checking return codes for critical operations**
   - Framework functions handle most errors, but verify critical steps succeeded

4. **Hardcoding paths instead of using ${SDCARD}**
   - Build paths are temporary and vary per build

5. **Creating files with wrong ownership**
   - Files created on host owned by build user
   - Files created via chroot commands run as root

6. **Modifying system files directly instead of using overlays**
   - When possible, use framework overlay system

### Example customize-image.sh Template

```bash
#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Customization script for MyBoard

Main() {
    case $RELEASE in
        bookworm|trixie|jammy|noble)
            # Supported releases
            ;;
        *)
            display_alert "Unsupported release" "$RELEASE" "wrn"
            return 0
            ;;
    esac

    case $BOARD in
        myboard*)
            display_alert "Customizing image for" "$BOARD" "info"
            
            # Update package cache
            chroot_sdcard_apt_get_update
            
            # Install packages in batches
            display_alert "Installing" "development tools" "info"
            chroot_sdcard_apt_get_install \
                build-essential cmake git wget curl
            
            display_alert "Installing" "networking tools" "info"
            chroot_sdcard_apt_get_install \
                wireless-tools wpasupplicant iw rfkill
            
            # Create configuration files
            display_alert "Configuring" "network interfaces" "info"
            cat <<-EOF > "${SDCARD}"/etc/network/interfaces.d/wlan0
            allow-hotplug wlan0
            iface wlan0 inet dhcp
                wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
            EOF
            
            # Create helper scripts
            display_alert "Creating" "helper scripts" "info"
            cat <<-'EOFSCRIPT' > "${SDCARD}"/usr/local/bin/my-helper
            #!/bin/bash
            echo "Helper script"
            EOFSCRIPT
            
            chmod +x "${SDCARD}"/usr/local/bin/my-helper
            
            display_alert "Customization complete for" "$BOARD" "info"
            ;;
    esac
}

Main "$@"
```

## Extensions System

### When to Use Extensions vs customize-image.sh

- **customize-image.sh**: Image-specific customizations (packages, configs, files specific to your project)
- **Extensions**: Reusable features across multiple boards (e.g., Docker support, cloud-init, GRUB configs)

### Using Existing Extensions

Enable in board config file (`.csc`, `.conf`, etc.):
```bash
enable_extension "docker-ce"
enable_extension "grub-with-dtb"
```

### Creating Custom Extensions

Place in `userpatches/extensions/myextension.sh`:

```bash
function extension_prepare_config__myextension() {
    # Runs during configuration phase
    # Modify build variables here
    display_alert "Extension loaded" "myextension" "info"
}

function pre_install_kernel_debs__myextension() {
    # Runs before kernel installation
}

function post_install_kernel_debs__myextension() {
    # Runs after kernel installation
    # Common place for kernel module setup
}

function post_family_tweaks__myextension() {
    # Runs during family-specific tweaks
    # Good place for board-specific configs
}

function customize_image__myextension() {
    # Runs during image customization
    # Similar to customize-image.sh but reusable
    display_alert "Customizing via extension" "myextension" "info"
}
```

## Patching Best Practices

### Creating Patches Interactively

1. Run `./compile.sh CREATE_PATCHES=yes`
2. Build proceeds until source extraction, then pauses
3. Navigate to the source directory shown in output
4. Make your changes to the source code
5. Press Enter in the build terminal to continue
6. Patches are auto-generated in `output/patch/`
7. Move patches to appropriate location:
   - Kernel: `userpatches/kernel/<family>-<version>/`
   - U-Boot: `userpatches/u-boot/<family>/`

### Patch Organization

```
userpatches/
└── kernel/
    └── rockchip-vendor-6.1/
        ├── 0001-add-custom-dts.patch
        ├── 0002-enable-custom-driver.patch
        └── 0003-fix-gpio-mapping.patch
```

### Patch Naming Conventions

- Use numeric prefixes: `0001-`, `0002-`, `0003-`, etc.
- Use descriptive names: `0001-add-custom-dts.patch`
- Patches are applied in alphanumeric order
- Keep patch descriptions clear and concise

### Patch Best Practices

1. **One logical change per patch** - Easier to maintain and debug
2. **Test each patch independently** - Ensure it applies cleanly
3. **Document why the patch exists** - In commit message or comment
4. **Regenerate when kernel version changes** - Old patches may not apply

## Board Configuration Files

### Required Variables

```bash
BOARD_NAME="Human Readable Name"
BOARDFAMILY="rockchip"          # SoC family (rockchip, sunxi, meson, etc.)
KERNEL_TARGET="vendor,current"  # Supported kernel branches
BOOT_SOC="rk3506"              # Specific SoC for bootloader
BOOTCONFIG="boardname_defconfig"
BOOT_FDT_FILE="rockchip/boardname.dtb"
```

### Optional but Recommended Variables

```bash
MODULES="module1 module2"        # Kernel modules to load at boot
MODULES_BLACKLIST="badmodule"    # Modules to blacklist
DEFAULT_CONSOLE="serial"         # Console type: "serial" or "both"
SERIALCON="ttyS0"               # Serial console device
BOOT_LOGO="yes"                 # Enable boot logo
```

### Board Config Best Practices

1. **Base on existing similar board** - Copy and modify rather than starting from scratch
2. **Test thoroughly** - Verify boot, peripherals, and network
3. **Document hardware specifics** - Add comments about GPIO pins, interfaces, etc.
4. **Use appropriate kernel branch** - `vendor` for hardware-specific drivers, `current` for mainline

## Testing and Validation

### Pre-Deployment Checklist

Before considering a build "done", verify:

1. ✅ **Build completes without errors** - Check `output/logs/`
2. ✅ **Image boots successfully** - Test on actual hardware
3. ✅ **All packages installed** - Verify with `dpkg -l | grep <package>` or `which <command>`
4. ✅ **Services running** - Check with `systemctl status <service>`
5. ✅ **Hardware functions correctly** - Test WiFi, Ethernet, GPIO, SPI, I2C, etc.
6. ✅ **System logs are clean** - Check `dmesg`, `journalctl -xe` for errors
7. ✅ **Network connectivity works** - Test both wired and wireless if applicable
8. ✅ **Custom scripts execute** - Run any helper scripts created

### Debugging Build Failures

```bash
# Check main build log
cat output/logs/log-build-*.log

# Check detailed debug log
cat output/debug/output.log

# Search for errors
grep -i error output/logs/*.log
grep -i failed output/logs/*.log

# Check customization script execution
grep -A 20 "customize-image.sh" output/logs/*.log

# Check specific package installation
grep "package-name" output/logs/*.log
```

### Debugging Runtime Issues

```bash
# On the device after boot:

# Check system logs
dmesg | less
journalctl -xe

# Check service status
systemctl status networking
systemctl status wpa_supplicant

# Verify package installation
dpkg -l | grep <package>
which <command>

# Check network interfaces
ip a
iw dev
lsusb  # For USB WiFi adapters

# Check loaded kernel modules
lsmod
modinfo <module_name>
```

## Performance Optimization

### Faster Build Iteration

1. **Disable compression during development**: `COMPRESS_OUTPUTIMAGE=img`
   - Avoid xz/gz compression which adds significant time
   
2. **Use incremental builds**: Don't use `CLEAN_LEVEL` unless necessary
   - Reuses cached artifacts from previous builds
   
3. **Build kernel separately**: `KERNEL_ONLY=yes` when only kernel changes
   - Much faster than full image build
   
4. **Never clean sources cache unnecessarily**: `cache/sources/` contains downloaded repos
   - Only clean if you suspect corruption

5. **Use local mirror for packages** (optional, advanced):
   - Set `APT_MIRROR` variable for faster package downloads

### Parallel Builds

```bash
# Framework automatically uses available CPU cores
# Manually limit if needed:
PARALLEL_BUILD=4  # Limit to 4 parallel jobs
```

### Disk Space Management

```bash
# Clean old packages (safe, quick)
./compile.sh CLEAN_LEVEL=debs

# Clean output images (safe, quick)
./compile.sh CLEAN_LEVEL=images

# Clean all build artifacts (safe, moderate)
./compile.sh CLEAN_LEVEL=alldebs,images

# Clean cache (slow, forces full rebuild)
./compile.sh CLEAN_LEVEL=cache  # Only when necessary!
```

## Git Workflow

### Committing Changes

Always include co-author attribution when using Warp Agent:

```bash
git commit -m "Add custom board support for MyBoard

- Added board configuration
- Created customize-image.sh with package installation
- Added kernel patches for GPIO remapping

Co-Authored-By: Warp <agent@warp.dev>"
```

### What to Commit to Version Control

✅ **Do commit:**
- `userpatches/` directory and all contents
- Documentation (README, WARP.md, build guides)
- Custom build scripts (build-*.sh, start-build.sh)
- Board-specific documentation

❌ **Do not commit:**
- `output/` directory (build artifacts, images, packages)
- `cache/` directory (downloaded sources, toolchains)
- `.tmp/` directory (temporary build files)
- Large binary files (images, .deb packages)

### Recommended .gitignore

```gitignore
# Build artifacts
output/
cache/
.tmp/

# Temporary files
*.log
*.tmp
*~

# OS files
.DS_Store
Thumbs.db
```

## Common Issues and Solutions

### Issue: Packages not installed in final image

**Symptoms**: Running `which <package>` or `dpkg -l | grep <package>` shows package missing

**Cause**: Using incorrect function in customize-image.sh

**Solution**: Use `chroot_sdcard_apt_get_install` not `chroot $SDCARD apt-get install` or `apt-get install`

**Debugging**:
```bash
# Check if customize script ran
grep "customize-image.sh" output/logs/*.log

# Check for package installation attempts
grep "Installing.*package-name" output/logs/*.log
```

### Issue: Changes to customize-image.sh not applied

**Symptoms**: Modified script but changes don't appear in image

**Cause**: Incremental build using cached rootfs

**Solution**: Clean and rebuild
```bash
./compile.sh CLEAN_LEVEL=cache docker BOARD=yourboard BRANCH=vendor RELEASE=bookworm
```

### Issue: Script runs but changes are missing

**Symptoms**: Logs show script executed but files/configs not present

**Cause**: 
- Syntax error in script (bash continues on errors)
- Wrong variable usage (e.g., missing `${SDCARD}`)
- Incorrect path

**Solution**: Add error checking and verification
```bash
# In customize-image.sh, add checks:
if ! chroot_sdcard_apt_get_install mypackage; then
    display_alert "Package installation failed" "mypackage" "err"
    return 1
fi

# Verify file creation
if [ ! -f "${SDCARD}"/etc/myconfig ]; then
    display_alert "Config file not created" "/etc/myconfig" "err"
fi
```

### Issue: Patch fails to apply

**Symptoms**: Build fails with "patch does not apply" error

**Cause**: 
- Kernel version changed
- Source code changed upstream
- Patch context doesn't match

**Solution**: Regenerate patch
```bash
./compile.sh CREATE_PATCHES=yes BOARD=yourboard BRANCH=vendor
# Make changes again
# Press Enter to generate new patch
```

### Issue: Build extremely slow on macOS

**Symptoms**: First build takes 3-4+ hours

**Cause**: Docker filesystem performance on macOS

**Solution**: This is expected behavior
- First build: 2-4 hours (downloads toolchains, sources, builds everything)
- Subsequent builds: 30-60 minutes (uses cache)
- Consider building on Linux if speed is critical

### Issue: Out of disk space during build

**Symptoms**: Build fails with "No space left on device"

**Cause**: Cache and build artifacts consume significant space

**Solution**: Clean old artifacts
```bash
# Check disk usage
du -sh cache/ output/

# Clean old packages and images
./compile.sh CLEAN_LEVEL=debs,images

# If desperate, clean everything (forces full rebuild)
./compile.sh CLEAN_LEVEL=cache,sources
```

### Issue: WiFi/Network drivers not loading

**Symptoms**: `lsmod` doesn't show expected modules, `iw dev` shows no interfaces

**Cause**: 
- Modules not in kernel
- Firmware missing
- Modules not loaded at boot

**Solution**:
```bash
# On device, check if module exists
modprobe <module_name>

# If that works, add to modules-load.d in customize-image.sh:
cat <<-EOF > "${SDCARD}"/etc/modules-load.d/wifi.conf
rtl8xxxu
8821cu
EOF

# Install firmware packages in customize-image.sh:
chroot_sdcard_apt_get_install firmware-realtek firmware-ralink linux-firmware
```

## Platform-Specific Notes

### macOS Development

- **Docker is REQUIRED** - Native builds not supported on macOS
- Install Docker Desktop: `brew install --cask docker`
- Requires modern Bash: `brew install bash coreutils git`
- Build system automatically uses Docker when on macOS
- Cannot run as root on macOS (not needed, don't use `sudo`)
- File sharing with Docker is slow - first builds take significantly longer

### Linux Development

- **Native builds supported** - No Docker required
- Use Ubuntu 22.04+ or Debian 11+ for best compatibility
- Some dependencies may need manual installation on first run
- Much faster than macOS Docker builds

### Build Time Expectations

| Platform | First Build | Subsequent Builds | Multiple Boards |
|----------|-------------|-------------------|-----------------|
| Linux    | 1-2 hours   | 15-30 minutes     | 2-4 hours       |
| macOS    | 2-4 hours   | 30-60 minutes     | 4-6 hours       |

### Disk Space Requirements

| Purpose           | Minimum | Recommended |
|-------------------|---------|-------------|
| Single board      | 30GB    | 50GB        |
| Multiple boards   | 50GB    | 100GB+      |
| Active development| 100GB   | 200GB+      |

## Additional Resources

### Official Documentation
- Main docs: https://docs.armbian.com/Developer-Guide_Overview/
- Build options: https://docs.armbian.com/Developer-Guide_Build-Options/
- Build preparation: https://docs.armbian.com/Developer-Guide_Build-Preparation/
- User configurations: https://docs.armbian.com/Developer-Guide_User-Configurations/

### Community
- Forums: https://forum.armbian.com
- GitHub: https://github.com/armbian/build
- IRC: #armbian on Libera.Chat

### Example Projects
- Armbian userpatches: https://github.com/armbian/os/tree/main/userpatches
- Community projects: https://github.com/armbian/community

---

## Quick Reference Card

### Essential Commands
```bash
# Interactive build
./compile.sh

# Non-interactive build
./compile.sh docker BOARD=name BRANCH=vendor RELEASE=bookworm

# Kernel only
./compile.sh KERNEL_ONLY=yes BOARD=name BRANCH=vendor

# Create patches
./compile.sh CREATE_PATCHES=yes

# Clean specific items
./compile.sh CLEAN_LEVEL=images,debs
```

### Essential Functions (in customize-image.sh)
```bash
chroot_sdcard_apt_get_update                    # Update apt cache
chroot_sdcard_apt_get_install pkg1 pkg2         # Install packages
display_alert "message" "details" "info"        # Log message
cat <<-EOF > "${SDCARD}"/path/to/file           # Create file
chmod +x "${SDCARD}"/path/to/script             # Make executable
```

### Essential Variables
- `$SDCARD` - Root of image filesystem
- `$BOARD` - Board name
- `$RELEASE` - Distribution release (bookworm, jammy, etc.)
- `$BRANCH` - Kernel branch (vendor, current, edge)

### Debugging Locations
- Build logs: `output/logs/log-build-*.log`
- Debug output: `output/debug/output.log`
- Built images: `output/images/`
- Packages: `output/debs/`
