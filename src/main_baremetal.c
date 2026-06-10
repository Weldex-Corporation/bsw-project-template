/**
 * Bare-metal integration style — main loop polls a 1 ms tick counter
 * and runs the SWCs in fixed order each tick.
 *
 * Layering view (template style #1 of 3):
 *
 *   App SWCs       Swc_ModeSelector, Swc_LedBlink   (same source as #2, #3)
 *   RTE backend    rte/static/ (shared static var + direct Dio)
 *   Scheduler      this file's super-loop
 *   MCAL           Mcu, Dio, Gpt (bsw-mcal-msp)
 *
 * Tick source: Gpt channel 0 (TIMG14 on C1104 / TIMG7 on G3507)
 * configured as 1 ms periodic timer via notification callback.
 */
#include "Mcu.h"
#include "Dio.h"
#include "Gpt.h"
#include "Swc_ModeSelector.h"
#include "Swc_LedBlink.h"

/* 1 ms tick counter — incremented by Gpt notification ISR */
static volatile uint32 s_tick_ms = 0u;

static void Gpt_TickNotification(void)
{
    s_tick_ms++;
}

static const Gpt_ChannelConfigType gpt_channels[] = {
    { .mode = GPT_CH_MODE_CONTINUOUS, .notification = Gpt_TickNotification },
};
static const Gpt_ConfigType gpt_config = {
    .channels    = gpt_channels,
    .numChannels = 1u,
};

int main(void)
{
    Mcu_Init();
    Dio_Init(NULL_PTR);
    Gpt_Init(&gpt_config);
    Gpt_EnableNotification(0);
    Gpt_StartTimer(0, 1000u);  /* 1000 ticks @ 1 MHz = 1 ms periodic */

    SwcModeSelector_Init();
    SwcLedBlink_Init();

    uint32 last_tick = 0u;

    for (;;)
    {
        uint32 now = s_tick_ms;
        uint32 dt  = now - last_tick;
        if (dt > 0u)
        {
            SwcModeSelector_Run(dt);
            SwcLedBlink_Run(dt);
            last_tick = now;
        }
    }

    return 0;
}
