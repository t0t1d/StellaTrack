# Stella Firmware

Firmware for the [Arduino Stella (ABX00131)](https://store-usa.arduino.cc/products/stella) — a Bluetooth + UWB tag built on the nRF52840 and Truesense DCU040 module. Designed for item finding and separation awareness with iOS via Apple's Nearby Interaction protocol.

## What It Does

- Advertises over BLE so an iPhone can discover and connect
- Runs Apple Nearby Interaction (NI) ranging over UWB for centimeter-level distance
- Reports battery level (CR2032 coin cell) to the connected phone
- Plays a 4 kHz buzzer on command (find-my-device)
- Each device advertises with a unique name derived from its BLE MAC address (e.g. `Stella-35AB`)

## Hardware

- **MCU:** Nordic nRF52840 (Cortex-M4, 64 MHz)
- **UWB:** Truesense DCU040 (NXP SR040), channels 5 & 9
- **Battery:** CR2032 coin cell (2.0–3.0 V)
- **Peripherals:** Buzzer (4 kHz), user button, power LED
- **Connectivity:** BLE 5.0, USB-C (power + programming)

## Prerequisites

- [PlatformIO CLI](https://docs.platformio.org/en/latest/core/installation.html) or the VS Code extension
- USB-C cable

## Building

```bash
# Full firmware
pio run -e stella

# Diagnostic build (UWB + NUS only, no custom services)
pio run -e stella-diag

# Run unit tests (desktop)
pio test -e native
```

## Flashing

Connect the Stella via USB-C, then:

```bash
pio run -e stella --target upload
```

If the port isn't detected automatically:

```bash
pio run -e stella --target upload --upload-port COM5
```

## Serial Monitor

```bash
pio device monitor -b 115200
```

On boot you'll see:

```
[Stella] Firmware starting...
[Stella] FW=1.0.0 HW=ABX00131
[Stella] Boot VDD: 2950mV
[Stella] Starting BLE...
[Stella] BLE OK
[Stella] Name: Stella-35AB
[Stella] UWB init attempt 1/3...
[Stella] UWB.state() = 0
[Stella] UWB ready
[Stella] battery 2950mV pct=95
[Stella] Ready.
```

The heartbeat prints every 5 seconds:

```
[Stella] alive t=10s conns=0 vdd=2940mV ranging=no
```

## Project Structure

```
stella-firmware/
├── include/
│   ├── config.h              # UUIDs, pins, constants
│   ├── power_manager.h       # Battery + motion tracking
│   ├── commands.h            # Buzzer / LED command handler
│   ├── button_handler.h      # Debounced button with short/long press
│   ├── bonding_manager.h     # In-RAM pairing state
│   └── led_indicator.h       # LED blink patterns
├── src/
│   ├── main.cpp              # Entry point (setup/loop), BLE + UWB init
│   ├── power_manager.cpp
│   ├── commands.cpp
│   ├── button_handler.cpp
│   ├── bonding_manager.cpp
│   ├── led_indicator.cpp
│   ├── ble_service.cpp       # BLE service abstraction (HAL-based)
│   ├── firmware_controller.cpp
│   └── hal/                  # Hardware abstraction layer
│       ├── gpio_hal.h        # IGpioHal interface
│       ├── arduino_gpio_hal.h
│       ├── accel_hal.h       # IAccelHal interface
│       ├── sc7a20_accel_hal.h
│       ├── ble_hal.h         # IBleHal interface
│       └── arduino_ble_hal.h
├── test/
│   ├── mocks/                # Mock HAL implementations for desktop tests
│   ├── test_power_manager/
│   ├── test_commands/
│   ├── test_ble_service/
│   ├── test_button/
│   ├── test_bonding/
│   ├── test_config/
│   ├── test_integration/
│   ├── test_led_indicator/
│   └── test_uwb_session/
├── boards/
│   └── stella.json           # Custom board definition
└── platformio.ini
```

## Boot Sequence

1. LED turns on (shows the board is alive)
2. Serial init with 2-second timeout
3. Reads supply voltage via nRF52840 internal SAADC
4. Starts BLE, sets unique name from MAC address
5. Registers custom GATT service and characteristics
6. Initializes UWB with up to 3 retries
7. Initializes button, buzzer, bonding
8. Writes initial battery percentage
9. LED turns off — device is ready

## Known Constraints

- `s_power.begin()` (accelerometer via I2C) is skipped because `Wire.begin()` shares a hardware instance with UWB SPI on the nRF52840. Motion detection is disabled.
- Pin 13 (`PIN_LED_USER`) is also `SPI_SCK` — LED commands (`CMD_LED_ON`/`CMD_LED_OFF`) are a no-op until an alternative LED pin is identified.
- `analogRead()` must only target pin A6 (`BATTERY_ADC_PIN`). Scanning other analog pins reconfigures UWB SPI GPIOs to analog mode, breaking UWB permanently until reset. *(Battery is now read via the internal VDD channel, so `analogRead()` is no longer used.)*

## BLE Protocol

See [PROTOCOL.md](PROTOCOL.md) for the full BLE service and characteristic specification.

## License

This project is not yet licensed. Contact the maintainer before reuse.
