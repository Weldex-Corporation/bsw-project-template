#include "app_tasks.h"
#include "app_mode.h"
#include "led_blink.h"
#include "Dio.h"
#include "Std_Types.h"

#define LED_GREEN_CHANNEL  ((Dio_ChannelType)0u)

void App_Tasks_Init(void)
{
    AppMode_Init();
    LedBlink_Init();
}

void App_Task_LedBlink(uint32 dt_ms)
{
    AppMode_Tick(dt_ms);

    switch (AppMode_Get())
    {
        case APP_MODE_BLINK_100MS:
            LedBlink_SetPeriod(100u);
            LedBlink_Tick(dt_ms);
            Dio_WriteChannel(LED_GREEN_CHANNEL, (Dio_LevelType)LedBlink_GetState());
            break;

        case APP_MODE_BLINK_500MS:
            LedBlink_SetPeriod(500u);
            LedBlink_Tick(dt_ms);
            Dio_WriteChannel(LED_GREEN_CHANNEL, (Dio_LevelType)LedBlink_GetState());
            break;

        case APP_MODE_OFF:
        default:
            Dio_WriteChannel(LED_GREEN_CHANNEL, STD_LOW);
            break;
    }
}
