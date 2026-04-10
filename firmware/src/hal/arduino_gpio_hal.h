#ifndef STELLA_ARDUINO_GPIO_HAL_H
#define STELLA_ARDUINO_GPIO_HAL_H

#ifdef STELLA_TARGET

#include "hal/gpio_hal.h"
#include <Arduino.h>

class ArduinoGpioHal : public IGpioHal {
public:
    void pinMode(int pin, int mode) override {
        ::pinMode(static_cast<pin_size_t>(pin), static_cast<PinMode>(mode));
    }

    void digitalWrite(int pin, int value) override {
        ::digitalWrite(static_cast<pin_size_t>(pin), static_cast<PinStatus>(value));
    }

    int digitalRead(int pin) override {
        return ::digitalRead(static_cast<pin_size_t>(pin));
    }

    int analogRead(int pin) override {
        return ::analogRead(static_cast<pin_size_t>(pin));
    }

    void toneStart(int pin, uint32_t frequency) override {
        ::tone(static_cast<pin_size_t>(pin), frequency);
    }

    void toneStop(int pin) override {
        ::noTone(static_cast<pin_size_t>(pin));
    }

    unsigned long millis() override {
        return ::millis();
    }
};

#endif // STELLA_TARGET
#endif
