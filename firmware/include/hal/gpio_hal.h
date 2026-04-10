#ifndef STELLA_GPIO_HAL_H
#define STELLA_GPIO_HAL_H

#include <stdint.h>

class IGpioHal {
public:
    virtual ~IGpioHal() = default;

    virtual void pinMode(int pin, int mode) = 0;
    virtual void digitalWrite(int pin, int value) = 0;
    virtual int  digitalRead(int pin) = 0;
    virtual int  analogRead(int pin) = 0;

    virtual void toneStart(int pin, uint32_t frequency) = 0;
    virtual void toneStop(int pin) = 0;

    virtual unsigned long millis() = 0;
};

#endif
