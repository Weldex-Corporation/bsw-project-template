/**
 * @file syscfg_lp.c
 * @brief LP-MSPM0C1104 LaunchPad — minimal system init (overrides weak defs)
 *
 * MSPM0C1104 differences from MSPM0G3507:
 *   - GPIOA only (no GPIOB)
 *   - 24 MHz SYSOSC (DL_SYSCTL_SYSOSC_FREQ_BASE)
 *   - No HFXT, no PLL, no MCAN, no UART (in this minimal init)
 *   - BTN_S2 on PA16 (IOMUX_PINCM17) instead of PB21
 *   - LED1 on PA22 (IOMUX_PINCM23) instead of PA0
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
    DL_GPIO_enablePower(GPIOA);
    delay_cycles(POWER_STARTUP_DELAY);

    /* PA22 — LED1 output (IOMUX_PINCM23) */
    DL_GPIO_initDigitalOutput(IOMUX_PINCM23);
    DL_GPIO_enableOutput(GPIOA, DL_GPIO_PIN_22);

    /* PA16 — USER button S2 input with pull-up (IOMUX_PINCM17), active low */
    DL_GPIO_initDigitalInputFeatures(IOMUX_PINCM17,
        DL_GPIO_INVERSION_DISABLE, DL_GPIO_RESISTOR_PULL_UP,
        DL_GPIO_HYSTERESIS_DISABLE, DL_GPIO_WAKEUP_DISABLE);
}

void SYSCFG_DL_SYSCTL_init(void)
{
    DL_SYSCTL_setSYSOSCFreq(DL_SYSCTL_SYSOSC_FREQ_BASE);
}
