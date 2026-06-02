#include "Dio.h"
/* Backing storage for mock GPIO channel levels */
Dio_LevelType mock_dio_channel_level[MOCK_DIO_NUM_CHANNELS] = {0};
