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
#include "Swc_ModeSelector.h"
#include "Swc_LedBlink.h"

int main(void)
{
    Mcu_Init();
    Dio_Init(NULL_PTR);

    SwcModeSelector_Init();
    SwcLedBlink_Init();

    uint32 last_tick = Mcu_GetTickMs();

    for (;;)
    {
        uint32 now = Mcu_GetTickMs();
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
