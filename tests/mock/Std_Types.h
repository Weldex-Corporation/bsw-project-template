#ifndef STD_TYPES_H
#define STD_TYPES_H
#include <stdint.h>

/* AUTOSAR integer aliases (matches bsw/legacy/framework/Std_Types.h). */
typedef uint8_t   uint8;
typedef uint16_t  uint16;
typedef uint32_t  uint32;
typedef int8_t    sint8;
typedef int16_t   sint16;
typedef int32_t   sint32;

typedef uint8_t   Std_ReturnType;
typedef uint8_t   boolean;

#define TRUE      1u
#define FALSE     0u
#define STD_HIGH  1u
#define STD_LOW   0u
#define E_OK      0u
#define E_NOT_OK  1u
#define NULL_PTR  ((void*)0)
#endif
