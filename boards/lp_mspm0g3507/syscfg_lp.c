/**
 * @file syscfg_lp.c
 * @brief LP-MSPM0G3507 LaunchPad — minimal system init (overrides weak defs)
 *
 * Adapted from bsw/platform/bsw-mcal-msp/examples/rgb_led_pwm/syscfg_lp.c.
 *
 * The default system/ti_msp_dl_config.c shipped in the bsw-mcal-msp SDK is
 * PLCA-specific: it inits HFXT, MCAN, UART, ADC, VREF and waits for
 * HFCLK_GOOD — which hangs on the LP-MSPM0G3507 LaunchPad because the
 * board has no HFXT crystal.
 *
 * This file provides strong definitions that override the SYSCONFIG_WEAK
 * functions with LP-appropriate init:
 *   - SYSOSC 32 MHz (internal, no crystal needed)
 *   - GPIO power for GPIOA / GPIOB
 *   - No HFXT, no MCAN, no UART, no ADC
 *
 * SysTick_Handler / Mcu_GetTickMs / mcu_tick_ms are owned by Mcu_Hw.c in
 * libmcal_msp.a (already strong in the static archive after the ISS-1526
 * refactor), so the board layer does not redefine them.
 */
#include "ti_msp_dl_config.h"
#include "Mcu.h"

void SYSCFG_DL_init(void)
{
    SYSCFG_DL_initPower();
    SYSCFG_DL_SYSCTL_init();
}

void SYSCFG_DL_initPower(void)
{
    DL_GPIO_reset(GPIOA);
    DL_GPIO_reset(GPIOB);
    DL_GPIO_enablePower(GPIOA);
    DL_GPIO_enablePower(GPIOB);
    delay_cycles(POWER_STARTUP_DELAY);
}

void SYSCFG_DL_SYSCTL_init(void)
{
    DL_SYSCTL_setSYSOSCFreq(DL_SYSCTL_SYSOSC_FREQ_BASE);
}
