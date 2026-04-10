#include <unity.h>
#include <cstring>
#include <string>
#include "config.h"
#include "hal/ble_hal.h"
#include "mock_ble.h"
#include "ble_service.h"

static MockBle mock;
static BleService svc(&mock);

static bool s_cmd_fired;
static uint8_t s_cmd_payload[64];
static size_t s_cmd_len;
static void* s_cmd_ctx_expected;

static bool s_uwb_in_fired;
static uint8_t s_uwb_payload[UWB_CONFIG_MAX_SIZE];
static size_t s_uwb_len;
static void* s_uwb_ctx_expected;

static bool s_connect_fired;
static void* s_connect_ctx_expected;
static bool s_disconnect_fired;
static void* s_disconnect_ctx_expected;

static void on_cmd_cb(const uint8_t* data, size_t len, void* ctx) {
    s_cmd_fired = true;
    s_cmd_len = len;
    TEST_ASSERT_EQUAL_PTR(s_cmd_ctx_expected, ctx);
    TEST_ASSERT_TRUE(len <= sizeof(s_cmd_payload));
    std::memcpy(s_cmd_payload, data, len);
}

static void on_uwb_in_cb(const uint8_t* data, size_t len, void* ctx) {
    s_uwb_in_fired = true;
    s_uwb_len = len;
    TEST_ASSERT_EQUAL_PTR(s_uwb_ctx_expected, ctx);
    TEST_ASSERT_TRUE(len <= sizeof(s_uwb_payload));
    std::memcpy(s_uwb_payload, data, len);
}

static void on_connect_cb(void* ctx) {
    s_connect_fired = true;
    TEST_ASSERT_EQUAL_PTR(s_connect_ctx_expected, ctx);
}

static void on_disconnect_cb(void* ctx) {
    s_disconnect_fired = true;
    TEST_ASSERT_EQUAL_PTR(s_disconnect_ctx_expected, ctx);
}

void setUp(void) {
    mock = MockBle();
    svc = BleService(&mock);
    s_cmd_fired = false;
    s_cmd_len = 0;
    s_uwb_in_fired = false;
    s_uwb_len = 0;
    s_connect_fired = false;
    s_disconnect_fired = false;
}

void tearDown(void) {}

void test_begin_initializes_ble_with_device_name_and_service(void) {
    TEST_ASSERT_TRUE(svc.begin());
    TEST_ASSERT_TRUE(mock.initialized);
    TEST_ASSERT_EQUAL_STRING(BLE_DEVICE_NAME, mock.device_name.c_str());
    TEST_ASSERT_EQUAL_STRING(SERVICE_UUID, mock.service_uuid.c_str());
}

void test_begin_creates_uwb_config_out_read_notify(void) {
    svc.begin();
    auto it = mock.characteristics.find(CHAR_UWB_CONFIG_OUT_UUID);
    TEST_ASSERT_TRUE(it != mock.characteristics.end());
    uint16_t want = BLE_PROP_READ | BLE_PROP_NOTIFY;
    TEST_ASSERT_EQUAL_UINT16(want, it->second.properties);
    TEST_ASSERT_EQUAL_UINT32(UWB_CONFIG_MAX_SIZE, it->second.maxLen);
}

void test_begin_creates_uwb_config_in_write(void) {
    svc.begin();
    auto it = mock.characteristics.find(CHAR_UWB_CONFIG_IN_UUID);
    TEST_ASSERT_TRUE(it != mock.characteristics.end());
    TEST_ASSERT_EQUAL_UINT16(BLE_PROP_WRITE, it->second.properties);
    TEST_ASSERT_EQUAL_UINT32(UWB_CONFIG_MAX_SIZE, it->second.maxLen);
}

