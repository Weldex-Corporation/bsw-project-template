/**
 * Rte_Impl.c (static backend) — port implementation for baremetal / oslite.
 *
 * Inter-SWC port (Mode) is a single static variable. Lock-free is safe
 * here because the static backend pairs with cooperative integration
 * styles where readers and writers never preempt each other.
 *
 * SWC → MCAL ports (LedState, Button) translate directly to Dio MCAL.
 * This file is the ONLY place application-side code touches Dio in the
 * static backend.
 */
#include "Rte_LedBlink.h"
#include "Rte_ModeSelector.h"
#include "Dio.h"
#include "Dio_Cfg.h"

static volatile Rte_AppMode_t s_mode = RTE_MODE_OFF;

Std_ReturnType Rte_Read_Mode_Value(Rte_AppMode_t *m)
{
    if (m == NULL_PTR) return E_NOT_OK;
    *m = s_mode;
    return RTE_E_OK;
}

Std_ReturnType Rte_Write_Mode_Value(Rte_AppMode_t m)
{
    s_mode = m;
    return RTE_E_OK;
}

Std_ReturnType Rte_Write_LedState_Value(Rte_LedState_t s)
{
#ifdef DIO_LED_GREEN_ACTIVE_LOW
    Dio_WriteChannel(DIO_CH_LED_GREEN, (s == RTE_LED_ON) ? STD_LOW : STD_HIGH);
#else
    Dio_WriteChannel(DIO_CH_LED_GREEN, (s == RTE_LED_ON) ? STD_HIGH : STD_LOW);
#endif
    return RTE_E_OK;
}

Std_ReturnType Rte_Read_Button_Value(boolean *pressed)
{
    if (pressed == NULL_PTR) return E_NOT_OK;
    /* PA14 is active-LOW (internal pull-up). */
    *pressed = (Dio_ReadChannel(DIO_CH_BTN_S2) == STD_LOW) ? TRUE : FALSE;
    return RTE_E_OK;
}
