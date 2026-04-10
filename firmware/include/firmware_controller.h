#ifndef STELLA_FIRMWARE_CONTROLLER_H
#define STELLA_FIRMWARE_CONTROLLER_H

#include "ble_service.h"
#include "bonding_manager.h"
#include "button_handler.h"
#include "commands.h"
#include "led_indicator.h"
#include "power_manager.h"
#include "uwb_session.h"

class IGpioHal;
class IBleHal;
class IUwbHal;
class IAccelHal;

class FirmwareController {
public:
    FirmwareController(IGpioHal* gpio, IBleHal* ble, IUwbHal* uwb, IAccelHal* accel);

    bool begin();
    void update();

    bool isPairingMode() const;
    uint8_t getBondCount() const;
    void setPendingPairAddress(const uint8_t addr[6]);
    bool hasConfigError() const;

private:
    IGpioHal* gpio_;
    IBleHal* ble_hal_;
    IUwbHal* uwb_hal_;

    BleService ble_service_;
    UwbSession uwb_session_;
    CommandHandler commands_;
    PowerManager power_;
    ButtonHandler button_;
    BondingManager bonding_;
    LedIndicator led_;

    bool begun_;
    bool advertising_active_;
    uint8_t last_ranging_rate_applied_;
    bool manual_rate_override_;
    unsigned long last_led_toggle_ms_;
    bool pairing_led_state_;
    bool config_error_;

    static void onBleConnectThunk(void* ctx);
    static void onBleDisconnectThunk(void* ctx);
    static void onCommandWrittenThunk(const uint8_t* data, size_t len, void* ctx);
    static void onUwbConfigInThunk(const uint8_t* data, size_t len, void* ctx);
    static void onButtonShortThunk(void* ctx);
    static void onButtonLongThunk(void* ctx);

    void onBleConnected();
    void onBleDisconnected();
    void onCommandWritten(const uint8_t* data, size_t len);
    void onUwbConfigIn(const uint8_t* data, size_t len);
    void onButtonShortPress();
    void onButtonLongPress();

    void applyRecommendedRangingRate();
    void maybeReportBattery();
    void tryRestartAdvertising();
    void updatePairingLed();
};

#endif
