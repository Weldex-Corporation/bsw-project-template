/**
 * Swc_LedBlink.c — LED blink SWC implementation.
 *
 * Behaviour (SWE.1 → SWE.3 trace):
 *   - Reads inter-SWC port Mode.
 *   - Mode == OFF        → drive LedState OFF.
 *   - Mode == BLINK_*ms  → toggle LedState every *ms.
 */
#include "Swc_LedBlink.h"
#include "Rte_LedBlink.h"

static Rte_LedState_t s_led;
static uint32         s_elapsed_ms;
static Rte_AppMode_t  s_last_mode;

static uint32 period_for_mode(Rte_AppMode_t m)
{
    switch (m)
    {
        case RTE_MODE_BLINK_100MS:  return 100u;
        case RTE_MODE_BLINK_500MS:  return 500u;
        default:                    return 0u;
    }
}

void SwcLedBlink_Init(void)
{
    s_led        = RTE_LED_OFF;
    s_elapsed_ms = 0u;
    s_last_mode  = RTE_MODE_OFF;
    (void)Rte_Write_LedState_Value(s_led);
}

void SwcLedBlink_Run(uint32 dt_ms)
{
    Rte_AppMode_t mode = RTE_MODE_OFF;
    (void)Rte_Read_Mode_Value(&mode);

    /* Mode change → reset phase, force OFF for predictable edge */
    if (mode != s_last_mode)
    {
        s_elapsed_ms = 0u;
        s_led        = RTE_LED_OFF;
        s_last_mode  = mode;
    }

    if (mode == RTE_MODE_OFF)
    {
        s_led = RTE_LED_OFF;
    }
    else
    {
        uint32 period = period_for_mode(mode);
        s_elapsed_ms += dt_ms;
        if (s_elapsed_ms >= period)
        {
            s_elapsed_ms -= period;
            s_led = (s_led == RTE_LED_OFF) ? RTE_LED_ON : RTE_LED_OFF;
        }
    }

    (void)Rte_Write_LedState_Value(s_led);
}
