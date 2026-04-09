#ifndef STELLA_ACCEL_HAL_H
#define STELLA_ACCEL_HAL_H

class IAccelHal {
public:
    virtual ~IAccelHal() = default;

    virtual bool begin() = 0;
    virtual float readMagnitude() = 0;
};

#endif
