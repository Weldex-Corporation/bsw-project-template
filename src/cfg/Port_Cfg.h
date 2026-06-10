/**
 * Port_Cfg.h — Pin configuration (hand-written).
 *
 * Pin encoding:  port idx (0=GPIOA, 1=GPIOB) in upper byte, pin idx in lower.
 *
 * Pins used by the LED-blink demo:
 *   LED_GREEN — PA0 (LP-MSPM0G3507) or PA22 (LP-MSPM0C1104)
 *   BTN_S2    — PB21 (LP-MSPM0G3507) or PA16 (LP-MSPM0C1104)
 */
#ifndef PORT_CFG_H
#define PORT_CFG_H

#include "Port.h"

#ifdef BOARD_LP_MSPM0C1104
#define PORT_PIN_PA0_LED_GREEN   ((Port_PinType)((0u << 8u) | 22u))  /* PA22 */
#define PORT_PIN_BTN_S2          ((Port_PinType)((0u << 8u) | 16u))  /* PA16 */
#else
#define PORT_PIN_PA0_LED_GREEN   ((Port_PinType)((0u << 8u) | 0u))   /* PA0  */
#define PORT_PIN_BTN_S2          ((Port_PinType)((1u << 8u) | 21u))  /* PB21 */
#endif

extern const Port_ConfigType Port_Config;

#endif /* PORT_CFG_H */
