#include "uwb_session.h"
#include "config.h"
#include "hal/uwb_hal.h"
#include "hal/gpio_hal.h"

UwbSession::UwbSession(IUwbHal* uwb, IGpioHal* gpio)
    : uwb_(uwb), gpio_(gpio), has_config_(false), state_(UwbSessionState::Idle) {}

bool UwbSession::begin() {
    (void)gpio_->millis();
    return uwb_->begin();
}

bool UwbSession::generateConfig(uint8_t* outBuf, size_t maxLen, size_t* outLen) {
    size_t cap = maxLen;
    if (cap > UWB_CONFIG_MAX_SIZE) {
        cap = UWB_CONFIG_MAX_SIZE;
    }
    if (!uwb_->generateAccessoryConfig(outBuf, cap, outLen)) {
        return false;
    }
    has_config_ = true;
    state_ = UwbSessionState::ConfigGenerated;
    return true;
}

bool UwbSession::startSession(const uint8_t* iosConfig, size_t len) {
    if (!has_config_) {
        return false;
    }
    if (!uwb_->startRanging(iosConfig, len, UWB_RANGING_RATE_ACTIVE_HZ)) {
        return false;
    }
    state_ = UwbSessionState::Ranging;
    return true;
}

bool UwbSession::stopSession() {
    bool ok = uwb_->stopRanging();
    has_config_ = false;
    state_ = UwbSessionState::Idle;
    return ok;
}

bool UwbSession::isActive() const {
    return uwb_->isRanging();
}

bool UwbSession::setRangingRate(uint8_t hz) {
    if (!uwb_->isRanging()) {
        return false;
    }
    return uwb_->setRangingRate(hz);
}

UwbSessionState UwbSession::getState() const {
    return state_;
}
