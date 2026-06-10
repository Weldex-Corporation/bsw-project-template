/**
 * Rte_Ports.h — common RTE port types + IDs.
 *
 * Shared across all three integration styles (baremetal / oslite / osrte).
 * The *implementation* of the named-port API (Rte_Read_*_Value /
 * Rte_Write_*_Value) lives in style-specific headers under rte/static/ or
 * rte/bsw/. Only the data contract is here.
 */
#ifndef RTE_PORTS_H
#define RTE_PORTS_H

#include "Std_Types.h"

/* ---------------------------------------------------------------
 * Port data types
 * --------------------------------------------------------------- */

/** LED-blink application mode (cycled by the button). */
typedef enum {
    RTE_MODE_OFF          = 0,
    RTE_MODE_BLINK_100MS  = 1,
    RTE_MODE_BLINK_500MS  = 2,
    RTE_MODE_COUNT
} Rte_AppMode_t;

/** Current LED commanded state. */
typedef enum {
    RTE_LED_OFF = 0,
    RTE_LED_ON  = 1
} Rte_LedState_t;

/* ---------------------------------------------------------------
 * Port IDs (used by the BSW Rte backend only)
 * --------------------------------------------------------------- */

#define RTE_PORT_MODE_ID        ((uint16)1u)
#define RTE_PORT_LED_STATE_ID   ((uint16)2u)

/* ---------------------------------------------------------------
 * Status (mirrors AUTOSAR Std_ReturnType conventions)
 * --------------------------------------------------------------- */

#ifndef RTE_E_OK
#define RTE_E_OK    ((Std_ReturnType)E_OK)
#endif

#endif /* RTE_PORTS_H */
