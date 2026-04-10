# StellaTrack

An iOS app that tracks the distance to nearby Bluetooth/UWB accessories and alerts the user when they move too far away. Built with SwiftUI, Core Bluetooth, Nearby Interaction, and ARKit.

## Features

- **Map-first UI** — Devices appear as pins on a live map with real-time distance updates
- **Stella BLE + UWB ranging** — Connects to Stella accessories (Qorvo DW3000-based) via the Apple Nearby Interaction Accessory Protocol for sub-meter distance measurement
- **ARKit camera-assisted direction** — Opt-in direction finding for iPhone 14+ (single UWB antenna) using headless ARKit with convergence coaching
- **Separation alerts** — Configurable distance thresholds with persistence timers; local notifications fire when the alert level is reached, even in the background
- **Background operation** — BLE central, Nearby Interaction, and location background modes keep tracking active when the app is suspended
- **Play sound** — Trigger the accessory's buzzer remotely to locate it
- **Mock devices** — Drag-and-drop simulated devices on the map for testing without hardware
- **Distance history** — Per-device timeseries chart with file-based persistence across launches
- **Battery monitoring** — Reads and displays accessory battery level via BLE

## Requirements

- iOS 16.0+
- iPhone with U1 chip (iPhone 11 or later) for UWB ranging
- Xcode 15+
- Swift 5.0+
- A Stella-compatible UWB accessory for hardware testing (mock devices work without one)

## Getting Started

1. Clone the repository
2. Open `StellaTrack.xcodeproj` in Xcode
3. Select your development team under Signing & Capabilities
4. Build and run on a physical device (UWB is not available in the Simulator)

### Permissions

The app requests the following permissions at runtime:

| Permission | Purpose |
|---|---|
| Bluetooth | Discover and communicate with Stella accessories |
| Location (When In Use) | Show user position on the map and compute mock distances |
| Location (Always) | Background distance alerts for mock devices |
| Camera | ARKit camera assistance for direction finding (no camera UI shown) |
| Notifications | Separation and disconnect alerts |

## Architecture

```
StellaTrack/
├── StellaTrackApp.swift    # App entry, environment wiring, scene phase handling
├── Engine/
│   ├── DeviceManager.swift         # Orchestrates devices, BLE central, persistence
│   └── AlertEngine.swift           # Distance threshold logic, alert levels, history
├── Models/
│   ├── SeparationModels.swift      # DistanceReading, ConnectionStatus
│   ├── TrackedDevice.swift         # Per-device aggregate (provider + alert + history)
│   ├── DistanceHistory.swift       # Timeseries storage with file persistence
│   ├── DiscoveredStella.swift      # BLE scan result model
│   └── AlertState.swift            # Alert level enum and settings
├── Providers/
│   ├── DistanceProvider.swift      # Protocol: distance/connection/battery publishers
│   ├── StellaDistanceProvider.swift# BLE + NI + ARKit implementation for Stella
│   ├── MockDistanceProvider.swift  # Location-based simulated distance
│   └── StubDistanceProvider.swift  # Inert provider for restored devices
├── Services/
│   ├── StellaConstants.swift       # BLE UUIDs, NI command/response byte protocol
│   ├── StellaScanner.swift         # BLE peripheral scanning
│   ├── StellaPairingManager.swift  # Pairing flow coordinator
│   ├── LocationManager.swift       # CLLocationManager wrapper with background support
│   ├── MotionManager.swift         # Device orientation (flat detection for TrackView)
│   ├── NotificationService.swift   # Local notification scheduling
│   ├── PersistenceService.swift    # UserDefaults device record storage
│   └── BLEDebugLog.swift           # In-app BLE diagnostic log
└── Views/
    ├── MapHomeView.swift           # Root view: map + device list sheet
    ├── DeviceCardView.swift        # Device list row with signal/status indicators
    ├── DevicePageDrawer.swift      # Device detail sheet (alert, sound, track buttons)
    ├── TrackView.swift             # Full-screen direction + distance tracking
    ├── DistanceChartView.swift     # Distance history chart
    ├── AddDeviceSheet.swift        # Add mock or scan for Stella
    ├── StellaScanOverlay.swift     # BLE scan UI
    ├── EditDeviceSheet.swift       # Rename / change icon
    ├── AlertSettingsWindowOverlay.swift  # Alert threshold configuration
    ├── BatteryIndicatorView.swift  # Battery level icon
    ├── BLELogView.swift            # Debug log viewer
    └── ...
```

### Key Protocols

**`DistanceProvider`** — The core abstraction. Each tracked device has a provider that publishes:
- `distancePublisher` — `DistanceReading` (distance, direction, timestamp)
- `connectionStatusPublisher` — `.disconnected` / `.searching` / `.connected` / `.ranging`
- `batteryLevelPublisher` — Optional battery percentage

Concrete implementations: `StellaDistanceProvider` (real hardware), `MockDistanceProvider` (simulated), `StubDistanceProvider` (placeholder for restored devices before reconnect).

**`CentralManaging` / `PeripheralManaging`** — Abstractions over `CBCentralManager` and `CBPeripheral` for testability.

### Stella BLE Protocol

The app communicates with Stella accessories over two BLE services:

| Service | Purpose |
|---|---|
| Nordic UART (NUS) | NI accessory protocol: config exchange, shareable config data |
| Stella Custom Service | Battery level, device commands (play/stop sound), device info |

The NI protocol flow:
1. App sends `init` command via NUS RX characteristic
2. Accessory responds with NI config data via NUS TX
3. App creates `NINearbyAccessoryConfiguration` and runs `NISession`
4. Framework calls `didGenerateShareableConfigurationData` — app sends this back to accessory
5. Ranging begins: `session(_:didUpdate:)` delivers distance and direction

### Camera Assistance (iPhone 14+)

iPhone 14 and later have a single UWB antenna, so `supportsDirectionMeasurement` returns `false`. The app uses ARKit camera assistance as an opt-in feature when the user opens TrackView:

1. Sets `isCameraAssistanceEnabled = true` on the NI config
2. The framework creates an internal ARSession (no camera preview shown)
3. `didUpdateAlgorithmConvergence` provides coaching (e.g. "Move your iPhone around slowly")
4. Once converged, `horizontalAngle` becomes available and is converted to a direction vector

## Testing

```bash
xcodebuild test \
  -project StellaTrack.xcodeproj \
  -scheme StellaTrack \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Test coverage includes:
- `AlertEngine` threshold and persistence logic
- `DeviceManager` add/remove/restore flows
- `StellaDistanceProvider` BLE delegate handling, peripheral swap, battery subscription
- `DistanceHistory` save/load/delete persistence
- `StellaScanner` and `StellaPairingManager` state machines
- `StellaConstants` UUID and command byte validation

## Background Modes

Configured in `Info.plist`:

| Mode | Purpose |
|---|---|
| `bluetooth-central` | Maintain BLE connections and receive data while backgrounded |
| `nearby-interaction` | Continue UWB ranging sessions in the background |
| `location` | Background location updates for mock device distance alerts |

## License

This project is part of Georgia Tech coursework.
