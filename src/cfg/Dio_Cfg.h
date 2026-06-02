/**
 * Dio_Cfg.h — LP-MSPM0G3507 DIO channel symbolic IDs (hand-written).
 *
 * Channel encoding (mcal_msp Dio_Hw.c):
 *   upper byte = port (0=GPIOA, 1=GPIOB)
 *   lower byte = pin index
 */
#ifndef DIO_CFG_H
#define DIO_CFG_H

#include "Dio.h"

#define DIO_CH_LED_GREEN   ((Dio_ChannelType)0u)    /* PA0  */
#define DIO_CH_BTN_S2      ((Dio_ChannelType)14u)   /* PA14 */

extern const Dio_ConfigType Dio_Config;

#endif /* DIO_CFG_H */
