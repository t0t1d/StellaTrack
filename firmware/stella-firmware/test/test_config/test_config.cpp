#include <unity.h>
#include "config.h"
#include <cstring>

void setUp(void) {}
void tearDown(void) {}

void test_service_uuid_defined(void) {
    TEST_ASSERT_TRUE(strlen(SERVICE_UUID) > 0);
    TEST_ASSERT_EQUAL_STRING("A0E9F8B0-1234-5678-ABCD-0123456789AB", SERVICE_UUID);
}

void test_characteristic_uuids_are_unique(void) {
    TEST_ASSERT_NOT_EQUAL(0, strcmp(CHAR_UWB_CONFIG_OUT_UUID, CHAR_UWB_CONFIG_IN_UUID));
    TEST_ASSERT_NOT_EQUAL(0, strcmp(CHAR_UWB_CONFIG_OUT_UUID, CHAR_BATTERY_UUID));
    TEST_ASSERT_NOT_EQUAL(0, strcmp(CHAR_UWB_CONFIG_OUT_UUID, CHAR_COMMAND_UUID));
    TEST_ASSERT_NOT_EQUAL(0, strcmp(CHAR_UWB_CONFIG_OUT_UUID, CHAR_DEVICE_INFO_UUID));
    TEST_ASSERT_NOT_EQUAL(0, strcmp(CHAR_BATTERY_UUID, CHAR_COMMAND_UUID));
}

void test_uuid_suffix_pattern(void) {
    // All characteristic UUIDs share the same base, differ only in first segment
    const char* base = "-1234-5678-ABCD-0123456789AB";
    TEST_ASSERT_NOT_NULL(strstr(CHAR_UWB_CONFIG_OUT_UUID, base));
    TEST_ASSERT_NOT_NULL(strstr(CHAR_UWB_CONFIG_IN_UUID, base));
    TEST_ASSERT_NOT_NULL(strstr(CHAR_BATTERY_UUID, base));
    TEST_ASSERT_NOT_NULL(strstr(CHAR_COMMAND_UUID, base));
    TEST_ASSERT_NOT_NULL(strstr(CHAR_DEVICE_INFO_UUID, base));
}

void test_ble_timing_constants(void) {
    TEST_ASSERT_EQUAL(100, BLE_ADV_INTERVAL_MS);
    TEST_ASSERT_EQUAL(30000, BLE_RECONNECT_TIMEOUT_MS);
    TEST_ASSERT_EQUAL(60000, BLE_ADV_TIMEOUT_MS);
}

void test_pin_definitions(void) {
    TEST_ASSERT_TRUE(PIN_BUZZER >= 0);
    TEST_ASSERT_TRUE(PIN_LED_USER >= 0);
    TEST_ASSERT_TRUE(PIN_BUTTON_USER >= 0);
}

void test_buzzer_frequency(void) {
    TEST_ASSERT_EQUAL(4000, BUZZER_FREQ_HZ);
}

void test_uwb_ranging_rates(void) {
    TEST_ASSERT_EQUAL(10, UWB_RANGING_RATE_ACTIVE_HZ);
    TEST_ASSERT_EQUAL(1, UWB_RANGING_RATE_IDLE_HZ);
    TEST_ASSERT_TRUE(UWB_RANGING_RATE_ACTIVE_HZ > UWB_RANGING_RATE_IDLE_HZ);
}

void test_uwb_config_buffer_size(void) {
    TEST_ASSERT_EQUAL(128, UWB_CONFIG_MAX_SIZE);
}

void test_power_management_constants(void) {
    TEST_ASSERT_FLOAT_WITHIN(0.01f, 0.1f, MOTION_THRESHOLD_G);
    TEST_ASSERT_EQUAL(10000, MOTION_TIMEOUT_MS);
    TEST_ASSERT_EQUAL(60000, SLEEP_TIMEOUT_MS);
}

void test_battery_constants(void) {
    TEST_ASSERT_EQUAL(30000, BATTERY_REPORT_INTERVAL_MS);
    TEST_ASSERT_TRUE(BATTERY_MV_FULL > BATTERY_MV_EMPTY);
}

void test_max_bonds(void) {
    TEST_ASSERT_EQUAL(4, MAX_BONDS);
}

void test_command_codes_are_sequential(void) {
    TEST_ASSERT_EQUAL(0x01, CMD_PLAY_SOUND);
    TEST_ASSERT_EQUAL(0x02, CMD_STOP_SOUND);
    TEST_ASSERT_EQUAL(0x03, CMD_LED_ON);
    TEST_ASSERT_EQUAL(0x04, CMD_LED_OFF);
    TEST_ASSERT_EQUAL(0x05, CMD_SET_RANGING_RATE);
    TEST_ASSERT_EQUAL(0x06, CMD_PING);
}

void test_device_states_defined(void) {
    DeviceState s = DeviceState::Idle;
    TEST_ASSERT_EQUAL(static_cast<uint8_t>(DeviceState::Idle), 0);
    TEST_ASSERT_TRUE(static_cast<uint8_t>(DeviceState::Sleep) > 0);
    (void)s;
}

void test_firmware_version(void) {
    TEST_ASSERT_EQUAL_STRING("1.0.0", FW_VERSION);
    TEST_ASSERT_EQUAL_STRING("ABX00131", HW_MODEL);
}

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    UNITY_BEGIN();
    RUN_TEST(test_service_uuid_defined);
    RUN_TEST(test_characteristic_uuids_are_unique);
    RUN_TEST(test_uuid_suffix_pattern);
    RUN_TEST(test_ble_timing_constants);
    RUN_TEST(test_pin_definitions);
    RUN_TEST(test_buzzer_frequency);
    RUN_TEST(test_uwb_ranging_rates);
    RUN_TEST(test_uwb_config_buffer_size);
    RUN_TEST(test_power_management_constants);
    RUN_TEST(test_battery_constants);
    RUN_TEST(test_max_bonds);
    RUN_TEST(test_command_codes_are_sequential);
    RUN_TEST(test_device_states_defined);
    RUN_TEST(test_firmware_version);
    return UNITY_END();
}
