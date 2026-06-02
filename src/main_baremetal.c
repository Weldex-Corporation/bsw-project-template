/**
 * Bare-metal integration style — main loop polls SysTick and runs the
 * SWCs in fixed order each tick.
 *
 * Layering view (template style #1 of 3):
 *
 *   App SWCs       Swc_ModeSelector, Swc_LedBlink   (same source as #2, #3)
 *   RTE backend    rte/static/ (shared static var + direct Dio)
 *   Scheduler      this file's super-loop
 *   MCAL           Mcu, Dio (bsw-mcal-msp)
 *
 * Target: LP-MSPM0G3507 (MSPM0G series, Cortex-M0+).
 */
#include "Mcu.h"
#include "Dio.h"
#include "Gpt.h"             /* Gpt_GetPredefTimerValue (SWS_GPT_00373) */
#include "Swc_ModeSelector.h"
#include "Swc_LedBlink.h"

/* Bare-metal ms tick via the AUTOSAR R20-11 standard Predef Timer
 * (1 µs / 32-bit free-running). Divides to ms for super-loop pacing. */
static inline uint32_t _now_ms(void)
{
    uint32_t us = 0u;
    (void)Gpt_GetPredefTimerValue(GPT_PREDEF_TIMER_1US_32BIT, &us);
    return us / 1000u;
}

int main(void)
{
    Mcu_Init();
    Dio_Init(NULL_PTR);

    SwcModeSelector_Init();
    SwcLedBlink_Init();

    uint32 last_tick = _now_ms();

    for (;;)
    {
        uint32 now = _now_ms();
        uint32 dt  = now - last_tick;
        if (dt > 0u)
        {
            SwcModeSelector_Run(dt);
            SwcLedBlink_Run(dt);
            last_tick = now;
        }
    }

    return 0;
}
