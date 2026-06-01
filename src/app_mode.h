#ifndef APP_MODE_H
#define APP_MODE_H

#include <stdint.h>

typedef enum {
    APP_MODE_OFF = 0,
    APP_MODE_BLINK_100MS,
    APP_MODE_BLINK_500MS,
    APP_MODE_COUNT
} AppMode_t;

void      AppMode_Init(void);
void      AppMode_Tick(uint32_t dt_ms);
AppMode_t AppMode_Get(void);

#endif /* APP_MODE_H */
