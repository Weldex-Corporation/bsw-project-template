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

#ifndef DELAY_LOOPS_PER_MS
#define DELAY_LOOPS_PER_MS  1000u
#endif

static void busy_delay_ms(uint32_t ms)
{
    volatile uint32_t i;
    for (uint32_t m = 0u; m < ms; ++m) {
        for (i = 0u; i < DELAY_LOOPS_PER_MS; ++i) { /* spin */ }
    }
}

int main(void)
{
    Mcu_Init();
    Dio_Init(NULL_PTR);
    LedBlink_Init();

    for (;;)
    {
        LedBlink_Tick(10u);
        Dio_WriteChannel(LED_GREEN_CHANNEL,
                         (Dio_LevelType)LedBlink_GetState());
        busy_delay_ms(10u);
    }

    return 0;
}
