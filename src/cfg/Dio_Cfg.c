/**
 * Dio_Cfg.c — Dio_Config for LP-MSPM0G3507.
 *
 * mcal_msp Dio_Init() currently uses the channel list for validation only;
 * direction is owned by Port_Init. Keeping the table explicit makes the
 * SWE.1 → SWE.3 trace easy to read.
 */
#include "Dio_Cfg.h"

static const Dio_ChannelType s_channels[] = {
    DIO_CH_LED_GREEN,
    DIO_CH_BTN_S2,
};

const Dio_ConfigType Dio_Config = {
    .channels     = s_channels,
    .numChannels  = sizeof(s_channels) / sizeof(s_channels[0]),
};
