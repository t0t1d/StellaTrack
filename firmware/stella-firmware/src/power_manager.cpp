#include "power_manager.h"

PowerManager::PowerManager(IAccelHal* accel, IGpioHal* gpio)
    : accel_(accel), gpio_(gpio) {}

void PowerManager::begin() {
    accel_->begin();
    unsigned long now = gpio_->millis();
    last_motion_ms_ = now;
    advertising_no_conn_start_ms_ = now;
    disconnect_at_ms_ = 0;
    last_battery_report_ms_ = 0;
    connected_ = false;
}

bool PowerManager::isMotionDetected() {
    return accel_->readMagnitude() > MOTION_THRESHOLD_G;
}

uint8_t PowerManager::getRecommendedRangingRate() {
    unsigned long now = gpio_->millis();
    if (accel_->readMagnitude() > MOTION_THRESHOLD_G) {
        last_motion_ms_ = now;
    }
    if (now - last_motion_ms_ >= MOTION_TIMEOUT_MS) {
        return UWB_RANGING_RATE_IDLE_HZ;
    }
    return UWB_RANGING_RATE_ACTIVE_HZ;
}

int PowerManager::readBatteryPercent() {
    int raw = gpio_->analogRead(BATTERY_ADC_PIN);
    float pin_v = (static_cast<float>(raw) / static_cast<float>(BATTERY_ADC_MAX)) * BATTERY_VREF;
    float batt_v = pin_v * BATTERY_DIVIDER;
    float pct =
        (batt_v - BATTERY_VOLTAGE_EMPTY) / (BATTERY_VOLTAGE_FULL - BATTERY_VOLTAGE_EMPTY) * 100.0f;
    if (pct < 0.0f)   pct = 0.0f;
    if (pct > 100.0f)  pct = 100.0f;
    return static_cast<int>(pct + 0.5f);
}

bool PowerManager::shouldReportBattery() {
    unsigned long now = gpio_->millis();
    if (now - last_battery_report_ms_ >= BATTERY_REPORT_INTERVAL_MS) {
        last_battery_report_ms_ = now;
        return true;
    }
    return false;
}

DeviceState PowerManager::getRecommendedState() {
    unsigned long now = gpio_->millis();

    if (connected_) {
        return DeviceState::BLEConnected;
    }

    if (disconnect_at_ms_ != 0) {
        if (now - disconnect_at_ms_ <= BLE_RECONNECT_TIMEOUT_MS) {
            return DeviceState::BLEConnected;
        }
        disconnect_at_ms_ = 0;
        advertising_no_conn_start_ms_ = now;
    }

    if (now - advertising_no_conn_start_ms_ >= SLEEP_TIMEOUT_MS) {
        return DeviceState::Sleep;
    }
    return DeviceState::Advertising;
}

void PowerManager::notifyConnected() {
    connected_ = true;
    disconnect_at_ms_ = 0;
}

void PowerManager::notifyDisconnected() {
    connected_ = false;
    disconnect_at_ms_ = gpio_->millis();
}
