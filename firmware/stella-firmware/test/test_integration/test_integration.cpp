#ifndef A0
#define A0 14
#endif

#include <unity.h>
#include <cstring>
#include <vector>

#include "config.h"
#include "firmware_controller.h"
#include "mock_accel.h"
#include "mock_ble.h"
#include "mock_gpio.h"
#include "mock_uwb.h"

static MockGpio s_gpio;
static MockBle s_ble;
static MockUwb s_uwb;
static MockAccel s_accel;
static FirmwareController* s_fw = nullptr;

static void reset_mocks() {
    s_gpio = MockGpio();
    s_ble = MockBle();
    s_uwb = MockUwb();
    s_accel = MockAccel();
    s_uwb.fake_accessory_config = {0xC0, 0xFF, 0xEE};
}

void setUp(void) {
    reset_mocks();
    if (s_fw) {
        delete s_fw;
        s_fw = nullptr;
    }
    s_fw = new FirmwareController(&s_gpio, &s_ble, &s_uwb, &s_accel);
}

void tearDown(void) {
    delete s_fw;
    s_fw = nullptr;
}

void test_begin_initializes_all_subsystems(void) {
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());

    TEST_ASSERT_TRUE(s_ble.initialized);
    TEST_ASSERT_TRUE(s_uwb.initialized);
    TEST_ASSERT_TRUE(s_accel.initialized);

    TEST_ASSERT_TRUE(s_gpio.pin_modes.count(PIN_BUZZER) > 0);
    TEST_ASSERT_TRUE(s_gpio.pin_modes.count(PIN_LED_USER) > 0);
    TEST_ASSERT_TRUE(s_gpio.pin_modes.count(PIN_BUTTON_USER) > 0);
}

void test_after_begin_ble_advertising_is_active(void) {
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());
    TEST_ASSERT_TRUE(s_ble.advertising);
}

void test_on_ble_connect_uwb_config_written_to_characteristic(void) {
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());
    s_ble.simulateConnect();

    auto it = s_ble.characteristics.find(CHAR_UWB_CONFIG_OUT_UUID);
    TEST_ASSERT_TRUE(it != s_ble.characteristics.end());
    TEST_ASSERT_EQUAL_UINT32(s_uwb.fake_accessory_config.size(), it->second.data.size());
    TEST_ASSERT_EQUAL_HEX8_ARRAY(
        s_uwb.fake_accessory_config.data(),
        it->second.data.data(),
        s_uwb.fake_accessory_config.size());
}

void test_on_uwb_config_in_ranging_starts(void) {
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());
    s_ble.simulateConnect();

    const uint8_t ios_cfg[] = {0x10, 0x20, 0x30};
    s_ble.simulateWrite(CHAR_UWB_CONFIG_IN_UUID, ios_cfg, sizeof(ios_cfg));

    TEST_ASSERT_TRUE(s_uwb.ranging);
    TEST_ASSERT_EQUAL_UINT32(sizeof(ios_cfg), s_uwb.last_ios_config.size());
    TEST_ASSERT_EQUAL_HEX8_ARRAY(ios_cfg, s_uwb.last_ios_config.data(), sizeof(ios_cfg));
}

void test_while_ranging_power_recommended_rate_applied(void) {
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());
    s_ble.simulateConnect();

    const uint8_t ios_cfg[] = {0x01};
    s_ble.simulateWrite(CHAR_UWB_CONFIG_IN_UUID, ios_cfg, sizeof(ios_cfg));
    TEST_ASSERT_TRUE(s_uwb.ranging);

    s_accel.fake_magnitude = MOTION_THRESHOLD_G + 0.05f;
    s_fw->update();
    TEST_ASSERT_EQUAL_UINT8(UWB_RANGING_RATE_ACTIVE_HZ, s_uwb.ranging_rate);

    s_accel.fake_magnitude = 0.0f;
    s_gpio.advanceMillis(MOTION_TIMEOUT_MS);
    s_fw->update();
    TEST_ASSERT_EQUAL_UINT8(UWB_RANGING_RATE_IDLE_HZ, s_uwb.ranging_rate);
}

void test_on_command_write_play_sound_activates_buzzer(void) {
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());

    const uint8_t cmd[] = {CMD_PLAY_SOUND, 0};
    s_ble.simulateWrite(CHAR_COMMAND_UUID, cmd, sizeof(cmd));

    TEST_ASSERT_TRUE(s_gpio.tone_active);
    TEST_ASSERT_EQUAL_INT(PIN_BUZZER, s_gpio.tone_pin);
    TEST_ASSERT_EQUAL_UINT32(BUZZER_FREQ_HZ, s_gpio.tone_freq);
}

