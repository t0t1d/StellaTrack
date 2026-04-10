#ifndef MOCK_GPIO_H
#define MOCK_GPIO_H

#include "hal/gpio_hal.h"
#include <map>

class MockGpio : public IGpioHal {
public:
    std::map<int, int> pin_modes;
    std::map<int, int> pin_values;
    std::map<int, int> analog_values;
    int tone_pin = -1;
    uint32_t tone_freq = 0;
    bool tone_active = false;
    unsigned long current_millis = 0;

    void pinMode(int pin, int mode) override {
        pin_modes[pin] = mode;
    }

    void digitalWrite(int pin, int value) override {
        pin_values[pin] = value;
    }

    int digitalRead(int pin) override {
        auto it = pin_values.find(pin);
        return (it != pin_values.end()) ? it->second : 0;
    }

    int analogRead(int pin) override {
        auto it = analog_values.find(pin);
        return (it != analog_values.end()) ? it->second : 0;
    }

    void toneStart(int pin, uint32_t frequency) override {
        tone_pin = pin;
        tone_freq = frequency;
        tone_active = true;
    }

    void toneStop(int pin) override {
        if (tone_pin == pin) {
            tone_active = false;
            tone_freq = 0;
        }
    }

    unsigned long millis() override {
        return current_millis;
    }

    void advanceMillis(unsigned long ms) {
        current_millis += ms;
    }
};

#endif
