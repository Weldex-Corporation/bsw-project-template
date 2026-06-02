/**
 * Swc_ModeSelector.h — public interface of the mode-selector SWC.
 *
 * Reads the button (active-low) via Rte_Read_Button_Value, debounces, and
 * cycles the Mode port through OFF → BLINK_100ms → BLINK_500ms → OFF on
 * each completed press.
 */
#ifndef SWC_MODESELECTOR_H
#define SWC_MODESELECTOR_H

#include "Std_Types.h"

void SwcModeSelector_Init(void);
void SwcModeSelector_Run(uint32 dt_ms);

#endif /* SWC_MODESELECTOR_H */
