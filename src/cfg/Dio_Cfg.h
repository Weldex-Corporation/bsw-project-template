/**
 * Dio_Cfg.h — DIO channel symbolic IDs (hand-written).
 *
 * Channel encoding (mcal_msp Dio_Hw.c):
 *   upper byte = port (0=GPIOA, 1=GPIOB)
 *   lower byte = pin index
 */
#ifndef DIO_CFG_H
#define DIO_CFG_H

#include "Dio.h"

#ifdef BOARD_LP_MSPM0C1104
#define DIO_CH_LED_GREEN   ((Dio_ChannelType)22u)                   /* PA22 */
#define DIO_CH_BTN_S2      ((Dio_ChannelType)16u)                   /* PA16 */
#define DIO_LED_GREEN_ACTIVE_LOW 1   /* PA22 active-low LED */
#else
#define DIO_CH_LED_GREEN   ((Dio_ChannelType)0u)                    /* PA0  */
#define DIO_CH_BTN_S2      ((Dio_ChannelType)((1u << 8u) | 21u))   /* PB21 */
/* DIO_LED_GREEN_ACTIVE_LOW not defined → active-high */
#endif

extern const Dio_ConfigType Dio_Config;

#endif /* DIO_CFG_H */
