#include "led_indicator.h"

void LedIndicator::begin() {
    gpio_->pinMode(pin_, 1); // OUTPUT
    writeLed(false);
}

void LedIndicator::update() {
    if (pairing_) return;

    unsigned long now = gpio_->millis();

    if (mode_ == ACK_BLINK) {
        if (now - toggle_ms_ >= ACK_BLINK_INTERVAL) {
            toggle_ms_ = now;
            led_on_ = !led_on_;
            writeLed(led_on_);
            if (ack_remaining_ > 0) ack_remaining_--;
            if (ack_remaining_ == 0) {
                mode_ = usb_powered_ ? USB_BLINK : OFF;
                if (mode_ == OFF) {
                    led_on_ = false;
                    writeLed(false);
                }
            }
        }
        return;
    }

    if (usb_powered_ && mode_ != USB_BLINK) {
        mode_ = USB_BLINK;
        toggle_ms_ = now;
        led_on_ = true;
        writeLed(true);
    } else if (!usb_powered_ && mode_ == USB_BLINK) {
        mode_ = OFF;
        led_on_ = false;
        writeLed(false);
        return;
    }

    if (mode_ == USB_BLINK && now - toggle_ms_ >= USB_BLINK_INTERVAL) {
        toggle_ms_ = now;
        led_on_ = !led_on_;
        writeLed(led_on_);
    }
}

void LedIndicator::setUsbPowered(bool usb) {
    usb_powered_ = usb;
}

void LedIndicator::triggerAckBlink() {
    if (pairing_) return;
    mode_ = ACK_BLINK;
    ack_remaining_ = ACK_FLASH_COUNT * 2 - 1;
    led_on_ = true;
    toggle_ms_ = gpio_->millis();
    writeLed(true);
}

void LedIndicator::setPairingMode(bool active) {
    pairing_ = active;
    if (active) {
        led_on_ = false;
        writeLed(false);
    } else {
        mode_ = usb_powered_ ? USB_BLINK : OFF;
        toggle_ms_ = gpio_->millis();
    }
}

void LedIndicator::writeLed(bool on) {
    gpio_->digitalWrite(pin_, on ? 1 : 0);
}
