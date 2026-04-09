#ifndef MOCK_BLE_H
#define MOCK_BLE_H

#include "hal/ble_hal.h"
#include <string>
#include <map>
#include <vector>
#include <cstring>

struct MockCharacteristic {
    std::string uuid;
    uint16_t properties;
    size_t maxLen;
    std::vector<uint8_t> data;
    BleWriteCallback writeCb = nullptr;
    void* writeCbCtx = nullptr;
};

class MockBle : public IBleHal {
public:
    bool initialized = false;
    std::string device_name;
    std::string service_uuid;
    std::map<std::string, MockCharacteristic> characteristics;
    bool advertising = false;
    bool connected = false;
    bool paired = false;

    BleEventCallback connectCb = nullptr;
    void* connectCtx = nullptr;
    BleEventCallback disconnectCb = nullptr;
    void* disconnectCtx = nullptr;

    bool begin(const char* deviceName) override {
        device_name = deviceName;
        initialized = true;
        return true;
    }

    bool addService(const char* serviceUuid) override {
        service_uuid = serviceUuid;
        return true;
    }

    bool addCharacteristic(const char* uuid, uint16_t properties, size_t maxLen) override {
        MockCharacteristic c;
        c.uuid = uuid;
        c.properties = properties;
        c.maxLen = maxLen;
        characteristics[uuid] = c;
        return true;
    }

    bool writeCharacteristic(const char* uuid, const uint8_t* data, size_t len) override {
        auto it = characteristics.find(uuid);
        if (it == characteristics.end()) return false;
        it->second.data.assign(data, data + len);
        return true;
    }

    bool readCharacteristic(const char* uuid, uint8_t* data, size_t maxLen, size_t* outLen) override {
        auto it = characteristics.find(uuid);
        if (it == characteristics.end()) return false;
        size_t copyLen = (it->second.data.size() < maxLen) ? it->second.data.size() : maxLen;
        std::memcpy(data, it->second.data.data(), copyLen);
        *outLen = copyLen;
        return true;
    }

    void setAdvertising(bool enabled) override { advertising = enabled; }
    bool isConnected() override { return connected; }
    bool isPaired() override { return paired; }

    void onConnect(BleEventCallback cb, void* ctx) override {
        connectCb = cb;
        connectCtx = ctx;
    }

    void onDisconnect(BleEventCallback cb, void* ctx) override {
        disconnectCb = cb;
        disconnectCtx = ctx;
    }

    void onCharacteristicWritten(const char* uuid, BleWriteCallback cb, void* ctx) override {
        auto it = characteristics.find(uuid);
        if (it != characteristics.end()) {
            it->second.writeCb = cb;
            it->second.writeCbCtx = ctx;
        }
    }

    void poll() override {}

    // --- Test helpers ---
    void simulateConnect() {
        connected = true;
        paired = true;
        if (connectCb) connectCb(connectCtx);
    }

    void simulateDisconnect() {
        connected = false;
        if (disconnectCb) disconnectCb(disconnectCtx);
    }

    void simulateWrite(const char* uuid, const uint8_t* data, size_t len) {
        auto it = characteristics.find(uuid);
        if (it != characteristics.end()) {
            it->second.data.assign(data, data + len);
            if (it->second.writeCb) {
                it->second.writeCb(data, len, it->second.writeCbCtx);
            }
        }
    }
};

#endif
