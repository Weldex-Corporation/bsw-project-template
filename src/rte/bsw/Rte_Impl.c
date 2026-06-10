/**
 * Rte_Impl.c (BSW backend) — port implementation for the osrte style.
 *
 * Inter-SWC port (Mode) goes through BSW Rte_Read/Rte_Write — port table
 * with thread-safe access (necessary under preemptive AUTOSAR Os).
 *
 * SWC → MCAL ports (LedState, Button) still translate to Dio MCAL.
 * This file is the only place application-side code touches Dio.
 */
#include "Rte_LedBlink.h"
#include "Rte_ModeSelector.h"
#include "Rte.h"
#include "Dio.h"
#include "Dio_Cfg.h"

Std_ReturnType Rte_Read_Mode_Value(Rte_AppMode_t *m)
{
    if (m == NULL_PTR) return E_NOT_OK;
    Rte_AppMode_t v = RTE_MODE_OFF;
    (void)Rte_Read(RTE_PORT_MODE_ID, &v, (uint16)sizeof(v));
    *m = v;
    return RTE_E_OK;
}

Std_ReturnType Rte_Write_Mode_Value(Rte_AppMode_t m)
{
    return (Rte_Write(RTE_PORT_MODE_ID, &m, (uint16)sizeof(m)) == RTE_E_OK)
           ? RTE_E_OK : E_NOT_OK;
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
    *pressed = (Dio_ReadChannel(DIO_CH_BTN_S2) == STD_LOW) ? TRUE : FALSE;
    return RTE_E_OK;
}
