#ifndef STELLA_BONDING_MANAGER_H
#define STELLA_BONDING_MANAGER_H

#include "config.h"
#include <stdint.h>

class BondingManager {
public:
    void begin();

    bool addBond(const uint8_t address[6]);
    bool isBonded(const uint8_t address[6]) const;
    bool removeBond(const uint8_t address[6]);
    uint8_t getBondCount() const;

    void clearAllBonds();

    bool isPairingMode() const;
    void enterPairingMode();
    void exitPairingMode();

    void setPendingPairAddress(const uint8_t address[6]);
    bool confirmPairing();

private:
    uint8_t bonds_[MAX_BONDS][6];
    uint8_t count_;
    bool pairing_mode_;
    bool pending_valid_;
    uint8_t pending_[6];
};

#endif
