/**
 * Swc_ModeSelector.c — Button → Mode SWC implementation.
 *
 * Press-arming debounce: once the button is held for DEBOUNCE_MS the mode
 * is advanced *once*; further holds do nothing until the button is released
 * (re-arms the next press).
 */
#include "Swc_ModeSelector.h"
#include "Rte_ModeSelector.h"

#define DEBOUNCE_MS  20u

static Rte_AppMode_t  s_mode;
static uint32         s_debounce_ms;
static boolean        s_armed;

void SwcModeSelector_Init(void)
{
    s_mode        = RTE_MODE_BLINK_500MS;
    s_debounce_ms = 0u;
    s_armed       = TRUE;
    (void)Rte_Write_Mode_Value(s_mode);
}

void SwcModeSelector_Run(uint32 dt_ms)
{
    boolean pressed = FALSE;
    (void)Rte_Read_Button_Value(&pressed);

    if (pressed == TRUE)
    {
        if (s_armed == TRUE)
        {
            s_debounce_ms += dt_ms;
            if (s_debounce_ms >= DEBOUNCE_MS)
            {
                s_mode = (Rte_AppMode_t)(((uint32)s_mode + 1u) % (uint32)RTE_MODE_COUNT);
                s_armed       = FALSE;
                s_debounce_ms = 0u;
                (void)Rte_Write_Mode_Value(s_mode);
            }
        }
    }
    else
    {
        s_debounce_ms = 0u;
        s_armed       = TRUE;
    }
}
