/**
 * Application-level stubs for BSW framework hooks.
 *
 * EcuM_Init() in the BSW framework calls a small set of application-provided
 * functions (debug/console + cooperative-dispatcher). The template provides
 * no-op stubs so the firmware links; a real application should replace these
 * with its own debug UART and scheduler integration.
 */

#include <stdarg.h>
#include <stdint.h>

/* Debug console hooks. */
void debug_init(void)        { /* no-op */ }
void debug_flush(void)       { /* no-op */ }
void debug_time_printf(const char *fmt, ...) { (void)fmt; }

/* Cooperative dispatcher hooks. */
void dispatch_init(void)     { /* no-op */ }
void dispatch_run(void)      { /* no-op */ }

/* AUTOSAR Development Error Tracer — log + ignore. */
typedef uint8_t Std_ReturnType;
Std_ReturnType Det_ReportError(uint16_t ModuleId, uint8_t InstanceId,
                               uint8_t ApiId,    uint8_t ErrorId)
{
    (void)ModuleId; (void)InstanceId; (void)ApiId; (void)ErrorId;
    return 0;
}
