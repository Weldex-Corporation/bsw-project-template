/**
 * BSW Project Template -- LED Blink (bare-metal super-loop)
 * Target: LP-MSPM0G3507 (MSPM0G series, Cortex-M0+)
 */

#include "Mcu.h"
#include "Dio.h"
#include "app_tasks.h"

int main(void)
{
    Mcu_Init();
    Dio_Init(NULL_PTR);
    App_Tasks_Init();

    uint32 last_tick = Mcu_GetTickMs();

    for (;;)
    {
        uint32 now = Mcu_GetTickMs();
        uint32 dt  = now - last_tick;
        if (dt > 0u)
        {
            App_Task_LedBlink(dt);
            last_tick = now;
        }
    }

    return 0;
}
