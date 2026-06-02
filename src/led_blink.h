#ifndef LED_BLINK_H
#define LED_BLINK_H

#include <stdint.h>

typedef enum {
    LED_BLINK_STATE_OFF = 0,
    LED_BLINK_STATE_ON  = 1
} LedBlink_State_t;

void             LedBlink_Init(void);
void             LedBlink_SetPeriod(uint32_t period_ms);
void             LedBlink_Tick(uint32_t elapsed_ms);
LedBlink_State_t LedBlink_GetState(void);

#endif /* LED_BLINK_H */
