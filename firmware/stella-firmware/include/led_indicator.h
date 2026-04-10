#ifndef STELLA_LED_INDICATOR_H
#define STELLA_LED_INDICATOR_H

#include "hal/gpio_hal.h"
#include <stdint.h>

class LedIndicator {
public:
    LedIndicator() : gpio_(nullptr), pin_(-1) {}
    LedIndicator(IGpioHal* gpio, int pin) : gpio_(gpio), pin_(pin) {}

    void begin();
    void update();

    void setUsbPowered(bool usb);
    void triggerAckBlink();
    void setPairingMode(bool active);

private:
    enum Mode : uint8_t { OFF, USB_BLINK, ACK_BLINK };

    IGpioHal* gpio_;
    int pin_;
    Mode mode_ = OFF;
    bool usb_powered_ = false;
    bool pairing_ = false;
    bool led_on_ = false;
    unsigned long toggle_ms_ = 0;
    uint8_t ack_remaining_ = 0;

    static const unsigned long USB_BLINK_INTERVAL = 1000;
    static const unsigned long ACK_BLINK_INTERVAL = 120;
    static const uint8_t ACK_FLASH_COUNT = 3;

    void writeLed(bool on);
};

#endif