void test_on_ble_disconnect_advertising_restarts_after_timeout(void) {
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());
    TEST_ASSERT_TRUE(s_ble.advertising);

    s_ble.simulateConnect();
    TEST_ASSERT_FALSE(s_ble.advertising);

    s_ble.simulateDisconnect();
    TEST_ASSERT_FALSE(s_ble.advertising);

    s_gpio.advanceMillis(BLE_RECONNECT_TIMEOUT_MS);
    s_fw->update();
    TEST_ASSERT_TRUE(s_ble.advertising);
}

void test_battery_level_reported_periodically(void) {
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());
    s_ble.simulateConnect();

    s_gpio.analog_values[0] = 2500;
    const int expected_pct = 50;

    s_gpio.advanceMillis(BATTERY_REPORT_INTERVAL_MS);
    s_fw->update();

    auto it = s_ble.characteristics.find(CHAR_BATTERY_UUID);
    TEST_ASSERT_TRUE(it != s_ble.characteristics.end());
    TEST_ASSERT_EQUAL_UINT32(1, it->second.data.size());
    TEST_ASSERT_EQUAL_UINT8(static_cast<uint8_t>(expected_pct), it->second.data[0]);
}

void test_button_short_press_triggers_buzzer(void) {
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());

    s_gpio.pin_values[PIN_BUTTON_USER] = 0;
    s_gpio.advanceMillis(50);
    s_fw->update();

    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    s_gpio.advanceMillis(50);
    s_fw->update();

    TEST_ASSERT_TRUE(s_gpio.tone_active);
    TEST_ASSERT_EQUAL_INT(PIN_BUZZER, s_gpio.tone_pin);
}

// --- Bonding integration tests ---

void test_button_long_press_enters_pairing_mode(void) {
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());
    TEST_ASSERT_FALSE(s_fw->isPairingMode());

    s_gpio.pin_values[PIN_BUTTON_USER] = 0;
    s_gpio.advanceMillis(50);
    s_fw->update();

    s_gpio.advanceMillis(2000);
    s_fw->update();

    TEST_ASSERT_TRUE(s_fw->isPairingMode());
}

void test_bonding_manager_accessible(void) {
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());
    TEST_ASSERT_EQUAL_UINT8(0, s_fw->getBondCount());
}

void test_led_blinks_during_pairing_mode(void) {
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());

    s_gpio.pin_values[PIN_BUTTON_USER] = 0;
    s_gpio.advanceMillis(50);
    s_fw->update();
    s_gpio.advanceMillis(2000);
    s_fw->update();
    TEST_ASSERT_TRUE(s_fw->isPairingMode());

    s_gpio.advanceMillis(500);
    s_fw->update();
    int led_val_a = s_gpio.pin_values[PIN_LED_USER];
    s_gpio.advanceMillis(500);
    s_fw->update();
    int led_val_b = s_gpio.pin_values[PIN_LED_USER];

    TEST_ASSERT_NOT_EQUAL(led_val_a, led_val_b);
}

void test_command_stop_sound_after_button_buzzer(void) {
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());

    s_gpio.pin_values[PIN_BUTTON_USER] = 0;
    s_gpio.advanceMillis(50);
    s_fw->update();
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    s_gpio.advanceMillis(50);
    s_fw->update();
    TEST_ASSERT_TRUE(s_gpio.tone_active);

    const uint8_t cmd[] = {CMD_STOP_SOUND, 0};
    s_ble.simulateWrite(CHAR_COMMAND_UUID, cmd, sizeof(cmd));
    TEST_ASSERT_FALSE(s_gpio.tone_active);
}

void test_led_on_off_via_ble_command(void) {
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());

    const uint8_t on_cmd[] = {CMD_LED_ON, 0};
    s_ble.simulateWrite(CHAR_COMMAND_UUID, on_cmd, sizeof(on_cmd));
    TEST_ASSERT_EQUAL(1, s_gpio.pin_values[PIN_LED_USER]);

    const uint8_t off_cmd[] = {CMD_LED_OFF, 0};
    s_ble.simulateWrite(CHAR_COMMAND_UUID, off_cmd, sizeof(off_cmd));
    TEST_ASSERT_EQUAL(0, s_gpio.pin_values[PIN_LED_USER]);
}

void test_uwb_ranging_stops_on_disconnect(void) {
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());
    s_ble.simulateConnect();

    const uint8_t ios_cfg[] = {0xAA};
    s_ble.simulateWrite(CHAR_UWB_CONFIG_IN_UUID, ios_cfg, sizeof(ios_cfg));
    TEST_ASSERT_TRUE(s_uwb.ranging);

    s_ble.simulateDisconnect();
    TEST_ASSERT_FALSE(s_uwb.ranging);
}

