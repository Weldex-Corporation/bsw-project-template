#include "app_tasks.h"
#include "led_blink.h"
#include "Dio.h"

#define LED_GREEN_CHANNEL  ((Dio_ChannelType)0u)

void App_Tasks_Init(void)
{
    LedBlink_Init();
}

void App_Task_LedBlink(uint32 dt_ms)
{
    LedBlink_Tick(dt_ms);
    Dio_WriteChannel(LED_GREEN_CHANNEL, (Dio_LevelType)LedBlink_GetState());
}
