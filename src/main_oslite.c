/**
 * Os_Lite integration style — cooperative scheduler with a per-task period.
 *
 * Layering view (template style #2 of 3):
 *
 *   App SWCs       Swc_ModeSelector, Swc_LedBlink   (same source as #1, #3)
 *   RTE backend    rte/static/ (shared static var + direct Dio)
 *   Scheduler      Os_Lite (bsw-mcal-msp/src/Os_Lite.c)
 *   MCAL           Mcu, Dio (bsw-mcal-msp)
 *
 * Tick periods:
 *   ModeSelector — 20 ms (matches the debounce window)
 *   LedBlink     — 20 ms (fastest blink mode is 100 ms → 5x oversample)
 */
#include "Os_Lite.h"
#include "Mcu.h"
#include "Dio.h"
#include "Swc_ModeSelector.h"
#include "Swc_LedBlink.h"

#define MODE_TASK_PERIOD_MS   20u
#define BLINK_TASK_PERIOD_MS  20u

static void Task_Mode(void)  { SwcModeSelector_Run(MODE_TASK_PERIOD_MS); }
static void Task_Blink(void) { SwcLedBlink_Run(BLINK_TASK_PERIOD_MS);    }

static const Os_TaskCfgType os_tasks[] = {
    { Task_Mode,  MODE_TASK_PERIOD_MS  },
    { Task_Blink, BLINK_TASK_PERIOD_MS },
};

int main(void)
{
    Mcu_Init();
    Dio_Init(NULL_PTR);

    SwcModeSelector_Init();
    SwcLedBlink_Init();

    Os_Init(os_tasks, (uint8)(sizeof(os_tasks) / sizeof(os_tasks[0])));
    Os_Start();
    return 0;
}
