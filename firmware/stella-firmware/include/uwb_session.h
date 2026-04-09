#ifndef STELLA_UWB_SESSION_H
#define STELLA_UWB_SESSION_H

#include <stdint.h>
#include <stddef.h>

class IUwbHal;
class IGpioHal;

enum class UwbSessionState : uint8_t {
    Idle,
    ConfigGenerated,
    Ranging
};

class UwbSession {
public:
    UwbSession(IUwbHal* uwb, IGpioHal* gpio);

    bool begin();
    bool generateConfig(uint8_t* outBuf, size_t maxLen, size_t* outLen);
    bool startSession(const uint8_t* iosConfig, size_t len);
    bool stopSession();
    bool isActive() const;
    bool setRangingRate(uint8_t hz);
    UwbSessionState getState() const;

private:
    IUwbHal* uwb_;
    IGpioHal* gpio_;
    bool has_config_;
    UwbSessionState state_;
};

#endif
