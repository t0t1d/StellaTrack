#include <unity.h>
#include "config.h"
#include "power_manager.h"
#include "mock_accel.h"
#include "mock_gpio.h"

static MockAccel accel;
static MockGpio gpio;
static PowerManager* pm = nullptr;

void setUp(void) {
    accel = MockAccel();
    gpio = MockGpio();
    pm = new PowerManager(&accel, &gpio);
}

void tearDown(void) {
    delete pm;
    pm = nullptr;
}

void test_begin_initializes_accelerometer(void) {
    TEST_ASSERT_FALSE(accel.initialized);
    pm->begin();
    TEST_ASSERT_TRUE(accel.initialized);
}

void test_motion_detected_when_magnitude_above_threshold(void) {
    pm->begin();
    accel.fake_magnitude = MOTION_THRESHOLD_G + 0.01f;
    TEST_ASSERT_TRUE(pm->isMotionDetected());
}

void test_motion_not_detected_at_or_below_threshold(void) {
    pm->begin();
    accel.fake_magnitude = MOTION_THRESHOLD_G;
    TEST_ASSERT_FALSE(pm->isMotionDetected());
    accel.fake_magnitude = MOTION_THRESHOLD_G - 0.01f;
    TEST_ASSERT_FALSE(pm->isMotionDetected());
}

void test_recommended_ranging_rate_active_when_motion(void) {
    pm->begin();
    accel.fake_magnitude = MOTION_THRESHOLD_G + 0.05f;
    TEST_ASSERT_EQUAL(UWB_RANGING_RATE_ACTIVE_HZ, pm->getRecommendedRangingRate());
}

void test_recommended_ranging_rate_idle_after_motion_timeout(void) {
    pm->begin();
    accel.fake_magnitude = MOTION_THRESHOLD_G + 0.05f;
    (void)pm->getRecommendedRangingRate();
    accel.fake_magnitude = 0.0f;
    gpio.advanceMillis(MOTION_TIMEOUT_MS);
    TEST_ASSERT_EQUAL(UWB_RANGING_RATE_IDLE_HZ, pm->getRecommendedRangingRate());
}

void test_recommended_ranging_rate_stays_active_if_motion_resumes_before_timeout(void) {
    pm->begin();
    accel.fake_magnitude = MOTION_THRESHOLD_G + 0.05f;
    (void)pm->getRecommendedRangingRate();
    accel.fake_magnitude = 0.0f;
    gpio.advanceMillis(MOTION_TIMEOUT_MS - 1);
    TEST_ASSERT_EQUAL(UWB_RANGING_RATE_ACTIVE_HZ, pm->getRecommendedRangingRate());
    accel.fake_magnitude = MOTION_THRESHOLD_G + 0.05f;
    TEST_ASSERT_EQUAL(UWB_RANGING_RATE_ACTIVE_HZ, pm->getRecommendedRangingRate());
}

void test_battery_percent_at_max_voltage(void) {
    pm->begin();
    // 3.0V -> ADC = 3.0/3.3 * 4095 ≈ 3723
    gpio.analog_values[BATTERY_ADC_PIN] = 3723;
    TEST_ASSERT_EQUAL(100, pm->readBatteryPercent());
}

void test_battery_percent_at_min_voltage(void) {
    pm->begin();
    // 2.0V -> ADC = 2.0/3.3 * 4095 ≈ 2482
    gpio.analog_values[BATTERY_ADC_PIN] = 2482;
    TEST_ASSERT_EQUAL(0, pm->readBatteryPercent());
}

void test_battery_percent_at_mid_voltage(void) {
    pm->begin();
    // 2.5V -> ADC = 2.5/3.3 * 4095 ≈ 3102
    gpio.analog_values[BATTERY_ADC_PIN] = 3102;
    TEST_ASSERT_EQUAL(50, pm->readBatteryPercent());
}

void test_battery_percent_clamps_to_range(void) {
    pm->begin();
    gpio.analog_values[BATTERY_ADC_PIN] = 0;
    TEST_ASSERT_EQUAL(0, pm->readBatteryPercent());
    gpio.analog_values[BATTERY_ADC_PIN] = 4095;
    TEST_ASSERT_EQUAL(100, pm->readBatteryPercent());
}

void test_should_report_battery_every_30s(void) {
    pm->begin();
    gpio.current_millis = 0;
    TEST_ASSERT_FALSE(pm->shouldReportBattery());
    gpio.advanceMillis(BATTERY_REPORT_INTERVAL_MS);
    TEST_ASSERT_TRUE(pm->shouldReportBattery());
    TEST_ASSERT_FALSE(pm->shouldReportBattery());
    gpio.advanceMillis(BATTERY_REPORT_INTERVAL_MS);
    TEST_ASSERT_TRUE(pm->shouldReportBattery());
}

void test_recommended_state_advertising_after_begin(void) {
    pm->begin();
    TEST_ASSERT_EQUAL(static_cast<int>(DeviceState::Advertising),
                      static_cast<int>(pm->getRecommendedState()));
}

void test_recommended_state_sleep_after_advertising_timeout(void) {
    pm->begin();
    gpio.advanceMillis(SLEEP_TIMEOUT_MS);
    TEST_ASSERT_EQUAL(static_cast<int>(DeviceState::Sleep),
                      static_cast<int>(pm->getRecommendedState()));
}

void test_recommended_state_advertising_after_long_disconnect_from_ble(void) {
    pm->begin();
    pm->notifyConnected();
    pm->notifyDisconnected();
    gpio.advanceMillis(BLE_RECONNECT_TIMEOUT_MS + 1);
    TEST_ASSERT_EQUAL(static_cast<int>(DeviceState::Advertising),
                      static_cast<int>(pm->getRecommendedState()));
}

void test_notify_connection_updates_tracking(void) {
    pm->begin();
    pm->notifyConnected();
    gpio.advanceMillis(SLEEP_TIMEOUT_MS);
    TEST_ASSERT_EQUAL(static_cast<int>(DeviceState::BLEConnected),
                      static_cast<int>(pm->getRecommendedState()));
    pm->notifyDisconnected();
    gpio.advanceMillis(1000);
    TEST_ASSERT_EQUAL(static_cast<int>(DeviceState::BLEConnected),
                      static_cast<int>(pm->getRecommendedState()));
}

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    UNITY_BEGIN();
    RUN_TEST(test_begin_initializes_accelerometer);
    RUN_TEST(test_motion_detected_when_magnitude_above_threshold);
    RUN_TEST(test_motion_not_detected_at_or_below_threshold);
    RUN_TEST(test_recommended_ranging_rate_active_when_motion);
    RUN_TEST(test_recommended_ranging_rate_idle_after_motion_timeout);
    RUN_TEST(test_recommended_ranging_rate_stays_active_if_motion_resumes_before_timeout);
    RUN_TEST(test_battery_percent_at_max_voltage);
    RUN_TEST(test_battery_percent_at_min_voltage);
    RUN_TEST(test_battery_percent_at_mid_voltage);
    RUN_TEST(test_battery_percent_clamps_to_range);
    RUN_TEST(test_should_report_battery_every_30s);
    RUN_TEST(test_recommended_state_advertising_after_begin);
    RUN_TEST(test_recommended_state_sleep_after_advertising_timeout);
    RUN_TEST(test_recommended_state_advertising_after_long_disconnect_from_ble);
    RUN_TEST(test_notify_connection_updates_tracking);
    return UNITY_END();
}