void test_set_ranging_rate_via_ble_command(void) {
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());
    s_ble.simulateConnect();

    const uint8_t ios_cfg[] = {0x01};
    s_ble.simulateWrite(CHAR_UWB_CONFIG_IN_UUID, ios_cfg, sizeof(ios_cfg));
    TEST_ASSERT_TRUE(s_uwb.ranging);

    const uint8_t cmd[] = {CMD_SET_RANGING_RATE, 5};
    s_ble.simulateWrite(CHAR_COMMAND_UUID, cmd, sizeof(cmd));

    s_fw->update();
    TEST_ASSERT_EQUAL_UINT8(5, s_uwb.ranging_rate);
}

void test_short_press_during_pairing_confirms_pairing(void) {
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());

    s_gpio.pin_values[PIN_BUTTON_USER] = 0;
    s_gpio.advanceMillis(50);
    s_fw->update();
    s_gpio.advanceMillis(2000);
    s_fw->update();
    TEST_ASSERT_TRUE(s_fw->isPairingMode());

    const uint8_t addr[6] = {0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF};
    s_fw->setPendingPairAddress(addr);

    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    s_gpio.advanceMillis(50);
    s_fw->update();

    s_gpio.pin_values[PIN_BUTTON_USER] = 0;
    s_gpio.advanceMillis(50);
    s_fw->update();
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    s_gpio.advanceMillis(50);
    s_fw->update();

    TEST_ASSERT_FALSE(s_fw->isPairingMode());
    TEST_ASSERT_EQUAL_UINT8(1, s_fw->getBondCount());
    TEST_ASSERT_FALSE(s_gpio.tone_active);
}

void test_short_press_outside_pairing_still_plays_sound(void) {
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());

    s_gpio.pin_values[PIN_BUTTON_USER] = 0;
    s_gpio.advanceMillis(50);
    s_fw->update();
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    s_gpio.advanceMillis(50);
    s_fw->update();

    TEST_ASSERT_TRUE(s_gpio.tone_active);
}

void test_uwb_config_failure_on_connect_signals_error(void) {
    s_uwb.fake_accessory_config.clear();
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());
    s_ble.simulateConnect();

    TEST_ASSERT_TRUE(s_fw->hasConfigError());
    auto it = s_ble.characteristics.find(CHAR_UWB_CONFIG_OUT_UUID);
    TEST_ASSERT_TRUE(it != s_ble.characteristics.end());
    TEST_ASSERT_EQUAL_UINT32(1, it->second.data.size());
    TEST_ASSERT_EQUAL_UINT8(0, it->second.data[0]);
}

void test_ping_command_reports_battery(void) {
    s_gpio.pin_values[PIN_BUTTON_USER] = 1;
    TEST_ASSERT_TRUE(s_fw->begin());
    s_ble.simulateConnect();

    s_gpio.analog_values[0] = 2800;
    const int expected_pct = 80;

    const uint8_t cmd[] = {CMD_PING, 0};
    s_ble.simulateWrite(CHAR_COMMAND_UUID, cmd, sizeof(cmd));

    auto it = s_ble.characteristics.find(CHAR_BATTERY_UUID);
    TEST_ASSERT_TRUE(it != s_ble.characteristics.end());
    TEST_ASSERT_EQUAL_UINT32(1, it->second.data.size());
    TEST_ASSERT_EQUAL_UINT8(static_cast<uint8_t>(expected_pct), it->second.data[0]);
}

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    UNITY_BEGIN();
    RUN_TEST(test_begin_initializes_all_subsystems);
    RUN_TEST(test_after_begin_ble_advertising_is_active);
    RUN_TEST(test_on_ble_connect_uwb_config_written_to_characteristic);
    RUN_TEST(test_on_uwb_config_in_ranging_starts);
    RUN_TEST(test_while_ranging_power_recommended_rate_applied);
    RUN_TEST(test_on_command_write_play_sound_activates_buzzer);
    RUN_TEST(test_on_ble_disconnect_advertising_restarts_after_timeout);
    RUN_TEST(test_battery_level_reported_periodically);
    RUN_TEST(test_button_short_press_triggers_buzzer);
    RUN_TEST(test_button_long_press_enters_pairing_mode);
    RUN_TEST(test_bonding_manager_accessible);
    RUN_TEST(test_led_blinks_during_pairing_mode);
    RUN_TEST(test_command_stop_sound_after_button_buzzer);
    RUN_TEST(test_led_on_off_via_ble_command);
    RUN_TEST(test_uwb_ranging_stops_on_disconnect);
    RUN_TEST(test_set_ranging_rate_via_ble_command);
    RUN_TEST(test_short_press_during_pairing_confirms_pairing);
    RUN_TEST(test_short_press_outside_pairing_still_plays_sound);
    RUN_TEST(test_uwb_config_failure_on_connect_signals_error);
    RUN_TEST(test_ping_command_reports_battery);
    return UNITY_END();
}
