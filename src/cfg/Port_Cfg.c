/**
 * Port_Cfg.c — Port_Config for LP-MSPM0G3507.
 *
 * Direction + initial mode for each pin used by the application.
 * Actual MMIO programming happens in syscfg_lp.c (SYSCFG_DL_initPower);
 * this table is the AUTOSAR Port_Init view used by the BSW Port MCAL.
 */
#include "Port_Cfg.h"

static const Port_PinConfigType s_pins[] = {
    {
        .pin                  = PORT_PIN_PA0_LED_GREEN,
        .direction            = PORT_PIN_OUT,
        .initialMode          = PORT_PIN_MODE_GPIO,
        .directionChangeable  = FALSE,
        .modeChangeable       = FALSE,
    },
    {
        .pin                  = PORT_PIN_PA14_BTN_S2,
        .direction            = PORT_PIN_IN,
        .initialMode          = PORT_PIN_MODE_GPIO,
        .directionChangeable  = FALSE,
        .modeChangeable       = FALSE,
    },
};

const Port_ConfigType Port_Config = {
    .pins     = s_pins,
    .numPins  = sizeof(s_pins) / sizeof(s_pins[0]),
};
