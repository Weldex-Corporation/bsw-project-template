/**
 * Port_Cfg.h — LP-MSPM0G3507 pin configuration (hand-written).
 *
 * Traceable to:  boards/lp_mspm0g3507.yaml  (SWE.1 HW interface).
 * Pin encoding:  port idx (0=GPIOA, 1=GPIOB) in upper byte, pin idx in lower.
 *
 * Pins used by the LED-blink demo:
 *   PA0  — LED_GREEN  (output, active HIGH)
 *   PA14 — BTN_S2     (input, active LOW, internal pull-up)
 */
#ifndef PORT_CFG_H
#define PORT_CFG_H

#include "Port.h"

#define PORT_PIN_PA0_LED_GREEN   ((Port_PinType)((0u << 8u) | 0u))
#define PORT_PIN_PB21_BTN_S2     ((Port_PinType)((1u << 8u) | 21u))

extern const Port_ConfigType Port_Config;

#endif /* PORT_CFG_H */
