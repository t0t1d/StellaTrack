#include "firmware_controller.h"

#include "config.h"
#include "hal/accel_hal.h"
#include "hal/ble_hal.h"
#include "hal/gpio_hal.h"
#include "hal/uwb_hal.h"

static const unsigned long kPairingBlinkIntervalMs = 500;

FirmwareController::FirmwareController(IGpioHal* gpio, IBleHal* ble, IUwbHal* uwb, IAccelHal* accel)
    : gpio_(gpio),
      ble_hal_(ble),
      uwb_hal_(uwb),
      ble_service_(ble),
      uwb_session_(uwb, gpio),
      commands_(gpio),
      power_(accel, gpio),
      button_(gpio),
      begun_(false),
      advertising_active_(false),
      last_ranging_rate_applied_(0xFF),
      manual_rate_override_(false),
      last_led_toggle_ms_(0),
      pairing_led_state_(false) {}

bool FirmwareController::begin() {
    if (begun_) {
        return true;
    }

    ble_service_.onConnect(&FirmwareController::onBleConnectThunk, this);
    ble_service_.onDisconnect(&FirmwareController::onBleDisconnectThunk, this);
    ble_service_.onCommandReceived(&FirmwareController::onCommandWrittenThunk, this);
    ble_service_.onUwbConfigReceived(&FirmwareController::onUwbConfigInThunk, this);

    commands_.begin();
    if (!ble_service_.begin()) {
        return false;
    }
    if (!uwb_session_.begin()) {
        return false;
    }
    power_.begin();
    button_.begin();
    button_.setOnShortPress(&FirmwareController::onButtonShortThunk, this);
    button_.setOnLongPress(&FirmwareController::onButtonLongThunk, this);
    bonding_.begin();

    begun_ = true;
    ble_service_.startAdvertising();
    advertising_active_ = true;
    return true;
}

void FirmwareController::update() {
    ble_hal_->poll();
    uwb_hal_->poll();

    button_.update();
    commands_.update();

    applyRecommendedRangingRate();
    maybeReportBattery();
    tryRestartAdvertising();
    updatePairingLed();
}

bool FirmwareController::isPairingMode() const {
    return bonding_.isPairingMode();
}

uint8_t FirmwareController::getBondCount() const {
    return bonding_.getBondCount();
}

void FirmwareController::onBleConnected() {
    ble_service_.stopAdvertising();
    advertising_active_ = false;
    power_.notifyConnected();

    uint8_t buf[UWB_CONFIG_MAX_SIZE];
    size_t out_len = 0;
    if (uwb_session_.generateConfig(buf, sizeof(buf), &out_len)) {
        ble_service_.writeUwbConfig(buf, out_len);
    }
}

void FirmwareController::onBleDisconnected() {
    (void)uwb_session_.stopSession();
    last_ranging_rate_applied_ = 0xFF;
    manual_rate_override_ = false;
    power_.notifyDisconnected();
}

void FirmwareController::onUwbConfigIn(const uint8_t* data, size_t len) {
    if (len == 0) {
        return;
    }
    if (uwb_session_.startSession(data, len)) {
        last_ranging_rate_applied_ = 0xFF;
    }
}

void FirmwareController::onCommandWritten(const uint8_t* data, size_t len) {
    if (len < 1) {
        return;
    }
    const uint8_t param = (len >= 2) ? data[1] : 0;
    uint8_t code = data[0];

    if (code == CMD_SET_RANGING_RATE && uwb_session_.isActive()) {
        uint8_t rate = param;
        if (rate < 1) rate = 1;
        if (rate > 10) rate = 10;
        uwb_session_.setRangingRate(rate);
        last_ranging_rate_applied_ = rate;
        manual_rate_override_ = true;
    }

    commands_.handleCommand(code, param);
}

void FirmwareController::onButtonShortPress() {
    commands_.handleCommand(CMD_PLAY_SOUND, 0);
}

void FirmwareController::onButtonLongPress() {
    bonding_.enterPairingMode();
    last_led_toggle_ms_ = gpio_->millis();
    pairing_led_state_ = true;
    gpio_->digitalWrite(PIN_LED_USER, 1);
}

void FirmwareController::applyRecommendedRangingRate() {
    if (!ble_service_.isConnected()) {
        return;
    }
    if (!uwb_session_.isActive()) {
        return;
    }
    if (manual_rate_override_) {
        return;
    }
    const uint8_t want = power_.getRecommendedRangingRate();
    if (want == last_ranging_rate_applied_) {
        return;
    }
    if (uwb_session_.setRangingRate(want)) {
        last_ranging_rate_applied_ = want;
    }
}

void FirmwareController::maybeReportBattery() {
    if (!ble_service_.isConnected()) {
        return;
    }
    if (!power_.shouldReportBattery()) {
        return;
    }
    int pct = power_.readBatteryPercent();
    if (pct < 0) {
        pct = 0;
    }
    if (pct > 100) {
        pct = 100;
    }
    ble_service_.writeBatteryLevel(static_cast<uint8_t>(pct));
}

void FirmwareController::tryRestartAdvertising() {
    if (ble_service_.isConnected()) {
        return;
    }
    if (power_.getRecommendedState() != DeviceState::Advertising) {
        return;
    }
    if (advertising_active_) {
        return;
    }
    ble_service_.startAdvertising();
    advertising_active_ = true;
}

void FirmwareController::updatePairingLed() {
    if (!bonding_.isPairingMode()) {
        return;
    }
    unsigned long now = gpio_->millis();
    if (now - last_led_toggle_ms_ >= kPairingBlinkIntervalMs) {
        pairing_led_state_ = !pairing_led_state_;
        gpio_->digitalWrite(PIN_LED_USER, pairing_led_state_ ? 1 : 0);
        last_led_toggle_ms_ = now;
    }
}

void FirmwareController::onBleConnectThunk(void* ctx) {
    static_cast<FirmwareController*>(ctx)->onBleConnected();
}

void FirmwareController::onBleDisconnectThunk(void* ctx) {
    static_cast<FirmwareController*>(ctx)->onBleDisconnected();
}

void FirmwareController::onCommandWrittenThunk(const uint8_t* data, size_t len, void* ctx) {
    static_cast<FirmwareController*>(ctx)->onCommandWritten(data, len);
}

void FirmwareController::onUwbConfigInThunk(const uint8_t* data, size_t len, void* ctx) {
    static_cast<FirmwareController*>(ctx)->onUwbConfigIn(data, len);
}

void FirmwareController::onButtonShortThunk(void* ctx) {
    static_cast<FirmwareController*>(ctx)->onButtonShortPress();
}

void FirmwareController::onButtonLongThunk(void* ctx) {
    static_cast<FirmwareController*>(ctx)->onButtonLongPress();
}
