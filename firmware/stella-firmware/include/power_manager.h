#ifndef STELLA_POWER_MANAGER_H
#define STELLA_POWER_MANAGER_H

#include "config.h"
#include "hal/accel_hal.h"
#include "hal/gpio_hal.h"

class PowerManager {
public:
    PowerManager(IAccelHal* accel, IGpioHal* gpio);

    void begin();

    bool isMotionDetected();
    uint8_t getRecommendedRangingRate();
    int readBatteryPercent();
    static int batteryPercentFromMillivolts(int mv);
    bool shouldReportBattery();
    DeviceState getRecommendedState();

    void notifyConnected();
    void notifyDisconnected();

private:
    IAccelHal* accel_;
    IGpioHal* gpio_;

    unsigned long last_motion_ms_ = 0;
    unsigned long advertising_no_conn_start_ms_ = 0;
    unsigned long disconnect_at_ms_ = 0;
    unsigned long last_battery_report_ms_ = 0;

    bool connected_ = false;
};

#endif
