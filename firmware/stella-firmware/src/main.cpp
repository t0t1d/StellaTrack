#ifdef STELLA_TARGET

#include <ArduinoBLE.h>
#include <StellaUWB.h>

// ============================================================
// DIAG_NEARBY_ONLY: UWB diagnosis build
// Build with: pio run -e stella-diag
// Initializes UWB in setup() with retries, not in BLE callback
// ============================================================
#ifdef DIAG_NEARBY_ONLY

static uint16_t numConnected = 0;
static bool uwb_ready = false;

static void rangingHandler(UWBRangingData& rangingData) {
    if (rangingData.measureType() !=
        static_cast<uint8_t>(uwb::MeasurementType::TWO_WAY))
        return;
    RangingMeasures twr = rangingData.twoWayRangingMeasure();
    for (int j = 0; j < rangingData.available(); j++) {
        if (twr[j].status == 0 && twr[j].distance != 0xFFFF) {
            Serial.print("Distance: ");
            Serial.println(twr[j].distance);
        }
    }
}

static void clientConnected(BLEDevice dev) {
    Serial.print("[DIAG] BLE connected: ");
    Serial.println(dev.address());
    Serial.print("[DIAG] UWB ready: ");
    Serial.println(uwb_ready ? "YES" : "NO");
    numConnected++;
}

static void clientDisconnected(BLEDevice dev) {
    Serial.print("[DIAG] BLE disconnected: ");
    Serial.println(dev.address());
    if (numConnected > 0) numConnected--;
}

static void sessionStarted(BLEDevice) {
    Serial.println("[DIAG] UWB session STARTED");
}

static void sessionStopped(BLEDevice) {
    Serial.println("[DIAG] UWB session STOPPED");
}

static bool tryUwbInit() {
    Serial.println("[DIAG] Calling UWB.begin()...");
    UWB.begin();
    uint8_t st = UWB.state();
    Serial.print("[DIAG] UWB.state() = ");
    Serial.println(st);
    return (st == 0);
}

void setup() {
    pinMode(LED_PWR, OUTPUT);
    digitalWrite(LED_PWR, HIGH);

    Serial.begin(115200);
    unsigned long t0 = millis();
    while (!Serial && (millis() - t0 < 2000)) delay(10);

    Serial.println("=== DIAG: UWB early-init with retries ===");

    UWB.registerRangingCallback(rangingHandler);
    UWBNearbySessionManager.onConnect(clientConnected);
    UWBNearbySessionManager.onDisconnect(clientDisconnected);
    UWBNearbySessionManager.onSessionStart(sessionStarted);
    UWBNearbySessionManager.onSessionStop(sessionStopped);

    UWBNearbySessionManager.begin("TS_DCU040");

    // Build unique name from BLE MAC (available after begin).
    {
        String mac = BLE.address();
        if (mac.length() >= 17) {
            static char name[20];
            snprintf(name, sizeof(name), "TS_DCU040-%c%c%c%c",
                     toupper(mac.charAt(12)), toupper(mac.charAt(13)),
                     toupper(mac.charAt(15)), toupper(mac.charAt(16)));
            BLE.setLocalName(name);
            BLE.setDeviceName(name);
            Serial.print("[DIAG] Name: ");
            Serial.println(name);
        }
    }

    // Try UWB init in setup with retries (not in BLE callback)
    for (int attempt = 1; attempt <= 3; attempt++) {
        Serial.print("[DIAG] UWB init attempt ");
        Serial.print(attempt);
        Serial.println("/3");
        if (tryUwbInit()) {
            uwb_ready = true;
            Serial.println("[DIAG] UWB initialized OK!");
            break;
        }
        Serial.println("[DIAG] UWB init FAILED, retrying after 2s...");
        UWB.end();
        delay(2000);
    }

    if (!uwb_ready) {
        Serial.println("[DIAG] === UWB INIT FAILED after 3 attempts ===");
        Serial.println("[DIAG] Possible causes:");
        Serial.println("[DIAG]   1. NXP SR040 chip not responding (HW issue)");
        Serial.println("[DIAG]   2. SPI bus misconfiguration");
        Serial.println("[DIAG]   3. UWB chip needs firmware update");
        Serial.println("[DIAG] BLE will still advertise but ranging won't work");
    }

    Serial.println("[DIAG] BLE advertising as TS_DCU040");
    Serial.println("[DIAG] Ready.");
}

void loop() {
    delay(100);
    UWBNearbySessionManager.poll();
}

