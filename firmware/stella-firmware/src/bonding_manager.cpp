#include "bonding_manager.h"
#include <cstring>

void BondingManager::begin() {
    count_ = 0;
    pairing_mode_ = false;
    pending_valid_ = false;
}

bool BondingManager::addBond(const uint8_t address[6]) {
    if (isBonded(address)) {
        return true;
    }
    if (count_ < MAX_BONDS) {
        std::memcpy(bonds_[count_], address, 6);
        ++count_;
        return true;
    }
    std::memmove(bonds_[0], bonds_[1], static_cast<size_t>(MAX_BONDS - 1) * 6);
    std::memcpy(bonds_[MAX_BONDS - 1], address, 6);
    return true;
}

bool BondingManager::isBonded(const uint8_t address[6]) const {
    for (uint8_t i = 0; i < count_; ++i) {
        if (std::memcmp(bonds_[i], address, 6) == 0) {
            return true;
        }
    }
    return false;
}

bool BondingManager::removeBond(const uint8_t address[6]) {
    for (uint8_t i = 0; i < count_; ++i) {
        if (std::memcmp(bonds_[i], address, 6) == 0) {
            if (i + 1 < count_) {
                std::memmove(bonds_[i], bonds_[i + 1],
                             static_cast<size_t>(count_ - i - 1) * 6);
            }
            --count_;
            return true;
        }
    }
    return false;
}

uint8_t BondingManager::getBondCount() const {
    return count_;
}

void BondingManager::clearAllBonds() {
    count_ = 0;
}

bool BondingManager::isPairingMode() const {
    return pairing_mode_;
}

void BondingManager::enterPairingMode() {
    pairing_mode_ = true;
}

void BondingManager::exitPairingMode() {
    pairing_mode_ = false;
    pending_valid_ = false;
}

void BondingManager::setPendingPairAddress(const uint8_t address[6]) {
    std::memcpy(pending_, address, 6);
    pending_valid_ = true;
}

bool BondingManager::confirmPairing() {
    if (!pairing_mode_ || !pending_valid_) {
        return false;
    }
    addBond(pending_);
    pairing_mode_ = false;
    pending_valid_ = false;
    return true;
}
