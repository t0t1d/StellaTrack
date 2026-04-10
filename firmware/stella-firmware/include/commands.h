#ifndef STELLA_COMMANDS_H
#define STELLA_COMMANDS_H

#include "config.h"
#include "hal/gpio_hal.h"

class CommandHandler {
public:
    CommandHandler() : gpio_(nullptr) {}
    explicit CommandHandler(IGpioHal* gpio) : gpio_(gpio) {}

    void begin();
    void update();

    bool handleCommand(uint8_t code, uint8_t param);

    bool isBuzzerActive() const { return buzzer_active_; }
    bool isLedOn() const { return led_on_; }
    uint8_t getRequestedRangingRate() const { return requested_ranging_rate_; }

private:
    IGpioHal* gpio_;
    bool buzzer_active_ = false;
    bool led_on_ = false;
    unsigned long buzzer_end_time_ = 0;
    bool buzzer_timed_ = false;
    uint8_t requested_ranging_rate_ = UWB_RANGING_RATE_ACTIVE_HZ;
};

#endif
