#ifndef STELLA_BLE_HAL_H
#define STELLA_BLE_HAL_H

#include <stdint.h>
#include <stddef.h>

using BleEventCallback = void(*)(void* context);
using BleWriteCallback = void(*)(const uint8_t* data, size_t len, void* context);

class IBleHal {
public:
    virtual ~IBleHal() = default;

    virtual bool begin(const char* deviceName) = 0;
    virtual bool addService(const char* serviceUuid) = 0;

    virtual bool addCharacteristic(const char* uuid, uint16_t properties, size_t maxLen) = 0;
    virtual bool writeCharacteristic(const char* uuid, const uint8_t* data, size_t len) = 0;
    virtual bool readCharacteristic(const char* uuid, uint8_t* data, size_t maxLen, size_t* outLen) = 0;

    virtual void setAdvertising(bool enabled) = 0;
    virtual bool isConnected() = 0;
    virtual bool isPaired() = 0;

    virtual void onConnect(BleEventCallback cb, void* ctx) = 0;
    virtual void onDisconnect(BleEventCallback cb, void* ctx) = 0;
    virtual void onCharacteristicWritten(const char* uuid, BleWriteCallback cb, void* ctx) = 0;

    virtual void poll() = 0;
};

static const uint16_t BLE_PROP_READ   = 0x01;
static const uint16_t BLE_PROP_WRITE  = 0x02;
static const uint16_t BLE_PROP_NOTIFY = 0x04;

#endif
