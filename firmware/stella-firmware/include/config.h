#ifndef STELLA_CONFIG_H
#define STELLA_CONFIG_H

#include <stdint.h>

// --- BLE Service UUIDs ---
#define SERVICE_UUID            "A0E9F8B0-1234-5678-ABCD-0123456789AB"
#define CHAR_UWB_CONFIG_OUT_UUID "A0E9F8B1-1234-5678-ABCD-0123456789AB"
#define CHAR_UWB_CONFIG_IN_UUID  "A0E9F8B2-1234-5678-ABCD-0123456789AB"
#define CHAR_BATTERY_UUID        "A0E9F8B3-1234-5678-ABCD-0123456789AB"
#define CHAR_COMMAND_UUID        "A0E9F8B4-1234-5678-ABCD-0123456789AB"
#define CHAR_DEVICE_INFO_UUID    "A0E9F8B5-1234-5678-ABCD-0123456789AB"

// --- BLE Advertising ---
#define BLE_DEVICE_NAME         "Stella"
#define BLE_ADV_INTERVAL_MS     100
#define BLE_RECONNECT_TIMEOUT_MS 30000
#define BLE_ADV_TIMEOUT_MS      60000

// --- Pin Definitions ---
#define PIN_BUZZER              3
#define PIN_LED_USER            13
#define PIN_BUTTON_USER         7
#define PIN_BUTTON_RESET        -1

// --- Buzzer ---
#define BUZZER_FREQ_HZ          4000
#define BUZZER_DEFAULT_DURATION_S 0

// --- UWB ---
#define UWB_RANGING_RATE_ACTIVE_HZ  10
#define UWB_RANGING_RATE_IDLE_HZ    1
#define UWB_CONFIG_MAX_SIZE         128

// --- Power Management ---
#define MOTION_THRESHOLD_G      0.1f
#define MOTION_TIMEOUT_MS       10000
#define SLEEP_TIMEOUT_MS        60000

// --- Battery ---
#define BATTERY_REPORT_INTERVAL_MS 30000
#if defined(NATIVE_TEST) && !defined(A0)
#define A0 14
#endif
#define BATTERY_ADC_PIN         A0
#define BATTERY_VOLTAGE_MIN     2.0f
#define BATTERY_VOLTAGE_MAX     3.0f

// --- Bonding ---
#define MAX_BONDS               4

// --- Command Codes ---
enum CommandCode : uint8_t {
    CMD_PLAY_SOUND      = 0x01,
    CMD_STOP_SOUND      = 0x02,
    CMD_LED_ON          = 0x03,
    CMD_LED_OFF         = 0x04,
    CMD_SET_RANGING_RATE = 0x05,
    CMD_PING            = 0x06
};

// --- Device State ---
enum class DeviceState : uint8_t {
    Idle,
    Advertising,
    BLEConnected,
    ConfigSent,
    Ranging,
    Sleep
};

// --- Firmware Info ---
#define FW_VERSION              "1.0.0"
#define HW_MODEL                "ABX00131"

#endif
