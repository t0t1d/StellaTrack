#ifdef STELLA_TARGET

#include "firmware_controller.h"
#include "hal/arduino_gpio_hal.h"
#include "hal/arduino_ble_hal.h"
#include "hal/stella_uwb_hal.h"
#include "hal/sc7a20_accel_hal.h"

static ArduinoGpioHal s_gpio;
static ArduinoBleHal s_ble;
static StellaUwbHal s_uwb;
static Sc7a20AccelHal s_accel;
static FirmwareController fw(&s_gpio, &s_ble, &s_uwb, &s_accel);

void setup() {
    ArduinoBleHal::instance_ = &s_ble;
    fw.begin();
}

void loop() {
    fw.update();
}

#endif // STELLA_TARGET
