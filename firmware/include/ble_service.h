#ifndef STELLA_BLE_SERVICE_H
#define STELLA_BLE_SERVICE_H

#include "config.h"
#include "hal/ble_hal.h"

#include <stddef.h>
#include <stdint.h>

class BleService {
public:
    explicit BleService(IBleHal* hal);

    bool begin();
    void startAdvertising();
    void stopAdvertising();
    bool isConnected();

    bool writeUwbConfig(const uint8_t* data, size_t len);
    bool writeBatteryLevel(uint8_t percent);

    void onCommandReceived(BleWriteCallback cb, void* ctx);
    void onUwbConfigReceived(BleWriteCallback cb, void* ctx);
    void onConnect(BleEventCallback cb, void* ctx);
    void onDisconnect(BleEventCallback cb, void* ctx);

private:
    IBleHal* hal_;
    bool begun_;
    BleWriteCallback cmd_cb_;
    void* cmd_ctx_;
    BleWriteCallback uwb_in_cb_;
    void* uwb_in_ctx_;
    BleEventCallback connect_cb_;
    void* connect_ctx_;
    BleEventCallback disconnect_cb_;
    void* disconnect_ctx_;

    void wireCallbacks();
};

#endif
