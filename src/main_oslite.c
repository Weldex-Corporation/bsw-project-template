/**
 * BSW Project Template -- LED Blink (Os_Lite scheduler)
 * Target: LP-MSPM0G3507 (MSPM0G series, Cortex-M0+)
 *
 * Os_Lite handles the 500 ms period; the task body just toggles the LED.
 * Compare with main_baremetal.c which manages timing manually in a super-loop.
 */
#ifdef OS_USE_LITE

#include "Os_Lite.h"
#include "Dio.h"
#include "Mcu.h"

#define LED_GREEN_CHANNEL  ((Dio_ChannelType)0u)
#define BLINK_PERIOD_MS    500u

static Dio_LevelType s_level = STD_LOW;

static void Task_LedBlink(void)
{
    s_level = (s_level == STD_LOW) ? STD_HIGH : STD_LOW;
    Dio_WriteChannel(LED_GREEN_CHANNEL, (Dio_LevelType)s_level);
}

static const Os_TaskCfgType os_tasks[] = {
    { Task_LedBlink, BLINK_PERIOD_MS },
};

int main(void)
{
    Mcu_Init();
    Dio_Init(NULL_PTR);
    Os_Init(os_tasks, 1u);
    Os_Start();   /* never returns */
    return 0;
}

#endif /* OS_USE_LITE */
