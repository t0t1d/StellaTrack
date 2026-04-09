#include "commands.h"

void CommandHandler::begin() {
    gpio_->pinMode(PIN_BUZZER, 1);
    gpio_->pinMode(PIN_LED_USER, 1);
    gpio_->digitalWrite(PIN_LED_USER, 0);
    led_on_ = false;
    buzzer_active_ = false;
    buzzer_timed_ = false;
}

void CommandHandler::update() {
    if (buzzer_active_ && buzzer_timed_) {
        if (gpio_->millis() >= buzzer_end_time_) {
            gpio_->toneStop(PIN_BUZZER);
            buzzer_active_ = false;
            buzzer_timed_ = false;
        }
    }
}

bool CommandHandler::handleCommand(uint8_t code, uint8_t param) {
    switch (code) {
        case CMD_PLAY_SOUND: {
            uint8_t dur = (param == 0) ? BUZZER_DEFAULT_DURATION_S : param;
            gpio_->toneStart(PIN_BUZZER, BUZZER_FREQ_HZ);
            buzzer_active_ = true;
            buzzer_timed_ = true;
            buzzer_end_time_ = gpio_->millis() + (unsigned long)dur * 1000;
            return true;
        }

        case CMD_STOP_SOUND:
            gpio_->toneStop(PIN_BUZZER);
            buzzer_active_ = false;
            buzzer_timed_ = false;
            return true;

        case CMD_LED_ON:
            gpio_->digitalWrite(PIN_LED_USER, 1);
            led_on_ = true;
            return true;

        case CMD_LED_OFF:
            gpio_->digitalWrite(PIN_LED_USER, 0);
            led_on_ = false;
            return true;

        case CMD_SET_RANGING_RATE: {
            uint8_t rate = param;
            if (rate < 1) rate = 1;
            if (rate > 10) rate = 10;
            requested_ranging_rate_ = rate;
            return true;
        }

        case CMD_PING:
            return true;

        default:
            return false;
    }
}
