# Stella BLE Protocol Specification

Firmware version: 1.0.0

## Overview

The Stella exposes two BLE services:

1. **Nordic UART Service (NUS)** — used for the Apple Nearby Interaction (NI) handshake
2. **Stella Application Service** — battery, commands, and device info

Both services are advertised simultaneously. The NUS service is managed by the StellaUWB library; the application service is managed by the firmware.

## Device Name

Each Stella advertises as `Stella-XXYY` where `XXYY` are the uppercase hex digits of the last two bytes of its BLE MAC address. Example: a device with MAC `70:3C:2C:59:35:AB` advertises as `Stella-35AB`.

The base name `Stella` appears in the scan response alongside the application service UUID.

---

## Service 1: Nordic UART Service (NUS)

Used for the Apple Nearby Interaction TLV command exchange.

| Field | Value |
|-------|-------|
| Service UUID | `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` |
| RX Characteristic | `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` |
| TX Characteristic | `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` |

**RX** (phone writes to this): `Write Without Response`
**TX** (phone reads/subscribes to this): `Read`, `Notify`

### NI Protocol Commands (phone → Stella, written to RX)

| Byte 0 | Meaning |
|--------|---------|
| `0x0A` | Initialize iOS — phone requests the accessory's NI configuration blob |
| `0x0B` | Configure and Start — phone sends its share token to begin UWB ranging |
| `0x0C` | Stop — phone requests ranging to stop |

### NI Protocol Responses (Stella → phone, notified on TX)

| Byte 0 | Meaning |
|--------|---------|
| `0x01` | Initialized Data — accessory's NI configuration blob (variable length) |
| `0x02` | UWB Did Start — ranging session is active |
| `0x03` | UWB Did Stop — ranging session ended |

The iOS app should:
1. Discover the NUS service and subscribe to TX notifications
2. Write `0x0A` to RX
3. Receive `0x01` + configuration blob on TX
4. Create `NINearbyAccessoryConfiguration` from the blob and start an `NISession`
5. Write `0x0B` + the phone's share token to RX
6. Receive `0x02` on TX when UWB ranging begins

---

## Service 2: Stella Application Service

| Field | Value |
|-------|-------|
| Service UUID | `A0E9F8B0-1234-5678-ABCD-0123456789AB` |

### Characteristics

#### Battery (`A0E9F8B3-...0123456789AB`)

| Property | Value |
|----------|-------|
| Permissions | Read, Notify |
| Size | 1 byte |
| Format | `uint8` — battery percentage (0–100) |

The firmware updates this value:
- Once at boot
- On BLE connection
- Every 30 seconds while connected
- On `CMD_PING`

The value is derived from the nRF52840's supply voltage measured via the internal SAADC VDD channel. On USB-C power the reading is ~3300 mV, which clamps to 100%. On CR2032 battery, 3000 mV = 100%, 2000 mV = 0%.

#### Command (`A0E9F8B4-...0123456789AB`)

| Property | Value |
|----------|-------|
| Permissions | Write |
| Size | 1–2 bytes |
| Format | byte 0 = command code, byte 1 = parameter (optional, defaults to 0) |

##### Command Codes

| Code | Name | Parameter | Behavior |
|------|------|-----------|----------|
| `0x01` | Play Sound | Duration in seconds. `0` = default (3 s). | Drives the buzzer at 4 kHz for the given duration. |
| `0x02` | Stop Sound | — | Stops the buzzer immediately. |
| `0x03` | LED On | — | No-op (pin 13 conflicts with SPI). |
| `0x04` | LED Off | — | No-op (pin 13 conflicts with SPI). |
| `0x05` | Set Ranging Rate | Rate in Hz, clamped to 1–10. | Stores the requested UWB ranging frequency. |
| `0x06` | Ping | — | Triggers an immediate battery level update (refreshes the battery characteristic). |

Writing an unrecognized command code is silently ignored.

#### Device Info (`A0E9F8B5-...0123456789AB`)

| Property | Value |
|----------|-------|
| Permissions | Read |
| Size | Up to 64 bytes |
| Format | UTF-8 JSON string |

Written once at boot. Current value:

```json
{"fw":"1.0.0","hw":"ABX00131"}
```

---

## Connection Flow (iOS)

1. Scan for peripherals advertising the name prefix `Stella-`
2. Connect to the peripheral
3. Discover services: expect both `6E400001-...` (NUS) and `A0E9F8B0-...` (app service)
4. Discover characteristics on both services
5. Subscribe to notifications on:
   - NUS TX (`6E400003-...`) — for NI protocol responses
   - Battery (`A0E9F8B3-...`) — for battery updates
6. Wait for the TX subscription confirmation (`didUpdateNotificationState`)
7. Write `0x0A` to NUS RX to start the NI handshake
8. Read Device Info (`A0E9F8B5-...`) for firmware and hardware version
9. After ranging is established, write `0x01` to Command to play the buzzer as needed

## Disconnection Behavior

- On BLE disconnect, the firmware stops any active UWB ranging session
- BLE advertising continues automatically after disconnection
- The firmware tracks a connection count; multiple simultaneous connections are supported by the BLE stack but only one NI session runs at a time
