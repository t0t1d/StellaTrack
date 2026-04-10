#include <unity.h>
#include "config.h"
#include "led_indicator.h"
#include "mock_gpio.h"

static MockGpio gpio;
static LedIndicator led;

void setUp(void) {
    gpio = MockGpio();
    led = LedIndicator(&gpio, PIN_LED_USER);
    led.begin();
}

void tearDown(void) {}

// --- Initialization ---

void test_begin_configures_led_pin_as_output(void) {
    TEST_ASSERT_TRUE(gpio.pin_modes.count(PIN_LED_USER) > 0);
}

void test_begin_led_starts_off(void) {
    TEST_ASSERT_EQUAL(0, gpio.pin_values[PIN_LED_USER]);
}

// --- USB blink mode ---

void test_usb_blink_toggles_led_every_1000ms(void) {
    led.setUsbPowered(true);
    led.update();
    int initial = gpio.pin_values[PIN_LED_USER];

    gpio.advanceMillis(999);
    led.update();
    TEST_ASSERT_EQUAL(initial, gpio.pin_values[PIN_LED_USER]);

    gpio.advanceMillis(1);
    led.update();
    TEST_ASSERT_NOT_EQUAL(initial, gpio.pin_values[PIN_LED_USER]);
}

void test_usb_blink_stops_when_switched_to_battery(void) {
    led.setUsbPowered(true);
    led.update();
    TEST_ASSERT_EQUAL(1, gpio.pin_values[PIN_LED_USER]);

    led.setUsbPowered(false);
    led.update();
    TEST_ASSERT_EQUAL(0, gpio.pin_values[PIN_LED_USER]);
}

void test_battery_powered_led_stays_off(void) {
    led.setUsbPowered(false);
    gpio.advanceMillis(5000);
    led.update();
    TEST_ASSERT_EQUAL(0, gpio.pin_values[PIN_LED_USER]);
}

// --- BLE connect acknowledgment ---

void test_ack_blink_flashes_3_times_on_usb(void) {
    led.setUsbPowered(true);
    led.triggerAckBlink();

    // trigger sets LED ON; then 5 toggles = 3 complete ON-OFF flashes
    int toggles = 0;
    int prev = gpio.pin_values[PIN_LED_USER];
    for (int i = 0; i < 10; i++) {
        gpio.advanceMillis(120);
        led.update();
        if (gpio.pin_values[PIN_LED_USER] != prev) {
            toggles++;
            prev = gpio.pin_values[PIN_LED_USER];
        }
    }
    TEST_ASSERT_EQUAL(5, toggles);
    TEST_ASSERT_EQUAL(0, gpio.pin_values[PIN_LED_USER]);
}

void test_ack_blink_flashes_3_times_on_battery(void) {
    led.setUsbPowered(false);
    led.triggerAckBlink();

    int toggles = 0;
    int prev = gpio.pin_values[PIN_LED_USER];
    for (int i = 0; i < 10; i++) {
        gpio.advanceMillis(120);
        led.update();
        if (gpio.pin_values[PIN_LED_USER] != prev) {
            toggles++;
            prev = gpio.pin_values[PIN_LED_USER];
        }
    }
    TEST_ASSERT_EQUAL(5, toggles);
    TEST_ASSERT_EQUAL(0, gpio.pin_values[PIN_LED_USER]);
}

void test_ack_blink_returns_to_usb_blink_after(void) {
    led.setUsbPowered(true);
    led.triggerAckBlink();

    // Fast-forward past ack blink (6 toggles * 120ms = 720ms + margin)
    gpio.advanceMillis(1500);
    for (int i = 0; i < 15; i++) {
        led.update();
        gpio.advanceMillis(120);
    }

    // Should now be in USB blink mode - LED toggles every 1000ms
    int val_before = gpio.pin_values[PIN_LED_USER];
    gpio.advanceMillis(1000);
    led.update();
    TEST_ASSERT_NOT_EQUAL(val_before, gpio.pin_values[PIN_LED_USER]);
}

void test_ack_blink_returns_to_off_on_battery_after(void) {
    led.setUsbPowered(false);
    led.triggerAckBlink();

    // Fast-forward past ack blink
    gpio.advanceMillis(2000);
    for (int i = 0; i < 20; i++) {
        led.update();
        gpio.advanceMillis(120);
    }

    TEST_ASSERT_EQUAL(0, gpio.pin_values[PIN_LED_USER]);
}

// --- Pairing mode override ---

void test_pairing_mode_suppresses_usb_blink(void) {
    led.setUsbPowered(true);
    led.setPairingMode(true);

    gpio.advanceMillis(2000);
    led.update();

    // LED state not changed by LedIndicator when pairing active
    TEST_ASSERT_EQUAL(0, gpio.pin_values[PIN_LED_USER]);
}

void test_pairing_mode_suppresses_ack_blink(void) {
    led.setPairingMode(true);
    led.triggerAckBlink();

    gpio.advanceMillis(500);
    led.update();

    TEST_ASSERT_EQUAL(0, gpio.pin_values[PIN_LED_USER]);
}

void test_resuming_from_pairing_restores_usb_blink(void) {
    led.setUsbPowered(true);
    led.setPairingMode(true);
    gpio.advanceMillis(5000);
    led.update();

    led.setPairingMode(false);
    gpio.advanceMillis(1000);
    led.update();
    int val = gpio.pin_values[PIN_LED_USER];
    gpio.advanceMillis(1000);
    led.update();
    TEST_ASSERT_NOT_EQUAL(val, gpio.pin_values[PIN_LED_USER]);
}

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    UNITY_BEGIN();
    RUN_TEST(test_begin_configures_led_pin_as_output);
    RUN_TEST(test_begin_led_starts_off);
    RUN_TEST(test_usb_blink_toggles_led_every_1000ms);
    RUN_TEST(test_usb_blink_stops_when_switched_to_battery);
    RUN_TEST(test_battery_powered_led_stays_off);
    RUN_TEST(test_ack_blink_flashes_3_times_on_usb);
    RUN_TEST(test_ack_blink_flashes_3_times_on_battery);
    RUN_TEST(test_ack_blink_returns_to_usb_blink_after);
    RUN_TEST(test_ack_blink_returns_to_off_on_battery_after);
    RUN_TEST(test_pairing_mode_suppresses_usb_blink);
    RUN_TEST(test_pairing_mode_suppresses_ack_blink);
    RUN_TEST(test_resuming_from_pairing_restores_usb_blink);
    return UNITY_END();
}
