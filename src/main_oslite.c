/**
 * BSW Project Template -- LED Blink (Os_Lite scheduler)
 * Target: LP-MSPM0G3507 (MSPM0G series, Cortex-M0+)
 */
#ifdef OS_USE_LITE

#include "Os_Lite.h"
#include "Mcu.h"
#include "Dio.h"
#include "app_tasks.h"

#define BLINK_PERIOD_MS  500u

static void Task_LedBlink(void)
{
    App_Task_LedBlink(BLINK_PERIOD_MS);
}

static const Os_TaskCfgType os_tasks[] = {
    { Task_LedBlink, BLINK_PERIOD_MS },
};

int main(void)
{
    Mcu_Init();
    Dio_Init(NULL_PTR);
    App_Tasks_Init();
    Os_Init(os_tasks, 1u);
    Os_Start();
    return 0;
}

#endif /* OS_USE_LITE */
