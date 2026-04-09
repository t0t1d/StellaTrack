# StellaUWB Library Patches

These patches modify the StellaUWB library installed in `.pio/libdeps/`.
They must be reapplied after any `pio lib install` or library update.

## Patches

### 001-stop-session-on-disconnect.patch
Uncomments `handleStopSession()` in `blePeripheralDisconnectHandler` so the
UWB session on the SR040 chip is properly torn down when the BLE client
disconnects. Without this, reconnecting fails because the old session is
still active on the chip.

### 002-uwb-role-responder.patch
Changes the accessory's UWB ranging role from INITIATOR to RESPONDER and
device type from CONTROLLER to CONTROLEE. RESPONDER is the standard role
for NI accessories per the Apple/FiRa protocol.

## Applying

Run from `stella-firmware/`:

```
python patches/apply_patches.py
```

Or manually edit the files listed in each `.patch` description.
