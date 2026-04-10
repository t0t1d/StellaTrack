#include "button_handler.h"
#include "config.h"

namespace {
const unsigned long kDebounceMs = 50;
const unsigned long kLongPressMs = 2000;
// Arduino INPUT_PULLUP (native tests expect mode value 2)
const int kInputPullup = 2;
}  // namespace

ButtonHandler::ButtonHandler(IGpioHal* gpio)
    : gpio_(gpio),
      on_short_(nullptr),
      short_ctx_(nullptr),
      on_long_(nullptr),
      long_ctx_(nullptr),
      stable_level_(1),
      transient_level_(1),
      transient_since_(0),
      last_update_ms_(0),
      press_start_ms_(0),
      long_fired_this_press_(false),
      was_pressed_latch_(false),
      was_long_pressed_latch_(false) {}

void ButtonHandler::begin() {
    gpio_->pinMode(PIN_BUTTON_USER, kInputPullup);
    unsigned long now = gpio_->millis();
    int r = gpio_->digitalRead(PIN_BUTTON_USER);
    stable_level_ = r;
    transient_level_ = r;
    transient_since_ = now;
    last_update_ms_ = now;
    long_fired_this_press_ = false;
    was_pressed_latch_ = false;
    was_long_pressed_latch_ = false;
}

void ButtonHandler::update() {
    unsigned long now = gpio_->millis();
    int r = gpio_->digitalRead(PIN_BUTTON_USER);

    if (r != transient_level_) {
        transient_level_ = r;
        transient_since_ = last_update_ms_;
    }
    if (r == transient_level_ && (now - transient_since_ >= kDebounceMs)) {
        if (transient_level_ != stable_level_) {
            int prev = stable_level_;
            stable_level_ = transient_level_;
            if (prev == 1 && stable_level_ == 0) {
                press_start_ms_ = now;
                long_fired_this_press_ = false;
            } else if (prev == 0 && stable_level_ == 1) {
                if (!long_fired_this_press_) {
                    was_pressed_latch_ = true;
                    if (on_short_) {
                        on_short_(short_ctx_);
                    }
                }
            }
        }
    }

    if (stable_level_ == 0 && !long_fired_this_press_ &&
        (now - press_start_ms_ >= kLongPressMs)) {
        long_fired_this_press_ = true;
        was_long_pressed_latch_ = true;
        if (on_long_) {
            on_long_(long_ctx_);
        }
    }

    last_update_ms_ = now;
}

bool ButtonHandler::wasPressed() {
    bool v = was_pressed_latch_;
    was_pressed_latch_ = false;
    return v;
}

bool ButtonHandler::wasLongPressed() {
    bool v = was_long_pressed_latch_;
    was_long_pressed_latch_ = false;
    return v;
}

void ButtonHandler::setOnShortPress(void (*cb)(void*), void* ctx) {
    on_short_ = cb;
    short_ctx_ = ctx;
}

void ButtonHandler::setOnLongPress(void (*cb)(void*), void* ctx) {
    on_long_ = cb;
    long_ctx_ = ctx;
}
