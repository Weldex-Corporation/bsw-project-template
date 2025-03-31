/**
 * BSW Project Template — LED Blink (Hello World)
 * Target: LP-MSPM0G3507 (MSPM0G series, Cortex-M0+)
 */

#include "Dio.h"
#include "Mcu.h"
#include "Os.h"
#include "led_blink.h"

#define LED_GREEN_CHANNEL   DioConf_DioChannel_LED_GREEN

int main(void)
{
    Mcu_Init(NULL_PTR);
    Dio_Init(NULL_PTR);
    Os_Init();
    LedBlink_Init();

    for (;;)
    {
        LedBlink_Tick(10u);  /* 10 ms tick */
        Dio_WriteChannel(LED_GREEN_CHANNEL,
                         (Dio_LevelType)LedBlink_GetState());
        Os_DelayMs(10u);
    }

    return 0;
}
