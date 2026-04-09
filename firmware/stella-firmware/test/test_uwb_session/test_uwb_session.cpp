#include <unity.h>
#include <memory>
#include <vector>
#include "config.h"
#include "uwb_session.h"
#include "mock_uwb.h"
#include "mock_gpio.h"

static MockUwb uwb;
static MockGpio gpio;
static std::unique_ptr<UwbSession> session;

void setUp(void) {
    uwb = MockUwb();
    gpio = MockGpio();
    session.reset(new UwbSession(&uwb, &gpio));
}

void tearDown(void) {
    session.reset();
}

void test_begin_initializes_uwb_module(void) {
    TEST_ASSERT_FALSE(uwb.initialized);
    TEST_ASSERT_TRUE(session->begin());
    TEST_ASSERT_TRUE(uwb.initialized);
}

void test_generate_config_produces_non_empty_blob_up_to_max(void) {
    uwb.fake_accessory_config = {0x01, 0x02, 0x03, 0xAA};
    session->begin();

    uint8_t buf[UWB_CONFIG_MAX_SIZE];
    size_t len = 0;
    TEST_ASSERT_TRUE(session->generateConfig(buf, sizeof(buf), &len));

    TEST_ASSERT_GREATER_THAN(0, (int)len);
    TEST_ASSERT_LESS_OR_EQUAL(UWB_CONFIG_MAX_SIZE, (int)len);
    TEST_ASSERT_EQUAL_UINT8_ARRAY(uwb.fake_accessory_config.data(), buf,
                                  uwb.fake_accessory_config.size());
}

void test_generate_config_fails_if_uwb_not_initialized(void) {
    uwb.fake_accessory_config = {0x10, 0x20};

    uint8_t buf[UWB_CONFIG_MAX_SIZE];
    size_t len = 0;
    TEST_ASSERT_FALSE(session->generateConfig(buf, sizeof(buf), &len));
}

void test_start_session_starts_twr_at_default_active_rate(void) {
    uwb.fake_accessory_config.assign(8, 0x55);
    session->begin();
    uint8_t accBuf[UWB_CONFIG_MAX_SIZE];
    size_t accLen = 0;
    TEST_ASSERT_TRUE(session->generateConfig(accBuf, sizeof(accBuf), &accLen));

    const uint8_t ios[] = {0xDE, 0xAD, 0xBE, 0xEF};
    TEST_ASSERT_TRUE(session->startSession(ios, sizeof(ios)));

    TEST_ASSERT_TRUE(uwb.ranging);
    TEST_ASSERT_EQUAL_UINT8(UWB_RANGING_RATE_ACTIVE_HZ, uwb.ranging_rate);
    TEST_ASSERT_EQUAL_UINT8_ARRAY(ios, uwb.last_ios_config.data(), sizeof(ios));
}

void test_start_session_fails_without_prior_generate_config(void) {
    session->begin();
    uwb.fake_accessory_config = {0x01};

    const uint8_t ios[] = {0x01, 0x02};
    TEST_ASSERT_FALSE(session->startSession(ios, sizeof(ios)));
}

void test_stop_session_stops_ranging(void) {
    uwb.fake_accessory_config = {0x01};
    session->begin();
    uint8_t accBuf[UWB_CONFIG_MAX_SIZE];
    size_t accLen = 0;
    session->generateConfig(accBuf, sizeof(accBuf), &accLen);

    const uint8_t ios[] = {0x03};
    session->startSession(ios, sizeof(ios));
    TEST_ASSERT_TRUE(uwb.ranging);

    TEST_ASSERT_TRUE(session->stopSession());
    TEST_ASSERT_FALSE(uwb.ranging);
}

void test_is_active_reflects_ranging_state(void) {
    uwb.fake_accessory_config = {0x01};
    session->begin();
    uint8_t accBuf[UWB_CONFIG_MAX_SIZE];
    size_t accLen = 0;
    session->generateConfig(accBuf, sizeof(accBuf), &accLen);

    TEST_ASSERT_FALSE(session->isActive());

    session->startSession(accBuf, accLen);
    TEST_ASSERT_TRUE(session->isActive());

    session->stopSession();
    TEST_ASSERT_FALSE(session->isActive());
}

void test_set_ranging_rate_changes_rate_while_active(void) {
    uwb.fake_accessory_config = {0x01};
    session->begin();
    uint8_t accBuf[UWB_CONFIG_MAX_SIZE];
    size_t accLen = 0;
    session->generateConfig(accBuf, sizeof(accBuf), &accLen);
    session->startSession(accBuf, accLen);

    TEST_ASSERT_TRUE(session->setRangingRate(7));
    TEST_ASSERT_EQUAL_UINT8(7, uwb.ranging_rate);
}

void test_set_ranging_rate_fails_if_not_ranging(void) {
    session->begin();
    TEST_ASSERT_FALSE(session->setRangingRate(5));
}

void test_state_transitions_idle_config_generated_ranging_idle(void) {
    TEST_ASSERT_EQUAL(UwbSessionState::Idle, session->getState());

    uwb.fake_accessory_config = {0xAB, 0xCD};
    session->begin();
    uint8_t accBuf[UWB_CONFIG_MAX_SIZE];
    size_t accLen = 0;
    session->generateConfig(accBuf, sizeof(accBuf), &accLen);
    TEST_ASSERT_EQUAL(UwbSessionState::ConfigGenerated, session->getState());

    session->startSession(accBuf, accLen);
    TEST_ASSERT_EQUAL(UwbSessionState::Ranging, session->getState());

    session->stopSession();
    TEST_ASSERT_EQUAL(UwbSessionState::Idle, session->getState());
}

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    UNITY_BEGIN();
    RUN_TEST(test_begin_initializes_uwb_module);
    RUN_TEST(test_generate_config_produces_non_empty_blob_up_to_max);
    RUN_TEST(test_generate_config_fails_if_uwb_not_initialized);
    RUN_TEST(test_start_session_starts_twr_at_default_active_rate);
    RUN_TEST(test_start_session_fails_without_prior_generate_config);
    RUN_TEST(test_stop_session_stops_ranging);
    RUN_TEST(test_is_active_reflects_ranging_state);
    RUN_TEST(test_set_ranging_rate_changes_rate_while_active);
    RUN_TEST(test_set_ranging_rate_fails_if_not_ranging);
    RUN_TEST(test_state_transitions_idle_config_generated_ranging_idle);
    return UNITY_END();
}
