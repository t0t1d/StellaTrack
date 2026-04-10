#ifndef STELLA_BUTTON_HANDLER_H
#define STELLA_BUTTON_HANDLER_H

#include "hal/gpio_hal.h"

class ButtonHandler {
public:
    explicit ButtonHandler(IGpioHal* gpio);

    void begin();
    void update();

    bool wasPressed();
    bool wasLongPressed();

    void setOnShortPress(void (*cb)(void*), void* ctx);
    void setOnLongPress(void (*cb)(void*), void* ctx);

private:
    IGpioHal* gpio_;
    void (*on_short_)(void*);
    void* short_ctx_;
    void (*on_long_)(void*);
    void* long_ctx_;

    int stable_level_;
    int transient_level_;
    unsigned long transient_since_;
    unsigned long last_update_ms_;

    unsigned long press_start_ms_;
    bool long_fired_this_press_;
    bool was_pressed_latch_;
    bool was_long_pressed_latch_;
};

#endif
