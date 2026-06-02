#include "app_mode.h"
#include "Dio.h"
#include "Std_Types.h"

/* PA14 = GPIOA pin 14 — USER button (S2) on LP-MSPM0G3507, active low */
#define BUTTON_CHANNEL  ((Dio_ChannelType)14u)
#define DEBOUNCE_MS     20u

static AppMode_t s_mode;
static uint32_t  s_debounce_ms;
static boolean   s_armed;

void AppMode_Init(void)
{
    s_mode        = APP_MODE_OFF;
    s_debounce_ms = 0u;
    s_armed       = TRUE;
}

void AppMode_Tick(uint32_t dt_ms)
{
    Dio_LevelType btn = Dio_ReadChannel(BUTTON_CHANNEL);

    if (btn == STD_LOW)
    {
        /* Button held (active low) — accumulate debounce time */
        if (s_armed == TRUE)
        {
            s_debounce_ms += dt_ms;
            if (s_debounce_ms >= DEBOUNCE_MS)
            {
                s_mode        = (AppMode_t)(((uint32_t)s_mode + 1u) % (uint32_t)APP_MODE_COUNT);
                s_armed       = FALSE;
                s_debounce_ms = 0u;
            }
        }
    }
    else
    {
        /* Button released — re-arm for next press */
        s_debounce_ms = 0u;
        s_armed       = TRUE;
    }
}

AppMode_t AppMode_Get(void)
{
    return s_mode;
}
