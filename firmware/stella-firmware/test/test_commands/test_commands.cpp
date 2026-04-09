#include <unity.h>
#include "config.h"
#include "commands.h"
#include "mock_gpio.h"

static MockGpio gpio;
static CommandHandler cmd;

void setUp(void) {
    gpio = MockGpio();
    cmd = CommandHandler(&gpio);
    cmd.begin();
}

void tearDown(void) {}

// --- Buzzer tests ---

void test_play_sound_activates_buzzer_at_4khz(void) {
    cmd.handleCommand(CMD_PLAY_SOUND, 0);

    TEST_ASSERT_TRUE(gpio.tone_active);
    TEST_ASSERT_EQUAL(PIN_BUZZER, gpio.tone_pin);
    TEST_ASSERT_EQUAL(BUZZER_FREQ_HZ, gpio.tone_freq);
}

void test_stop_sound_deactivates_buzzer(void) {
    cmd.handleCommand(CMD_PLAY_SOUND, 0);
    cmd.handleCommand(CMD_STOP_SOUND, 0);

    TEST_ASSERT_FALSE(gpio.tone_active);
}

void test_play_sound_with_duration_stores_end_time(void) {
    gpio.current_millis = 1000;
    cmd.handleCommand(CMD_PLAY_SOUND, 5);

    TEST_ASSERT_TRUE(gpio.tone_active);
    TEST_ASSERT_TRUE(cmd.isBuzzerActive());
}

void test_play_sound_with_duration_auto_stops(void) {
    gpio.current_millis = 1000;
    cmd.handleCommand(CMD_PLAY_SOUND, 2);
    TEST_ASSERT_TRUE(gpio.tone_active);

    gpio.current_millis = 2999;
    cmd.update();
    TEST_ASSERT_TRUE(gpio.tone_active);

    gpio.current_millis = 3001;
    cmd.update();
    TEST_ASSERT_FALSE(gpio.tone_active);
}

void test_play_sound_default_duration_3s_when_param_zero(void) {
    gpio.current_millis = 1000;
    cmd.handleCommand(CMD_PLAY_SOUND, 0);
    TEST_ASSERT_TRUE(gpio.tone_active);

    gpio.current_millis = 3999;
    cmd.update();
    TEST_ASSERT_TRUE(gpio.tone_active);

    gpio.current_millis = 4001;
    cmd.update();
    TEST_ASSERT_FALSE(gpio.tone_active);
}

// --- LED tests ---

void test_led_on_sets_pin_high(void) {
    cmd.handleCommand(CMD_LED_ON, 0);
    TEST_ASSERT_EQUAL(1, gpio.pin_values[PIN_LED_USER]);
}

void test_led_off_sets_pin_low(void) {
    cmd.handleCommand(CMD_LED_ON, 0);
    cmd.handleCommand(CMD_LED_OFF, 0);
    TEST_ASSERT_EQUAL(0, gpio.pin_values[PIN_LED_USER]);
}

void test_led_state_tracking(void) {
    TEST_ASSERT_FALSE(cmd.isLedOn());
    cmd.handleCommand(CMD_LED_ON, 0);
    TEST_ASSERT_TRUE(cmd.isLedOn());
    cmd.handleCommand(CMD_LED_OFF, 0);
    TEST_ASSERT_FALSE(cmd.isLedOn());
}

// --- Command dispatch tests ---

void test_unknown_command_returns_false(void) {
    TEST_ASSERT_FALSE(cmd.handleCommand(0xFF, 0));
}

void test_valid_commands_return_true(void) {
    TEST_ASSERT_TRUE(cmd.handleCommand(CMD_PLAY_SOUND, 0));
    TEST_ASSERT_TRUE(cmd.handleCommand(CMD_STOP_SOUND, 0));
    TEST_ASSERT_TRUE(cmd.handleCommand(CMD_LED_ON, 0));
    TEST_ASSERT_TRUE(cmd.handleCommand(CMD_LED_OFF, 0));
}

void test_set_ranging_rate_clamps_to_valid_range(void) {
    TEST_ASSERT_TRUE(cmd.handleCommand(CMD_SET_RANGING_RATE, 5));
    TEST_ASSERT_EQUAL(5, cmd.getRequestedRangingRate());

    cmd.handleCommand(CMD_SET_RANGING_RATE, 0);
    TEST_ASSERT_EQUAL(1, cmd.getRequestedRangingRate());

    cmd.handleCommand(CMD_SET_RANGING_RATE, 15);
    TEST_ASSERT_EQUAL(10, cmd.getRequestedRangingRate());
}

void test_ping_command_accepted(void) {
    TEST_ASSERT_TRUE(cmd.handleCommand(CMD_PING, 0));
}

// --- Begin initializes pins ---

void test_begin_configures_pins(void) {
    MockGpio fresh_gpio;
    CommandHandler fresh_cmd(&fresh_gpio);
    fresh_cmd.begin();

    TEST_ASSERT_TRUE(fresh_gpio.pin_modes.count(PIN_BUZZER) > 0);
    TEST_ASSERT_TRUE(fresh_gpio.pin_modes.count(PIN_LED_USER) > 0);
}

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    UNITY_BEGIN();
    RUN_TEST(test_play_sound_activates_buzzer_at_4khz);
    RUN_TEST(test_stop_sound_deactivates_buzzer);
    RUN_TEST(test_play_sound_with_duration_stores_end_time);
    RUN_TEST(test_play_sound_with_duration_auto_stops);
    RUN_TEST(test_play_sound_default_duration_3s_when_param_zero);
    RUN_TEST(test_led_on_sets_pin_high);
    RUN_TEST(test_led_off_sets_pin_low);
    RUN_TEST(test_led_state_tracking);
    RUN_TEST(test_unknown_command_returns_false);
    RUN_TEST(test_valid_commands_return_true);
    RUN_TEST(test_set_ranging_rate_clamps_to_valid_range);
    RUN_TEST(test_ping_command_accepted);
    RUN_TEST(test_begin_configures_pins);
    return UNITY_END();
}
