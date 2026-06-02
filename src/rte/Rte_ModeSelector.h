/**
 * Rte_ModeSelector.h — per-SWC named-port API for Swc_ModeSelector.
 *
 * DECLARATIONS ONLY. Implementation lives in a style-specific Rte_Impl.c.
 */
#ifndef RTE_MODESELECTOR_H
#define RTE_MODESELECTOR_H

#include "Rte_Ports.h"

Std_ReturnType Rte_Read_Button_Value(boolean *pressed);
Std_ReturnType Rte_Write_Mode_Value(Rte_AppMode_t m);

#endif /* RTE_MODESELECTOR_H */
