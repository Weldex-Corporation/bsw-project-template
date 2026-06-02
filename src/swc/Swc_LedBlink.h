/**
 * Swc_LedBlink.h — public interface of the LED-blink SWC.
 *
 * The SWC owns the blink state machine: it reads the Mode port, advances
 * an internal phase counter, and writes the LedState port. It does NOT
 * read its own driver — that is the integrator's job (Rte_Write_LedState
 * goes to Dio in the static backend, through Rte_Write in the BSW backend).
 *
 * Same translation unit compiles bit-identically for all 3 integration
 * styles. Only the Rte backend (via include path) differs.
 */
#ifndef SWC_LEDBLINK_H
#define SWC_LEDBLINK_H

#include "Std_Types.h"

/**
 * Initialise internal state. Called once before the first Run.
 */
void SwcLedBlink_Init(void);

/**
 * Periodic runnable. Caller passes elapsed milliseconds since the
 * previous invocation.
 */
void SwcLedBlink_Run(uint32 dt_ms);

#endif /* SWC_LEDBLINK_H */
