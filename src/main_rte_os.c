/**
 * AUTOSAR (RTE + Os) integration style — full BSW stack.
 *
 * Layering view (template style #3 of 3):
 *
 *   App SWCs       Swc_ModeSelector, Swc_LedBlink   (same source as #1, #2)
 *   RTE            BSW Rte.c (port-based, thread-safe)
 *   System         BSW EcuM, AUTOSAR-compatible Os (Task + Alarm)
 *   MCAL           Port, Dio, Mcu (bsw-mcal-msp)
 *
 * Tick periods (matched to styles #1/#2 for behaviour parity):
 *   ModeTask  — 20 ms via Os Alarm
 *   BlinkTask — 20 ms via Os Alarm
 *
 * Note: the SWCs are bit-identical to the other two styles. Only the
 *       Rte_*.h backend (selected by include path) and the scheduling
 *       layer here differ.
 */
#include "EcuM.h"
#include "Port.h"
#include "Dio.h"
#include "Mcu.h"
#include "Rte.h"
#include "autosar/Os.h"
#include "Port_Cfg.h"
#include "Dio_Cfg.h"
#include "Swc_ModeSelector.h"
#include "Swc_LedBlink.h"
#include "Rte_Ports.h"

#define MODE_TASK_PERIOD_MS   20u
#define BLINK_TASK_PERIOD_MS  20u

/* ── Os tasks ────────────────────────────────────────────────────── */

static void Task_Mode(void)
{
    SwcModeSelector_Run(MODE_TASK_PERIOD_MS);
    (void)Os_TerminateTask();
}

static void Task_Blink(void)
{
    SwcLedBlink_Run(BLINK_TASK_PERIOD_MS);
    (void)Os_TerminateTask();
}

#define OS_TASK_MODE_ID   ((Os_TaskIdType)0u)
#define OS_TASK_BLINK_ID  ((Os_TaskIdType)1u)

static const Os_TaskConfigType os_tasks[] = {
    { .name = "Mode",  .func = Task_Mode,  .priority = 1u, .autostart = FALSE, .maxActivations = 1u },
    { .name = "Blink", .func = Task_Blink, .priority = 1u, .autostart = FALSE, .maxActivations = 1u },
};

static const Os_AlarmConfigType os_alarms[] = {
    {
        .name            = "ModeAlarm",
        .counter         = OS_COUNTER_SYSTEM,
        .action          = OS_ALARM_ACTION_ACTIVATETASK,
        .taskId          = OS_TASK_MODE_ID,
        .eventMask       = 0u,
        .callback        = NULL_PTR,
        .autostart_ticks = MODE_TASK_PERIOD_MS,
        .autostart_cycle = MODE_TASK_PERIOD_MS,
    },
    {
        .name            = "BlinkAlarm",
        .counter         = OS_COUNTER_SYSTEM,
        .action          = OS_ALARM_ACTION_ACTIVATETASK,
        .taskId          = OS_TASK_BLINK_ID,
        .eventMask       = 0u,
        .callback        = NULL_PTR,
        .autostart_ticks = BLINK_TASK_PERIOD_MS,
        .autostart_cycle = BLINK_TASK_PERIOD_MS,
    },
};

static const Os_ConfigType os_cfg = {
    .tasks     = os_tasks,
    .numTasks  = (uint8)(sizeof(os_tasks) / sizeof(os_tasks[0])),
    .alarms    = os_alarms,
    .numAlarms = (uint8)(sizeof(os_alarms) / sizeof(os_alarms[0])),
};

/* ── RTE runnables ───────────────────────────────────────────────── */

static void RtSwc_ModeSelector_Init(void)  { SwcModeSelector_Init(); }
static void RtSwc_LedBlink_Init(void)      { SwcLedBlink_Init();     }

static const Rte_RunnableConfigType rte_runnables[] = {
    { .name = "ModeSelector_Init",
      .func = RtSwc_ModeSelector_Init,
      .trigger = RTE_TRIGGER_INIT,
      .period_ms = 0u, .swc_id = 1u },
    { .name = "LedBlink_Init",
      .func = RtSwc_LedBlink_Init,
      .trigger = RTE_TRIGGER_INIT,
      .period_ms = 0u, .swc_id = 2u },
};

/* ── Entry point ─────────────────────────────────────────────────── */

int main(void)
{
    EcuM_Init();
    Port_Init(&Port_Config);
    Dio_Init(&Dio_Config);

    (void)Rte_Init(rte_runnables,
                   (uint16)(sizeof(rte_runnables) / sizeof(rte_runnables[0])));
    (void)Rte_Start();

    Os_Init(&os_cfg);
    Os_StartOS(OS_APPMODE_DEFAULT);

    /* Os_StartOS does not return. */
    for (;;) { }
    return 0;
}
