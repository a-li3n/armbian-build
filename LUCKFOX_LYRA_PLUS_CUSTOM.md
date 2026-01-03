# Luckfox Lyra Plus Custom - GPIO Pin Mapping

This is a custom variant of the Luckfox Lyra Plus with remapped GPIO pins for SPI, I2C, and UART interfaces.

## Custom GPIO Pin Assignments

### SPI0 Interface
| Function | GPIO Pin | Linux GPIO Number | Notes |
|----------|----------|-------------------|-------|
| CS (Chip Select) | GPIO1_B1 | 41 | Software controlled |
| RESET | GPIO1_B2 | 42 | Active low |
| SCK (Clock) | GPIO1_B3 | 43 | SPI clock signal |
| MOSI (Master Out) | GPIO1_C2 | 50 | Data out from master |
| MISO (Master In) | GPIO1_C3 | 51 | Data in to master |
| IRQ (Interrupt) | GPIO1_D2 | 58 | Interrupt request, active low |
| BUSY | GPIO1_D3 | 59 | Busy signal, active high |

### I2C1 Interface
| Function | GPIO Pin | Linux GPIO Number | Notes |
|----------|----------|-------------------|-------|
| SCL (Clock) | GPIO0_A2 | 2 | I2C clock with pull-up |
| SDA (Data) | GPIO0_A3 | 3 | I2C data with pull-up |

### UART1 Interface
| Function | GPIO Pin | Linux GPIO Number | Notes |
|----------|----------|-------------------|-------|
| TX (Transmit) | GPIO0_A6 | 6 | Serial transmit |
| RX (Receive) | GPIO0_A7 | 7 | Serial receive |

## GPIO Number Calculation

Rockchip GPIO pins are numbered as: `bank * 32 + group * 8 + pin`

Where:
- GPIO0_A0 = 0, GPIO0_A1 = 1, ... GPIO0_A7 = 7
- GPIO0_B0 = 8, GPIO0_B1 = 9, ... GPIO0_B7 = 15
- GPIO1_A0 = 32, GPIO1_B0 = 40, GPIO1_C0 = 48, GPIO1_D0 = 56

## Building the Custom Image

```bash
./compile.sh docker \
    BOARD=luckfox-lyra-plus-custom \
    BRANCH=vendor \
    RELEASE=bookworm \
    BUILD_MINIMAL=no \
    BUILD_DESKTOP=no \
    KERNEL_CONFIGURE=no \
    COMPRESS_OUTPUTIMAGE=sha,gpg,img
```

Or use the helper script:

```bash
./build-lyra-images.sh --board luckfox-lyra-plus-custom
```

## Device Tree Details

The custom device tree is defined in:
- Device tree source: `arch/arm/boot/dts/rk3506g-luckfox-lyra-plus-custom-sd.dts`
- Patch file: `userpatches/kernel/rk35xx-vendor-6.1/9999-add-luckfox-lyra-plus-custom.patch`
- Board config: `config/boards/luckfox-lyra-plus-custom.csc`

## Accessing GPIO in Linux

### Using sysfs (legacy method)
```bash
# Export GPIO (e.g., SPI0_RESET = GPIO1_B2 = 42)
echo 42 > /sys/class/gpio/export

# Set direction
echo out > /sys/class/gpio/gpio42/direction

# Set value
echo 1 > /sys/class/gpio/gpio42/value

# Unexport when done
echo 42 > /sys/class/gpio/unexport
```

### Using libgpiod (modern method)
```bash
# List GPIO chips
gpiodetect

# Get GPIO line info
gpioinfo gpiochip1

# Set GPIO high
gpioset gpiochip1 42=1

# Read GPIO value
gpioget gpiochip1 58
```

### Using Python (periphery library)
```python
from periphery import GPIO

# SPI0_RESET (GPIO1_B2 = pin 42)
reset_gpio = GPIO(42, "out")
reset_gpio.write(True)  # Set high
reset_gpio.close()

# SPI0_IRQ (GPIO1_D2 = pin 58)
irq_gpio = GPIO(58, "in")
value = irq_gpio.read()
irq_gpio.close()
```

## SPI Device Access

The SPI device will appear as `/dev/spidev0.0` with the following GPIO pins available:

```bash
# In your application, access the GPIOs via the device tree properties:
# - reset-gpios: GPIO1_B2 (pin 42)
# - irq-gpios: GPIO1_D2 (pin 58)
# - busy-gpios: GPIO1_D3 (pin 59)
```

## I2C Device Access

The I2C bus will appear as `/dev/i2c-1`:

```bash
# Scan for I2C devices
i2cdetect -y 1

# Read from I2C device at address 0x3d
i2cget -y 1 0x3d 0x00
```

## UART Device Access

The UART will appear as `/dev/ttyS1`:

```bash
# Set baud rate
stty -F /dev/ttyS1 ispeed 115200 ospeed 115200

# Send data
echo "Hello" > /dev/ttyS1

# Read data (requires terminal program)
cat /dev/ttyS1
```

## Pin Multiplexing Notes

The Rockchip Matrix IO system allows flexible pin assignment. The mux values used in the device tree are:
- **0**: GPIO function
- **16**: UART function
- **17**: UART function (RX)
- **32**: I2C function (SCL)
- **33**: I2C function (SDA)
- **48**: SPI function (SCK)
- **49**: SPI function (MOSI)
- **50**: SPI function (MISO)

You can verify the current pin mux setting with:
```bash
# Check GPIO0_A2 mux (should be 32 for I2C)
iomux 0 2

# Check GPIO1_B3 mux (should be 48 for SPI SCK)
iomux 1 11
```

## Hardware Differences from Standard Lyra Plus

This custom variant uses the same hardware as the standard Luckfox Lyra Plus but with different GPIO pin assignments in software. The physical board is identical - only the device tree configuration differs.

## Troubleshooting

If interfaces don't work:
1. Check device tree was properly applied: `dmesg | grep -i "luckfox lyra plus custom"`
2. Verify pin mux settings with `iomux` command
3. Check that the device files exist (`/dev/spidev0.0`, `/dev/i2c-1`, `/dev/ttyS1`)
4. Verify GPIO exports: `ls /sys/class/gpio/`

## References

- [Luckfox Wiki](https://wiki.luckfox.com/Luckfox-Lyra/)
- [Armbian Build Guide](./LUCKFOX_LYRA_BUILD_GUIDE.md)
- [Rockchip RK3506 Datasheet](https://files.luckfox.com/wiki/Luckfox/RK3506/PDF/)
