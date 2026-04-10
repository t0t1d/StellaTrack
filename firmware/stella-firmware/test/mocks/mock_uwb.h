#ifndef MOCK_UWB_H
#define MOCK_UWB_H

#include "hal/uwb_hal.h"
#include <vector>
#include <cstring>

class MockUwb : public IUwbHal {
public:
    bool initialized = false;
    bool ranging = false;
    uint8_t ranging_rate = 0;
    std::vector<uint8_t> last_ios_config;

    std::vector<uint8_t> fake_accessory_config;

    bool begin() override {
        initialized = true;
        return true;
    }

    bool generateAccessoryConfig(uint8_t* outBuf, size_t maxLen, size_t* outLen) override {
        if (!initialized || fake_accessory_config.empty()) return false;
        size_t copyLen = (fake_accessory_config.size() < maxLen) ? fake_accessory_config.size() : maxLen;
        std::memcpy(outBuf, fake_accessory_config.data(), copyLen);
        *outLen = copyLen;
        return true;
    }

    bool startRanging(const uint8_t* iosConfig, size_t configLen, uint8_t rateHz) override {
        if (!initialized) return false;
        last_ios_config.assign(iosConfig, iosConfig + configLen);
        ranging_rate = rateHz;
        ranging = true;
        return true;
    }

    bool stopRanging() override {
        ranging = false;
        ranging_rate = 0;
        return true;
    }

    bool isRanging() override { return ranging; }

    bool setRangingRate(uint8_t rateHz) override {
        if (!ranging) return false;
        ranging_rate = rateHz;
        return true;
    }

    void poll() override {}
};

#endif