void test_begin_creates_battery_read_notify(void) {
    svc.begin();
    auto it = mock.characteristics.find(CHAR_BATTERY_UUID);
    TEST_ASSERT_TRUE(it != mock.characteristics.end());
    uint16_t want = BLE_PROP_READ | BLE_PROP_NOTIFY;
    TEST_ASSERT_EQUAL_UINT16(want, it->second.properties);
    TEST_ASSERT_EQUAL_UINT32(1, it->second.maxLen);
}

void test_begin_creates_command_write(void) {
    svc.begin();
    auto it = mock.characteristics.find(CHAR_COMMAND_UUID);
    TEST_ASSERT_TRUE(it != mock.characteristics.end());
    TEST_ASSERT_EQUAL_UINT16(BLE_PROP_WRITE, it->second.properties);
    TEST_ASSERT_EQUAL_UINT32(2, it->second.maxLen);
}

void test_begin_creates_device_info_read(void) {
    svc.begin();
    auto it = mock.characteristics.find(CHAR_DEVICE_INFO_UUID);
    TEST_ASSERT_TRUE(it != mock.characteristics.end());
    TEST_ASSERT_EQUAL_UINT16(BLE_PROP_READ, it->second.properties);
    TEST_ASSERT_EQUAL_UINT32(64, it->second.maxLen);
}

void test_begin_writes_device_info_json(void) {
    svc.begin();
    auto it = mock.characteristics.find(CHAR_DEVICE_INFO_UUID);
    TEST_ASSERT_TRUE(it != mock.characteristics.end());
    TEST_ASSERT_TRUE(it->second.data.size() > 0);
    std::string json(reinterpret_cast<const char*>(it->second.data.data()), it->second.data.size());
    TEST_ASSERT_NOT_NULL(std::strstr(json.c_str(), "\"fw\""));
    TEST_ASSERT_NOT_NULL(std::strstr(json.c_str(), "\"hw\""));
    TEST_ASSERT_NOT_NULL(std::strstr(json.c_str(), FW_VERSION));
    TEST_ASSERT_NOT_NULL(std::strstr(json.c_str(), HW_MODEL));
}

void test_start_advertising_enables(void) {
    svc.begin();
    svc.startAdvertising();
    TEST_ASSERT_TRUE(mock.advertising);
}

void test_stop_advertising_disables(void) {
    svc.begin();
    svc.startAdvertising();
    svc.stopAdvertising();
    TEST_ASSERT_FALSE(mock.advertising);
}

void test_is_connected_reflects_hal(void) {
    svc.begin();
    mock.connected = false;
    TEST_ASSERT_FALSE(svc.isConnected());
    mock.connected = true;
    TEST_ASSERT_TRUE(svc.isConnected());
}

void test_write_uwb_config_writes_out_characteristic(void) {
    svc.begin();
    const uint8_t payload[] = {0x01, 0x02, 0x03};
    TEST_ASSERT_TRUE(svc.writeUwbConfig(payload, sizeof(payload)));
    auto it = mock.characteristics.find(CHAR_UWB_CONFIG_OUT_UUID);
    TEST_ASSERT_TRUE(it != mock.characteristics.end());
    TEST_ASSERT_EQUAL_UINT32(sizeof(payload), it->second.data.size());
    TEST_ASSERT_EQUAL_HEX8_ARRAY(payload, it->second.data.data(), sizeof(payload));
}

void test_write_battery_level_writes_battery_characteristic(void) {
    svc.begin();
    TEST_ASSERT_TRUE(svc.writeBatteryLevel(87));
    auto it = mock.characteristics.find(CHAR_BATTERY_UUID);
    TEST_ASSERT_TRUE(it != mock.characteristics.end());
    TEST_ASSERT_EQUAL_UINT32(1, it->second.data.size());
    TEST_ASSERT_EQUAL_UINT8(87, it->second.data[0]);
}