#else
// ============================================================
// Normal firmware
// ============================================================

#include "config.h"
#include "commands.h"
#include "power_manager.h"
#include "button_handler.h"
#include "bonding_manager.h"
#include "hal/arduino_gpio_hal.h"
#include "hal/sc7a20_accel_hal.h"

static ArduinoGpioHal s_gpio;
static Sc7a20AccelHal s_accel;

static CommandHandler s_commands(&s_gpio);
static PowerManager   s_power(&s_accel, &s_gpio);
static ButtonHandler  s_button(&s_gpio);
static BondingManager s_bonding;

static BLEService        appService(SERVICE_UUID);
static BLECharacteristic batteryChar(CHAR_BATTERY_UUID,
                                     BLERead | BLENotify, 1);
static BLECharacteristic commandChar(CHAR_COMMAND_UUID,
                                     BLEWrite, 2);
static BLECharacteristic deviceInfoChar(CHAR_DEVICE_INFO_UUID,
                                        BLERead, 64);

static uint16_t      numConnected     = 0;
static bool          ranging_active   = false;
static bool          uwb_ready        = false;
static unsigned long pairing_blink_ms = 0;
static bool          pairing_led_state = false;

static void rangingHandler(UWBRangingData& rangingData) {
    if (rangingData.measureType() !=
        static_cast<uint8_t>(uwb::MeasurementType::TWO_WAY))
        return;

    RangingMeasures twr = rangingData.twoWayRangingMeasure();
    for (int j = 0; j < rangingData.available(); j++) {
        if (twr[j].status == 0 && twr[j].distance != 0xFFFF) {
            Serial.print("Distance: ");
            Serial.println(twr[j].distance);
        }
    }
}

static void writeBattery() {
    int raw = analogRead(BATTERY_ADC_PIN);
    int pct = s_power.readBatteryPercent();
    Serial.print("[Stella] battery raw=");
    Serial.print(raw);
    Serial.print(" pct=");
    Serial.println(pct);
    if (pct < 0)   pct = 0;
    if (pct > 100) pct = 100;
    uint8_t val = static_cast<uint8_t>(pct);
    batteryChar.writeValue(&val, 1);
}

static bool battery_update_pending = false;

static void clientConnected(BLEDevice dev) {
    Serial.print("[Stella] BLE client connected: ");
    Serial.println(dev.address());
    numConnected++;
    s_power.notifyConnected();
    battery_update_pending = true;
}

static void clientDisconnected(BLEDevice dev) {
    Serial.print("[Stella] BLE client disconnected: ");
    Serial.println(dev.address());
    if (numConnected > 0) numConnected--;
    s_power.notifyDisconnected();
    ranging_active = false;
}

static void sessionStarted(BLEDevice) {
    Serial.println("[Stella] UWB session started");
    ranging_active = true;
}
static void sessionStopped(BLEDevice) {
    Serial.println("[Stella] UWB session stopped");
    ranging_active = false;
}

static void onCommandWritten(BLEDevice, BLECharacteristic characteristic) {
    const uint8_t* data = characteristic.value();
    int len = characteristic.valueLength();
    if (len < 1) return;

    uint8_t code  = data[0];
    uint8_t param = (len >= 2) ? data[1] : 0;

    if (code == CMD_PING) {
        int pct = s_power.readBatteryPercent();
        if (pct < 0)   pct = 0;
        if (pct > 100) pct = 100;
        uint8_t val = static_cast<uint8_t>(pct);
        batteryChar.writeValue(&val, 1);
        return;
    }

    s_commands.handleCommand(code, param);
}

static void onButtonShort(void*) {
    if (s_bonding.isPairingMode()) {
        s_bonding.confirmPairing();
        if (!s_bonding.isPairingMode()) {
            pairing_led_state = false;
            s_gpio.digitalWrite(PIN_LED_USER, 0);
        }
        return;
    }
    s_commands.handleCommand(CMD_PLAY_SOUND, 0);
}

static void onButtonLong(void*) {
    s_bonding.enterPairingMode();
    pairing_blink_ms  = s_gpio.millis();
    pairing_led_state = true;
    s_gpio.digitalWrite(PIN_LED_USER, 1);
}

