#ifndef DIO_H
#define DIO_H
#include "Std_Types.h"

typedef uint8_t Dio_ChannelType;
typedef uint8_t Dio_LevelType;

#define DioConf_DioChannel_LED_GREEN  0u
#define DioConf_DioChannel_LED_BLUE   1u
#define DioConf_DioChannel_LED_RED    2u

/* Track last written level per channel for test assertions */
extern Dio_LevelType mock_dio_channel_level[8];

static inline void Dio_Init(void* cfg)
{
    (void)cfg;
    for (int i = 0; i < 8; i++) mock_dio_channel_level[i] = STD_LOW;
}

static inline void Dio_WriteChannel(Dio_ChannelType ch, Dio_LevelType lvl)
{
    if (ch < 8u) mock_dio_channel_level[ch] = lvl;
}

static inline Dio_LevelType Dio_ReadChannel(Dio_ChannelType ch)
{
    return (ch < 8u) ? mock_dio_channel_level[ch] : STD_LOW;
}
#endif
