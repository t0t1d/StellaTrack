#include <unity.h>
#include "bonding_manager.h"
#include "config.h"
#include <cstring>

static BondingManager g_mgr;

void setUp(void) {
    g_mgr.begin();
}

void tearDown(void) {}

static void addr(uint8_t* out, uint8_t a0, uint8_t a1, uint8_t a2,
                 uint8_t a3, uint8_t a4, uint8_t a5) {
    out[0] = a0;
    out[1] = a1;
    out[2] = a2;
    out[3] = a3;
    out[4] = a4;
    out[5] = a5;
}

void test_begin_initializes_zero_bonds(void) {
    BondingManager m;
    m.begin();
    TEST_ASSERT_EQUAL(0, m.getBondCount());
}

void test_add_bond_stores_address(void) {
    uint8_t a[6];
    addr(a, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66);
    TEST_ASSERT_TRUE(g_mgr.addBond(a));
    TEST_ASSERT_EQUAL(1, g_mgr.getBondCount());
    TEST_ASSERT_TRUE(g_mgr.isBonded(a));
}

void test_add_bond_up_to_max_succeeds(void) {
    uint8_t b0[6], b1[6], b2[6], b3[6];
    addr(b0, 1, 0, 0, 0, 0, 0);
    addr(b1, 2, 0, 0, 0, 0, 0);
    addr(b2, 3, 0, 0, 0, 0, 0);
    addr(b3, 4, 0, 0, 0, 0, 0);
    TEST_ASSERT_TRUE(g_mgr.addBond(b0));
    TEST_ASSERT_TRUE(g_mgr.addBond(b1));
    TEST_ASSERT_TRUE(g_mgr.addBond(b2));
    TEST_ASSERT_TRUE(g_mgr.addBond(b3));
    TEST_ASSERT_EQUAL(MAX_BONDS, g_mgr.getBondCount());
    TEST_ASSERT_TRUE(g_mgr.isBonded(b0));
    TEST_ASSERT_TRUE(g_mgr.isBonded(b1));
    TEST_ASSERT_TRUE(g_mgr.isBonded(b2));
    TEST_ASSERT_TRUE(g_mgr.isBonded(b3));
}

void test_add_bond_when_full_evicts_oldest_fifo(void) {
    uint8_t oldest[6], mid2[6], mid3[6], newest_before[6], newest[6];
    addr(oldest, 0x10, 0, 0, 0, 0, 0);
    addr(mid2, 0x20, 0, 0, 0, 0, 0);
    addr(mid3, 0x30, 0, 0, 0, 0, 0);
    addr(newest_before, 0x40, 0, 0, 0, 0, 0);
    addr(newest, 0x50, 0, 0, 0, 0, 0);
    TEST_ASSERT_TRUE(g_mgr.addBond(oldest));
    TEST_ASSERT_TRUE(g_mgr.addBond(mid2));
    TEST_ASSERT_TRUE(g_mgr.addBond(mid3));
    TEST_ASSERT_TRUE(g_mgr.addBond(newest_before));
    TEST_ASSERT_EQUAL(MAX_BONDS, g_mgr.getBondCount());
    TEST_ASSERT_TRUE(g_mgr.addBond(newest));
    TEST_ASSERT_EQUAL(MAX_BONDS, g_mgr.getBondCount());
    TEST_ASSERT_FALSE(g_mgr.isBonded(oldest));
    TEST_ASSERT_TRUE(g_mgr.isBonded(mid2));
    TEST_ASSERT_TRUE(g_mgr.isBonded(mid3));
    TEST_ASSERT_TRUE(g_mgr.isBonded(newest_before));
    TEST_ASSERT_TRUE(g_mgr.isBonded(newest));
}

void test_is_bonded_true_for_stored(void) {
    uint8_t a[6];
    addr(a, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF);
    g_mgr.addBond(a);
    TEST_ASSERT_TRUE(g_mgr.isBonded(a));
}

void test_is_bonded_false_for_unknown(void) {
    uint8_t stored[6], unknown[6];
    addr(stored, 1, 2, 3, 4, 5, 6);
    addr(unknown, 9, 9, 9, 9, 9, 9);
    g_mgr.addBond(stored);
    TEST_ASSERT_FALSE(g_mgr.isBonded(unknown));
}

