/**
 * BSW Project Template — LED Blink (Hello World)
 * Target: LP-MSPM0G3507 (MSPM0G series, Cortex-M0+)
 */

#include "Dio.h"
#include "Mcu.h"
#include "led_blink.h"

/* Dio channel used for the LED. Replace with a generated Dio config symbol
 * (e.g. DioConf_DioChannel_LED_GREEN) once a Dio configuration is added. */
#define LED_GREEN_CHANNEL   ((Dio_ChannelType)0u)

int main(void)
{
    Mcu_Init();
    Dio_Init(NULL_PTR);
    LedBlink_Init();

    /* Tick-driven main loop: derive elapsed_ms from Mcu_GetTickMs() so the
     * firmware advances in step with the real (or simulated) clock. On the
     * real silicon Mcu_GetTickMs() reads the SysTick counter; on Renode it
     * reads the TIM0 VTIME_MS register, which is bound to virtual time. */
    uint32 last_tick = Mcu_GetTickMs();

    for (;;)
    {
        uint32 now = Mcu_GetTickMs();
        uint32 dt  = now - last_tick;
        if (dt > 0u)
        {
            LedBlink_Tick(dt);
            Dio_WriteChannel(LED_GREEN_CHANNEL,
                             (Dio_LevelType)LedBlink_GetState());
            last_tick = now;
        }
        /* idle until the next tick */
    }

    return 0;
}