void setup() {
    // LED_PWR is active-low: HIGH = off.
    pinMode(LED_PWR, OUTPUT);
    digitalWrite(LED_PWR, HIGH);
    // Keep PIN_ENABLE_SENSORS_3V3 HIGH -- the UWB SPI bus needs this rail.

    Serial.begin(115200);
    unsigned long t0 = millis();
    while (!Serial && (millis() - t0 < 2000)) delay(10);

    Serial.println("[Stella] Firmware starting...");
    Serial.print("[Stella] FW=");
    Serial.print(FW_VERSION);
    Serial.print(" HW=");
    Serial.println(HW_MODEL);

    UWB.registerRangingCallback(rangingHandler);

    UWBNearbySessionManager.onConnect(clientConnected);
    UWBNearbySessionManager.onDisconnect(clientDisconnected);
    UWBNearbySessionManager.onSessionStart(sessionStarted);
    UWBNearbySessionManager.onSessionStop(sessionStopped);

    Serial.println("[Stella] Starting BLE...");
    UWBNearbySessionManager.begin(BLE_DEVICE_NAME);
    Serial.println("[Stella] BLE OK");

    // Build unique name from BLE MAC so multiple Stellas are distinguishable.
    static char device_name[20];
    {
        String mac = BLE.address();
        if (mac.length() >= 17) {
            snprintf(device_name, sizeof(device_name), "Stella-%c%c%c%c",
                     toupper(mac.charAt(12)), toupper(mac.charAt(13)),
                     toupper(mac.charAt(15)), toupper(mac.charAt(16)));
        } else {
            strncpy(device_name, BLE_DEVICE_NAME, sizeof(device_name));
        }
        BLE.setLocalName(device_name);
        BLE.setDeviceName(device_name);
    }

    // UWB early init with retries (must happen before BLE connection)
    for (int attempt = 1; attempt <= 3; attempt++) {
        Serial.print("[Stella] UWB init attempt ");
        Serial.print(attempt);
        Serial.println("/3...");
        UWB.begin();
        uint8_t st = UWB.state();
        Serial.print("[Stella] UWB.state() = ");
        Serial.println(st);
        if (st == 0) {
            uwb_ready = true;
            Serial.println("[Stella] UWB ready");
            break;
        }
        Serial.println("[Stella] UWB init failed, retrying...");
        UWB.end();
        delay(2000);
    }
    if (!uwb_ready) {
        Serial.println("[Stella] WARNING: UWB unavailable after 3 attempts");
    }

    appService.addCharacteristic(batteryChar);
    appService.addCharacteristic(commandChar);
    appService.addCharacteristic(deviceInfoChar);
    BLE.addService(appService);

    BLEAdvertisingData scanResponse;
    scanResponse.setLocalName(device_name);
    scanResponse.setAdvertisedService(appService);
    BLE.setScanResponseData(scanResponse);

    char info[64];
    snprintf(info, sizeof(info),
             "{\"fw\":\"%s\",\"hw\":\"%s\"}", FW_VERSION, HW_MODEL);
    deviceInfoChar.writeValue(
        reinterpret_cast<const uint8_t*>(info),
        static_cast<int>(strlen(info)));

    commandChar.setEventHandler(BLEWritten, onCommandWritten);

    // GPIO peripherals after UWB.
    // Do NOT call s_power.begin() -- Wire.begin() conflicts with UWB SPI.
    s_commands.begin();
    s_button.begin();
    s_button.setOnShortPress(onButtonShort, nullptr);
    s_button.setOnLongPress(onButtonLong, nullptr);
    s_bonding.begin();

    // Write initial battery value so iOS doesn't see 0% on first read.
    // Only reads A6 (BATTERY_ADC_PIN) -- do NOT scan other analog pins,
    // as some share nRF GPIOs with the UWB SPI bus and analogRead()
    // reconfigures them from SPI mode to analog input.
    writeBattery();

    Serial.print("[Stella] Name: ");
    Serial.println(device_name);
    Serial.println("[Stella] Ready.");
}

static unsigned long last_heartbeat_ms = 0;

void loop() {
    delay(100);
    UWBNearbySessionManager.poll();

    s_button.update();
    s_commands.update();

    unsigned long now = millis();
    if (now - last_heartbeat_ms >= 5000) {
        last_heartbeat_ms = now;
        Serial.print("[Stella] alive t=");
        Serial.print(now / 1000);
        Serial.print("s conns=");
        Serial.print(numConnected);
        Serial.print(" ranging=");
        Serial.println(ranging_active ? "yes" : "no");
    }

    if (numConnected > 0 && (battery_update_pending || s_power.shouldReportBattery())) {
        battery_update_pending = false;
        writeBattery();
    }
}

#endif // DIAG_NEARBY_ONLY
#endif // STELLA_TARGET