void test_remove_bond_removes_specific(void) {
    uint8_t a[6], b[6];
    addr(a, 1, 0, 0, 0, 0, 0);
    addr(b, 2, 0, 0, 0, 0, 0);
    g_mgr.addBond(a);
    g_mgr.addBond(b);
    TEST_ASSERT_TRUE(g_mgr.removeBond(a));
    TEST_ASSERT_EQUAL(1, g_mgr.getBondCount());
    TEST_ASSERT_FALSE(g_mgr.isBonded(a));
    TEST_ASSERT_TRUE(g_mgr.isBonded(b));
}

void test_remove_bond_unknown_returns_false(void) {
    uint8_t a[6], unknown[6];
    addr(a, 1, 0, 0, 0, 0, 0);
    addr(unknown, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF);
    g_mgr.addBond(a);
    TEST_ASSERT_FALSE(g_mgr.removeBond(unknown));
    TEST_ASSERT_EQUAL(1, g_mgr.getBondCount());
}

void test_get_bond_count_tracks_correctly(void) {
    uint8_t a[6], b[6];
    addr(a, 1, 0, 0, 0, 0, 0);
    addr(b, 2, 0, 0, 0, 0, 0);
    TEST_ASSERT_EQUAL(0, g_mgr.getBondCount());
    g_mgr.addBond(a);
    TEST_ASSERT_EQUAL(1, g_mgr.getBondCount());
    g_mgr.addBond(b);
    TEST_ASSERT_EQUAL(2, g_mgr.getBondCount());
    g_mgr.removeBond(a);
    TEST_ASSERT_EQUAL(1, g_mgr.getBondCount());
}

void test_clear_all_bonds(void) {
    uint8_t a[6], b[6];
    addr(a, 1, 0, 0, 0, 0, 0);
    addr(b, 2, 0, 0, 0, 0, 0);
    g_mgr.addBond(a);
    g_mgr.addBond(b);
    g_mgr.clearAllBonds();
    TEST_ASSERT_EQUAL(0, g_mgr.getBondCount());
    TEST_ASSERT_FALSE(g_mgr.isBonded(a));
    TEST_ASSERT_FALSE(g_mgr.isBonded(b));
}

void test_pairing_mode_state(void) {
    TEST_ASSERT_FALSE(g_mgr.isPairingMode());
    g_mgr.enterPairingMode();
    TEST_ASSERT_TRUE(g_mgr.isPairingMode());
    g_mgr.exitPairingMode();
    TEST_ASSERT_FALSE(g_mgr.isPairingMode());
}

void test_confirm_pairing_exits_pairing_and_stores_pending(void) {
    uint8_t pending[6];
    addr(pending, 0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x01);
    g_mgr.enterPairingMode();
    TEST_ASSERT_TRUE(g_mgr.isPairingMode());
    g_mgr.setPendingPairAddress(pending);
    TEST_ASSERT_TRUE(g_mgr.confirmPairing());
    TEST_ASSERT_FALSE(g_mgr.isPairingMode());
    TEST_ASSERT_TRUE(g_mgr.isBonded(pending));
    TEST_ASSERT_EQUAL(1, g_mgr.getBondCount());
}

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    UNITY_BEGIN();
    RUN_TEST(test_begin_initializes_zero_bonds);
    RUN_TEST(test_add_bond_stores_address);
    RUN_TEST(test_add_bond_up_to_max_succeeds);
    RUN_TEST(test_add_bond_when_full_evicts_oldest_fifo);
    RUN_TEST(test_is_bonded_true_for_stored);
    RUN_TEST(test_is_bonded_false_for_unknown);
    RUN_TEST(test_remove_bond_removes_specific);
    RUN_TEST(test_remove_bond_unknown_returns_false);
    RUN_TEST(test_get_bond_count_tracks_correctly);
    RUN_TEST(test_clear_all_bonds);
    RUN_TEST(test_pairing_mode_state);
    RUN_TEST(test_confirm_pairing_exits_pairing_and_stores_pending);
    return UNITY_END();
}
