/**
 * Rte_LedBlink.h — per-SWC named-port API for Swc_LedBlink.
 *
 * DECLARATIONS ONLY. Implementation lives in a style-specific Rte_Impl.c
 * (rte/static/ or rte/bsw/) selected by CMake at compile time.
 *
 * SWE.3 trace: the SWC sees only this header — no MCAL header, no driver
 * type. Application code is strictly hardware-blind.
 */
#ifndef RTE_LEDBLINK_H
#define RTE_LEDBLINK_H

#include "Rte_Ports.h"

Std_ReturnType Rte_Read_Mode_Value(Rte_AppMode_t *m);
Std_ReturnType Rte_Write_LedState_Value(Rte_LedState_t s);

#endif /* RTE_LEDBLINK_H */
