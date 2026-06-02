#ifndef DIO_H
#define DIO_H
#include "Std_Types.h"

typedef uint8_t Dio_ChannelType;
typedef uint8_t Dio_LevelType;

/* Mirror real Dio_ConfigType so the application's Dio_Cfg.{c,h} compiles
 * unchanged in the host build. The mock Dio_Init ignores the table. */
typedef struct {
    const Dio_ChannelType *channels;
    uint8                  numChannels;
} Dio_ConfigType;

#define DioConf_DioChannel_LED_GREEN  0u
#define DioConf_DioChannel_LED_BLUE   1u
#define DioConf_DioChannel_LED_RED    2u
#define DioConf_DioChannel_BUTTON_S2  14u   /* PA14, active low */

#define MOCK_DIO_NUM_CHANNELS 16u

/* Track last written/read level per channel for test assertions */
extern Dio_LevelType mock_dio_channel_level[MOCK_DIO_NUM_CHANNELS];

static inline void Dio_Init(void* cfg)
{
    (void)cfg;
    for (int i = 0; i < (int)MOCK_DIO_NUM_CHANNELS; i++)
        mock_dio_channel_level[i] = STD_LOW;
    /* Simulate pull-up on button channel: HIGH = not pressed */
    mock_dio_channel_level[DioConf_DioChannel_BUTTON_S2] = STD_HIGH;
}

static inline void Dio_WriteChannel(Dio_ChannelType ch, Dio_LevelType lvl)
{
    if (ch < MOCK_DIO_NUM_CHANNELS) mock_dio_channel_level[ch] = lvl;
}

static inline Dio_LevelType Dio_ReadChannel(Dio_ChannelType ch)
{
    return (ch < MOCK_DIO_NUM_CHANNELS) ? mock_dio_channel_level[ch] : STD_LOW;
}
#endif
