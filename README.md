# StellaTrack

A UWB-based proximity tracking system consisting of an iOS app and Arduino firmware for the Stella accessory. Uses Bluetooth Low Energy for connectivity and Apple's Nearby Interaction framework for sub-meter distance measurement.

## Repository Structure

```
StellaTrack/
├── ios/          # iOS app (SwiftUI, Core Bluetooth, Nearby Interaction, ARKit)
├── firmware/     # Stella accessory firmware (Arduino/PlatformIO, Qorvo DW3000)
```

## Components

### iOS App (`ios/`)

SwiftUI app that discovers, connects to, and tracks Stella accessories. Features include real-time distance and direction display on a map, configurable separation alerts with local notifications, ARKit camera-assisted direction finding for iPhone 14+, and background BLE/UWB operation.

See [ios/README.md](ios/README.md) for setup, architecture, and build instructions.

### Stella Firmware (`firmware/`)

PlatformIO-based firmware for the Stella accessory board (nRF52840 + Qorvo DW3000). Implements the Apple Nearby Interaction Accessory Protocol over BLE, along with battery reporting, buzzer commands, and power management.

See [firmware/README.md](firmware/README.md) for build instructions and hardware details.
See [firmware/PROTOCOL.md](firmware/PROTOCOL.md) for the BLE/NI protocol specification.

## Requirements

- **iOS App**: Xcode 15+, iOS 16+, iPhone with U1 chip (iPhone 11+)
- **Firmware**: PlatformIO, nRF52840-based board with Qorvo DW3000 UWB module

## License

This project is part of Georgia Tech coursework.
