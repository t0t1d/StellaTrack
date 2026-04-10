#ifndef STELLA_UWB_HAL_H
#define STELLA_UWB_HAL_H

#include <stdint.h>
#include <stddef.h>

class IUwbHal {
public:
    virtual ~IUwbHal() = default;

    virtual bool begin() = 0;
    virtual bool generateAccessoryConfig(uint8_t* outBuf, size_t maxLen, size_t* outLen) = 0;
    virtual bool startRanging(const uint8_t* iosConfig, size_t configLen, uint8_t rateHz) = 0;
    virtual bool stopRanging() = 0;
    virtual bool isRanging() = 0;
    virtual bool setRangingRate(uint8_t rateHz) = 0;
    virtual void poll() = 0;
};

#endif
