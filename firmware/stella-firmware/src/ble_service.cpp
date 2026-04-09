#include "ble_service.h"

#include <cstdio>
#include <cstring>

BleService::BleService(IBleHal* hal)
    : hal_(hal)
    , begun_(false)
    , cmd_cb_(nullptr)
    , cmd_ctx_(nullptr)
    , uwb_in_cb_(nullptr)
    , uwb_in_ctx_(nullptr)
    , connect_cb_(nullptr)
    , connect_ctx_(nullptr)
    , disconnect_cb_(nullptr)
    , disconnect_ctx_(nullptr) {}

void BleService::wireCallbacks() {
    if (connect_cb_) hal_->onConnect(connect_cb_, connect_ctx_);
    if (disconnect_cb_) hal_->onDisconnect(disconnect_cb_, disconnect_ctx_);
    if (cmd_cb_) hal_->onCharacteristicWritten(CHAR_COMMAND_UUID, cmd_cb_, cmd_ctx_);
    if (uwb_in_cb_) hal_->onCharacteristicWritten(CHAR_UWB_CONFIG_IN_UUID, uwb_in_cb_, uwb_in_ctx_);
}

bool BleService::begin() {
    if (!hal_->begin(BLE_DEVICE_NAME)) return false;
    if (!hal_->addService(SERVICE_UUID)) return false;

    const uint16_t uwbOutProps = BLE_PROP_READ | BLE_PROP_NOTIFY;
    if (!hal_->addCharacteristic(CHAR_UWB_CONFIG_OUT_UUID, uwbOutProps, UWB_CONFIG_MAX_SIZE)) return false;

    if (!hal_->addCharacteristic(CHAR_UWB_CONFIG_IN_UUID, BLE_PROP_WRITE, UWB_CONFIG_MAX_SIZE)) return false;

    const uint16_t batteryProps = BLE_PROP_READ | BLE_PROP_NOTIFY;
    if (!hal_->addCharacteristic(CHAR_BATTERY_UUID, batteryProps, 1)) return false;

    if (!hal_->addCharacteristic(CHAR_COMMAND_UUID, BLE_PROP_WRITE, 2)) return false;

    if (!hal_->addCharacteristic(CHAR_DEVICE_INFO_UUID, BLE_PROP_READ, 64)) return false;

    char info[64];
    std::snprintf(info, sizeof(info), "{\"fw\":\"%s\",\"hw\":\"%s\"}", FW_VERSION, HW_MODEL);
    const size_t infoLen = std::strlen(info);
    if (!hal_->writeCharacteristic(CHAR_DEVICE_INFO_UUID, reinterpret_cast<const uint8_t*>(info), infoLen)) return false;

    begun_ = true;
    wireCallbacks();
    return true;
}

void BleService::startAdvertising() { hal_->setAdvertising(true); }

void BleService::stopAdvertising() { hal_->setAdvertising(false); }

bool BleService::isConnected() { return hal_->isConnected(); }

bool BleService::writeUwbConfig(const uint8_t* data, size_t len) {
    return hal_->writeCharacteristic(CHAR_UWB_CONFIG_OUT_UUID, data, len);
}

bool BleService::writeBatteryLevel(uint8_t percent) {
    return hal_->writeCharacteristic(CHAR_BATTERY_UUID, &percent, 1);
}

void BleService::onCommandReceived(BleWriteCallback cb, void* ctx) {
    cmd_cb_ = cb;
    cmd_ctx_ = ctx;
    if (begun_) hal_->onCharacteristicWritten(CHAR_COMMAND_UUID, cb, ctx);
}

void BleService::onUwbConfigReceived(BleWriteCallback cb, void* ctx) {
    uwb_in_cb_ = cb;
    uwb_in_ctx_ = ctx;
    if (begun_) hal_->onCharacteristicWritten(CHAR_UWB_CONFIG_IN_UUID, cb, ctx);
}

void BleService::onConnect(BleEventCallback cb, void* ctx) {
    connect_cb_ = cb;
    connect_ctx_ = ctx;
    if (begun_) hal_->onConnect(cb, ctx);
}

void BleService::onDisconnect(BleEventCallback cb, void* ctx) {
    disconnect_cb_ = cb;
    disconnect_ctx_ = ctx;
    if (begun_) hal_->onDisconnect(cb, ctx);
}
