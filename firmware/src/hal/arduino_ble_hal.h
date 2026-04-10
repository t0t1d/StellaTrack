#ifndef STELLA_ARDUINO_BLE_HAL_H
#define STELLA_ARDUINO_BLE_HAL_H

#ifdef STELLA_TARGET

#include "hal/ble_hal.h"
#include <ArduinoBLE.h>
#include <map>
#include <string>

struct BleCharEntry {
    BLECharacteristic* characteristic;
    BleWriteCallback writeCb;
    void* writeCbCtx;
};

class ArduinoBleHal : public IBleHal {
public:
    bool begin(const char* deviceName) override {
        if (!BLE.begin()) return false;
        BLE.setLocalName(deviceName);
        BLE.setDeviceName(deviceName);
        return true;
    }

    bool addService(const char* serviceUuid) override {
        service_ = new BLEService(serviceUuid);
        BLE.setAdvertisedService(*service_);
        return true;
    }

    bool addCharacteristic(const char* uuid, uint16_t properties, size_t maxLen) override {
        uint8_t bleProps = 0;
        if (properties & BLE_PROP_READ)   bleProps |= BLERead;
        if (properties & BLE_PROP_WRITE)  bleProps |= BLEWrite;
        if (properties & BLE_PROP_NOTIFY) bleProps |= BLENotify;

        auto* chr = new BLECharacteristic(uuid, bleProps, maxLen);
        service_->addCharacteristic(*chr);

        BleCharEntry entry;
        entry.characteristic = chr;
        entry.writeCb = nullptr;
        entry.writeCbCtx = nullptr;
        chars_[uuid] = entry;

        if (properties & BLE_PROP_WRITE) {
            chr->setEventHandler(BLEWritten, ArduinoBleHal::onWriteEvent);
        }

        return true;
    }

    bool writeCharacteristic(const char* uuid, const uint8_t* data, size_t len) override {
        auto it = chars_.find(uuid);
        if (it == chars_.end()) return false;
        it->second.characteristic->writeValue(data, len);
        return true;
    }

    bool readCharacteristic(const char* uuid, uint8_t* data, size_t maxLen, size_t* outLen) override {
        auto it = chars_.find(uuid);
        if (it == chars_.end()) return false;
        int vLen = it->second.characteristic->valueLength();
        size_t copyLen = (static_cast<size_t>(vLen) < maxLen) ? static_cast<size_t>(vLen) : maxLen;
        memcpy(data, it->second.characteristic->value(), copyLen);
        *outLen = copyLen;
        return true;
    }

    void setAdvertising(bool enabled) override {
        if (enabled) {
            BLE.addService(*service_);
            BLE.advertise();
        } else {
            BLE.stopAdvertise();
        }
    }

    bool isConnected() override {
        BLEDevice central = BLE.central();
        return central && central.connected();
    }

    bool isPaired() override {
        return isConnected();
    }

    void onConnect(BleEventCallback cb, void* ctx) override {
        connect_cb_ = cb;
        connect_ctx_ = ctx;
        BLE.setEventHandler(BLEConnected, ArduinoBleHal::onConnectEvent);
    }

    void onDisconnect(BleEventCallback cb, void* ctx) override {
        disconnect_cb_ = cb;
        disconnect_ctx_ = ctx;
        BLE.setEventHandler(BLEDisconnected, ArduinoBleHal::onDisconnectEvent);
    }

    void onCharacteristicWritten(const char* uuid, BleWriteCallback cb, void* ctx) override {
        auto it = chars_.find(uuid);
        if (it != chars_.end()) {
            it->second.writeCb = cb;
            it->second.writeCbCtx = ctx;
        }
    }

    void poll() override {
        BLE.poll();
    }

    static ArduinoBleHal* instance_;

private:
    BLEService* service_ = nullptr;
    std::map<std::string, BleCharEntry> chars_;
    BleEventCallback connect_cb_ = nullptr;
    void* connect_ctx_ = nullptr;
    BleEventCallback disconnect_cb_ = nullptr;
    void* disconnect_ctx_ = nullptr;

    static void onConnectEvent(BLEDevice central) {
        (void)central;
        if (instance_ && instance_->connect_cb_) {
            instance_->connect_cb_(instance_->connect_ctx_);
        }
    }

    static void onDisconnectEvent(BLEDevice central) {
        (void)central;
        if (instance_ && instance_->disconnect_cb_) {
            instance_->disconnect_cb_(instance_->disconnect_ctx_);
        }
    }

    static void onWriteEvent(BLEDevice central, BLECharacteristic characteristic) {
        (void)central;
        if (!instance_) return;
        const char* uuid = characteristic.uuid();
        auto it = instance_->chars_.find(uuid);
        if (it != instance_->chars_.end() && it->second.writeCb) {
            it->second.writeCb(
                characteristic.value(),
                characteristic.valueLength(),
                it->second.writeCbCtx
            );
        }
    }
};

ArduinoBleHal* ArduinoBleHal::instance_ = nullptr;

#endif // STELLA_TARGET
#endif
