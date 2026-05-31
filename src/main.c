/**
 * BSW Project Template — LED Blink (Hello World)
 * Target: LP-MSPM0G3507 (Cortex-M0+) / Renode SIL
 *
 * Drives a 1Hz blink on PA0 (LED_GREEN) by polling Mcu_GetTickMs() and
 * feeding 10ms deltas into the testable LedBlink state machine. Uses the
 * BSW MCAL HAL layer (Mcu + Dio) so the same code runs on Renode and
 * real silicon without modification.
 */

#include "Std_Types.h"
#include "Mcu.h"
#include "Dio.h"
#include "led_blink.h"

/* PA0 = LED_GREEN. Dio_ChannelType is just uint8 — bit position in the
 * GPIOA DOUT register. No DioConf_* config table is generated for this
 * minimal example. */
#define LED_GREEN_CHANNEL  ((Dio_ChannelType)0u)
#define TICK_PERIOD_MS     10u

/* ── SysTick-backed millisecond time source ──────────────────────────
 * The BSW renode HAL ships `hal_system_get_time()` returning a stale
 * global that's only refreshed inside critical sections — our cooperative
 * main loop never enters one, so time would always read zero. Override
 * Mcu_GetTickMs() with a direct SysTick poll (Cortex-M0+ has no DWT).
 *
 * Reload value = (CPU_HZ / 1000) - 1 → COUNTFLAG asserts once per ms. */
#define SYST_CSR  (*(volatile uint32_t *)0xE000E010u)  /* control */
#define SYST_RVR  (*(volatile uint32_t *)0xE000E014u)  /* reload */
#define SYST_CVR  (*(volatile uint32_t *)0xE000E018u)  /* current */
#define SYSTICK_HZ          32000000u
#define SYSTICK_RELOAD_MS   ((SYSTICK_HZ / 1000u) - 1u)
#define SYST_CSR_ENABLE     (1u << 0)
#define SYST_CSR_CLKSOURCE  (1u << 2)  /* 1 = processor clock */
#define SYST_CSR_COUNTFLAG  (1u << 16) /* set when CVR reached 0; cleared on read */

static volatile uint32_t g_tick_ms = 0u;

static void systick_init(void)
{
    SYST_RVR = SYSTICK_RELOAD_MS;
    SYST_CVR = 0u;                                          /* clear current + flag */
    SYST_CSR = SYST_CSR_CLKSOURCE | SYST_CSR_ENABLE;        /* no IRQ, just count */
}

/* Override BSW's weak Mcu_GetTickMs(). Each call drains COUNTFLAG and
 * advances by the number of ms that elapsed since the previous call.
 * Robust for "polled at least once per period" (true for our main loop). */
uint32 Mcu_GetTickMs(void)
{
    if (SYST_CSR & SYST_CSR_COUNTFLAG) {
        g_tick_ms++;
    }
    return g_tick_ms;
}

/* Diagnostics — exposed at fixed addresses inside the GPIOA region so
 * robot tests can poke memory and inspect runtime state.
 * DBG_LED_BYTE is 0x00 (OFF) or 0xFF (ON), giving robot tests a clean
 * byte to match via `Should Contain` without hex-string parsing. */
#define DBG_MAIN_REACHED  (*(volatile uint32_t *)0x400A00F0u)
#define DBG_TICK_MS       (*(volatile uint32_t *)0x400A00F4u)
#define DBG_LED_BYTE      (*(volatile uint8_t  *)0x400A00F8u)

int main(void)
{
    DBG_MAIN_REACHED = 0xDEADBEEFu;

    Mcu_Init();
    Dio_Init(NULL_PTR);
    LedBlink_Init();
    systick_init();

    uint32 last = Mcu_GetTickMs();
    for (;;) {
        uint32 now   = Mcu_GetTickMs();
        DBG_TICK_MS  = now;
        uint32 delta = now - last;
        if (delta >= TICK_PERIOD_MS) {
            LedBlink_Tick(delta);
            const Dio_LevelType lvl = (Dio_LevelType)LedBlink_GetState();
            Dio_WriteChannel(LED_GREEN_CHANNEL, lvl);
            DBG_LED_BYTE = (lvl == DIO_HIGH) ? 0xFFu : 0x00u;
            last = now;
        }
    }

    return 0;
}
