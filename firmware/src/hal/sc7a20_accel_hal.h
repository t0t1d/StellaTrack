#ifndef STELLA_SC7A20_ACCEL_HAL_H
#define STELLA_SC7A20_ACCEL_HAL_H

#ifdef STELLA_TARGET

#include "hal/accel_hal.h"
#include <Wire.h>
#include <math.h>

// SC7A20 3-axis MEMS accelerometer registers (I2C address 0x18 or 0x19)
static const uint8_t SC7A20_ADDR       = 0x18;
static const uint8_t SC7A20_WHO_AM_I   = 0x0F;
static const uint8_t SC7A20_CTRL_REG1  = 0x20;
static const uint8_t SC7A20_OUT_X_L    = 0x28;
static const uint8_t SC7A20_WHO_AM_I_VAL = 0x11;

class Sc7a20AccelHal : public IAccelHal {
public:
    bool begin() override {
        Wire.begin();

        if (readReg(SC7A20_WHO_AM_I) != SC7A20_WHO_AM_I_VAL) {
            return false;
        }

        // Enable all axes, 100 Hz ODR, normal mode
        // CTRL_REG1: ODR=0101 (100Hz), LPen=0, Zen=1, Yen=1, Xen=1 = 0x57
        writeReg(SC7A20_CTRL_REG1, 0x57);
        initialized_ = true;
        return true;
    }

    float readMagnitude() override {
        if (!initialized_) return 0.0f;

        int16_t x = readAxis(SC7A20_OUT_X_L);
        int16_t y = readAxis(SC7A20_OUT_X_L + 2);
        int16_t z = readAxis(SC7A20_OUT_X_L + 4);

        // SC7A20 default range is +/-2G, 12-bit left-justified in 16-bit.
        // Sensitivity: 1 mg/digit at +/-2G (after right-shifting 4 bits).
        float fx = static_cast<float>(x >> 4) / 1000.0f;
        float fy = static_cast<float>(y >> 4) / 1000.0f;
        float fz = static_cast<float>(z >> 4) / 1000.0f;

        // Subtract 1G gravity on Z to get acceleration magnitude
        // For motion detection, we use the deviation from resting state.
        // At rest: magnitude ~= 1.0G. We report delta from 1G.
        float mag = sqrtf(fx * fx + fy * fy + fz * fz);
        float delta = fabsf(mag - 1.0f);
        return delta;
    }

private:
    bool initialized_ = false;

    uint8_t readReg(uint8_t reg) {
        Wire.beginTransmission(SC7A20_ADDR);
        Wire.write(reg);
        Wire.endTransmission(false);
        Wire.requestFrom(SC7A20_ADDR, (uint8_t)1);
        return Wire.available() ? Wire.read() : 0;
    }

    void writeReg(uint8_t reg, uint8_t val) {
        Wire.beginTransmission(SC7A20_ADDR);
        Wire.write(reg);
        Wire.write(val);
        Wire.endTransmission();
    }

    int16_t readAxis(uint8_t baseReg) {
        // Auto-increment read: set MSB of register address
        Wire.beginTransmission(SC7A20_ADDR);
        Wire.write(baseReg | 0x80);
        Wire.endTransmission(false);
        Wire.requestFrom(SC7A20_ADDR, (uint8_t)2);
        uint8_t lo = Wire.available() ? Wire.read() : 0;
        uint8_t hi = Wire.available() ? Wire.read() : 0;
        return static_cast<int16_t>((hi << 8) | lo);
    }
};

#endif // STELLA_TARGET
#endif
