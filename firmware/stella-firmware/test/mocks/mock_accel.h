#ifndef MOCK_ACCEL_H
#define MOCK_ACCEL_H

#include "hal/accel_hal.h"

class MockAccel : public IAccelHal {
public:
    bool initialized = false;
    float fake_magnitude = 0.0f;

    bool begin() override {
        initialized = true;
        return true;
    }

    float readMagnitude() override {
        return fake_magnitude;
    }
};

#endif