void test_on_command_received_fires_on_write(void) {
    int dummy = 42;
    s_cmd_ctx_expected = &dummy;
    svc.onCommandReceived(on_cmd_cb, &dummy);
    svc.begin();
    const uint8_t w[] = {CMD_PING};
    mock.simulateWrite(CHAR_COMMAND_UUID, w, sizeof(w));
    TEST_ASSERT_TRUE(s_cmd_fired);
    TEST_ASSERT_EQUAL_UINT32(sizeof(w), s_cmd_len);
    TEST_ASSERT_EQUAL_HEX8_ARRAY(w, s_cmd_payload, sizeof(w));
}

void test_on_uwb_config_received_fires_on_write(void) {
    int dummy = 7;
    s_uwb_ctx_expected = &dummy;
    svc.onUwbConfigReceived(on_uwb_in_cb, &dummy);
    svc.begin();
    const uint8_t w[] = {0xAA, 0xBB};
    mock.simulateWrite(CHAR_UWB_CONFIG_IN_UUID, w, sizeof(w));
    TEST_ASSERT_TRUE(s_uwb_in_fired);
    TEST_ASSERT_EQUAL_UINT32(sizeof(w), s_uwb_len);
    TEST_ASSERT_EQUAL_HEX8_ARRAY(w, s_uwb_payload, sizeof(w));
}

void test_on_connect_and_disconnect_callbacks(void) {
    long ctx = 99;
    s_connect_ctx_expected = &ctx;
    s_disconnect_ctx_expected = &ctx;
    svc.onConnect(on_connect_cb, &ctx);
    svc.onDisconnect(on_disconnect_cb, &ctx);
    svc.begin();
    mock.simulateConnect();
    TEST_ASSERT_TRUE(s_connect_fired);
    mock.simulateDisconnect();
    TEST_ASSERT_TRUE(s_disconnect_fired);
}

void test_device_info_json_contains_fw_and_hw(void) {
    svc.begin();
    auto it = mock.characteristics.find(CHAR_DEVICE_INFO_UUID);
    std::string json(reinterpret_cast<const char*>(it->second.data.data()), it->second.data.size());
    TEST_ASSERT_NOT_NULL(std::strstr(json.c_str(), "\"fw\""));
    TEST_ASSERT_NOT_NULL(std::strstr(json.c_str(), "\"hw\""));
    TEST_ASSERT_NOT_NULL(std::strstr(json.c_str(), FW_VERSION));
    TEST_ASSERT_NOT_NULL(std::strstr(json.c_str(), HW_MODEL));
}

void test_is_paired_independent_of_connected(void) {
    mock.simulateConnectUnpaired();
    TEST_ASSERT_TRUE(mock.isConnected());
    TEST_ASSERT_FALSE(mock.isPaired());
    mock.paired = true;
    TEST_ASSERT_TRUE(mock.isPaired());
    mock.connected = false;
    TEST_ASSERT_FALSE(mock.isConnected());
    TEST_ASSERT_TRUE(mock.isPaired());
}

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    UNITY_BEGIN();
    RUN_TEST(test_begin_initializes_ble_with_device_name_and_service);
    RUN_TEST(test_begin_creates_uwb_config_out_read_notify);
    RUN_TEST(test_begin_creates_uwb_config_in_write);
    RUN_TEST(test_begin_creates_battery_read_notify);
    RUN_TEST(test_begin_creates_command_write);
    RUN_TEST(test_begin_creates_device_info_read);
    RUN_TEST(test_begin_writes_device_info_json);
    RUN_TEST(test_start_advertising_enables);
    RUN_TEST(test_stop_advertising_disables);
    RUN_TEST(test_is_connected_reflects_hal);
    RUN_TEST(test_write_uwb_config_writes_out_characteristic);
    RUN_TEST(test_write_battery_level_writes_battery_characteristic);
    RUN_TEST(test_on_command_received_fires_on_write);
    RUN_TEST(test_on_uwb_config_received_fires_on_write);
    RUN_TEST(test_on_connect_and_disconnect_callbacks);
    RUN_TEST(test_device_info_json_contains_fw_and_hw);
    RUN_TEST(test_is_paired_independent_of_connected);
    return UNITY_END();
}
