#include "led_blink.h"

#define BLINK_PERIOD_MS_DEFAULT 500u

static LedBlink_State_t s_state;
static uint32_t         s_elapsed_ms;
static uint32_t         s_period_ms;

void LedBlink_Init(void)
{
    s_state      = LED_BLINK_STATE_OFF;
    s_elapsed_ms = 0u;
    s_period_ms  = BLINK_PERIOD_MS_DEFAULT;
}

void LedBlink_SetPeriod(uint32_t period_ms)
{
    if (s_period_ms != period_ms)
    {
        s_period_ms  = period_ms;
        s_elapsed_ms = 0u;
        s_state      = LED_BLINK_STATE_OFF;
    }
}

void LedBlink_Tick(uint32_t elapsed_ms)
{
    s_elapsed_ms += elapsed_ms;
    if (s_elapsed_ms >= s_period_ms)
    {
        s_elapsed_ms -= s_period_ms;
        s_state = (s_state == LED_BLINK_STATE_OFF)
                  ? LED_BLINK_STATE_ON
                  : LED_BLINK_STATE_OFF;
    }
}

LedBlink_State_t LedBlink_GetState(void)
{
    return s_state;
}
