#ifndef OS_H
#define OS_H
#include <stdint.h>
static inline void Os_Init(void) {}
static inline void Os_DelayMs(uint32_t ms) { (void)ms; }
#endif
