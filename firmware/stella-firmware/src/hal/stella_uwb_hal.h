#ifndef STELLA_UWB_HAL_IMPL_H
#define STELLA_UWB_HAL_IMPL_H

#ifdef STELLA_TARGET

#include "hal/uwb_hal.h"

// The StellaUWB library from Truesense provides the NI accessory protocol.
// Include path depends on library installation; adjust if needed.
// #include <StellaUWB.h>

class StellaUwbHal : public IUwbHal {
public:
    bool begin() override {
        // Initialize the DCU040 UWB module over SPI.
        // StellaUWB.begin() performs hardware init, antenna calibration.
        // return StellaUWB.begin();
        initialized_ = true;
        return true;
    }

    bool generateAccessoryConfig(uint8_t* outBuf, size_t maxLen, size_t* outLen) override {
        if (!initialized_) return false;

        // StellaUWB.generateNIAccessoryConfig() produces the Apple NI
        // protocol blob that iOS needs to create an NINearbyAccessoryConfiguration.
        //
        // size_t len = StellaUWB.generateNIAccessoryConfig(outBuf, maxLen);
        // if (len == 0) return false;
        // *outLen = len;
        // return true;

        (void)outBuf;
        (void)maxLen;
        *outLen = 0;
        return false;
    }

    bool startRanging(const uint8_t* iosConfig, size_t configLen, uint8_t rateHz) override {
        if (!initialized_) return false;

        // StellaUWB.setShareableConfig(iosConfig, configLen) parses the
        // NI shareable configuration sent by iOS and configures the UWB
        // session parameters (channel, preamble, STS, etc.).
        //
        // StellaUWB.setRangingRate(rateHz);
        // return StellaUWB.startRanging();

        (void)iosConfig;
        (void)configLen;
        ranging_ = true;
        rate_ = rateHz;
        return true;
    }

    bool stopRanging() override {
        // StellaUWB.stopRanging();
        ranging_ = false;
        rate_ = 0;
        return true;
    }

    bool isRanging() override {
        // return StellaUWB.isRanging();
        return ranging_;
    }

    bool setRangingRate(uint8_t rateHz) override {
        if (!ranging_) return false;
        // StellaUWB.setRangingRate(rateHz);
        rate_ = rateHz;
        return true;
    }

    void poll() override {
        // StellaUWB.poll() processes incoming UWB frames and delivers
        // ranging results to the NI framework. On the Stella, the NI
        // framework handles UWB -> iOS delivery, so no explicit result
        // handling is needed here.
        //
        // StellaUWB.poll();
    }

private:
    bool initialized_ = false;
    bool ranging_ = false;
    uint8_t rate_ = 0;
};

#endif // STELLA_TARGET
#endif
