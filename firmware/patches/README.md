# StellaUWB Library Patches

These patches modify the StellaUWB library installed in `.pio/libdeps/`.
They must be reapplied after any `pio lib install` or library update.

## Patches

### 001-stop-session-on-disconnect.patch
Uncomments `handleStopSession()` in `blePeripheralDisconnectHandler` so the
UWB session on the SR040 chip is properly torn down when the BLE client
disconnects. Without this, reconnecting fails because the old session is
still active on the chip.

### 001b-stop-session-before-reconfigure.patch
Stops and deinitializes any active UWB session before starting a new one
when `kMsg_ConfigureAndStart` is received. Without this, session updates
(e.g. enabling ARKit camera assistance) cause an SPI write failure on
the SR040 because the old session is still active.

### 001c-cached-config-on-session-update.patch
After a session starts, writes the real cached accessory config to the
GATT characteristic instead of zeros. Also re-sends the cached config
when `kMsg_Initialize_iOS` arrives while a session is already running,
instead of regenerating from the SR040 via SPI each time. Prevents the
iPhone from looping init requests that exhaust the SPI bus.

### 002-uwb-role-responder.patch
Changes the accessory's UWB ranging role from INITIATOR to RESPONDER and
device type from CONTROLLER to CONTROLEE. RESPONDER is the standard role
for NI accessories per the Apple/FiRa protocol.

## Applying

Run from the `firmware/` directory (this repo’s PlatformIO root):

```
python patches/apply_patches.py
```

Or manually edit the files listed in each `.patch` description.
