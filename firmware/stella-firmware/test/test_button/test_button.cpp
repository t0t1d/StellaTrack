#include <unity.h>
#include "config.h"
#include "button_handler.h"
#include "mock_gpio.h"

static int s_short_calls;
static void* s_short_ctx_seen;

static void short_cb(void* ctx) {
    s_short_calls++;
    s_short_ctx_seen = ctx;
}

static int s_long_calls;
static void* s_long_ctx_seen;

static void long_cb(void* ctx) {
    s_long_calls++;
    s_long_ctx_seen = ctx;
}

void setUp(void) {
    s_short_calls = 0;
    s_short_ctx_seen = nullptr;
    s_long_calls = 0;
    s_long_ctx_seen = nullptr;
}

void tearDown(void) {}

void test_begin_configures_button_pin_as_input_pullup(void) {
    MockGpio gpio;
    ButtonHandler btn(&gpio);
    btn.begin();

    TEST_ASSERT_TRUE(gpio.pin_modes.count(PIN_BUTTON_USER) > 0);
    TEST_ASSERT_EQUAL(2, gpio.pin_modes[PIN_BUTTON_USER]);
}

void test_update_detects_debounced_press_active_low(void) {
    MockGpio gpio;
    gpio.pin_values[PIN_BUTTON_USER] = 1;
    ButtonHandler btn(&gpio);
    btn.begin();
    btn.update();

    gpio.pin_values[PIN_BUTTON_USER] = 0;
    gpio.advanceMillis(50);
    btn.update();

    gpio.pin_values[PIN_BUTTON_USER] = 1;
    gpio.advanceMillis(50);
    btn.update();

    TEST_ASSERT_TRUE(btn.wasPressed());
}

void test_update_debounce_ignores_transitions_faster_than_50ms(void) {
    MockGpio gpio;
    gpio.pin_values[PIN_BUTTON_USER] = 1;
    ButtonHandler btn(&gpio);
    btn.begin();
    btn.update();

    gpio.pin_values[PIN_BUTTON_USER] = 0;
    btn.update();
    gpio.advanceMillis(49);
    gpio.pin_values[PIN_BUTTON_USER] = 1;
    btn.update();
    gpio.advanceMillis(100);
    btn.update();

    TEST_ASSERT_FALSE(btn.wasPressed());
}

void test_was_pressed_returns_true_once_then_resets(void) {
    MockGpio gpio;
    gpio.pin_values[PIN_BUTTON_USER] = 1;
    ButtonHandler btn(&gpio);
    btn.begin();
    btn.update();

    gpio.pin_values[PIN_BUTTON_USER] = 0;
    gpio.advanceMillis(50);
    btn.update();
    gpio.pin_values[PIN_BUTTON_USER] = 1;
    gpio.advanceMillis(50);
    btn.update();

    TEST_ASSERT_TRUE(btn.wasPressed());
    TEST_ASSERT_FALSE(btn.wasPressed());
}

void test_was_long_pressed_true_when_held_over_2_seconds(void) {
    MockGpio gpio;
    gpio.pin_values[PIN_BUTTON_USER] = 1;
    ButtonHandler btn(&gpio);
    btn.begin();
    btn.update();

    gpio.pin_values[PIN_BUTTON_USER] = 0;
    gpio.advanceMillis(50);
    btn.update();
    gpio.advanceMillis(2000);
    btn.update();

    TEST_ASSERT_TRUE(btn.wasLongPressed());
}

void test_was_long_pressed_false_for_short_press(void) {
    MockGpio gpio;
    gpio.pin_values[PIN_BUTTON_USER] = 1;
    ButtonHandler btn(&gpio);
    btn.begin();
    btn.update();

    gpio.pin_values[PIN_BUTTON_USER] = 0;
    gpio.advanceMillis(50);
    btn.update();
    gpio.pin_values[PIN_BUTTON_USER] = 1;
    gpio.advanceMillis(50);
    btn.update();

    TEST_ASSERT_TRUE(btn.wasPressed());
    TEST_ASSERT_FALSE(btn.wasLongPressed());
}

void test_short_press_invokes_short_callback(void) {
    MockGpio gpio;
    gpio.pin_values[PIN_BUTTON_USER] = 1;
    ButtonHandler btn(&gpio);
    int marker = 42;
    btn.setOnShortPress(short_cb, &marker);
    btn.begin();
    btn.update();

    gpio.pin_values[PIN_BUTTON_USER] = 0;
    gpio.advanceMillis(50);
    btn.update();
    gpio.pin_values[PIN_BUTTON_USER] = 1;
    gpio.advanceMillis(50);
    btn.update();

    TEST_ASSERT_EQUAL(1, s_short_calls);
    TEST_ASSERT_EQUAL_PTR(&marker, s_short_ctx_seen);
}

void test_long_press_invokes_long_callback(void) {
    MockGpio gpio;
    gpio.pin_values[PIN_BUTTON_USER] = 1;
    ButtonHandler btn(&gpio);
    int marker = 7;
    btn.setOnLongPress(long_cb, &marker);
    btn.begin();
    btn.update();

    gpio.pin_values[PIN_BUTTON_USER] = 0;
    gpio.advanceMillis(50);
    btn.update();
    gpio.advanceMillis(2000);
    btn.update();

    TEST_ASSERT_EQUAL(1, s_long_calls);
    TEST_ASSERT_EQUAL_PTR(&marker, s_long_ctx_seen);
}

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    UNITY_BEGIN();
    RUN_TEST(test_begin_configures_button_pin_as_input_pullup);
    RUN_TEST(test_update_detects_debounced_press_active_low);
    RUN_TEST(test_update_debounce_ignores_transitions_faster_than_50ms);
    RUN_TEST(test_was_pressed_returns_true_once_then_resets);
    RUN_TEST(test_was_long_pressed_true_when_held_over_2_seconds);
    RUN_TEST(test_was_long_pressed_false_for_short_press);
    RUN_TEST(test_short_press_invokes_short_callback);
    RUN_TEST(test_long_press_invokes_long_callback);
    return UNITY_END();
}
