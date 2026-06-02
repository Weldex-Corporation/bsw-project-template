/**
 * @file hal_system_shim.c
 * @brief Minimal stand-in for the legacy `hal_system_*` symbols that
 *        Cortex-M0+ rte_os builds reference.
 *
 * Background — `bsw-mcal-msp/legacy/hal/hal_system.c` cannot be assembled
 * on Cortex-M0+ because of an inline-asm `.syntax`-mismatch in
 * `hal_system_start_application` (see docs/upstream-issues.md #1).
 * The Os_bcc1 + EcuM_bcc1 path doesn't need any of that file, but
 * other legacy framework code (dispatch.c) still references
 * `hal_system_sw_interrupt_*`. That mechanism is already a no-op on
 * MSPM0 (the original `hal_system.c` declared them empty), so this
 * shim trivially satisfies the link without bringing the broken TU
 * into the build.
 *
 * Once dispatch.c is itself migrated off the legacy hal_system_*
 * surface, this shim can be deleted.
 */
#include <stdint.h>

/* No-op stubs — original MSPM0 hal_system.c had empty bodies for
 * these. Dispatch.c's queue-drain pattern works without an actual
 * SW-interrupt: ready work is processed at the next dispatch_run()
 * call from the main loop. */

int  hal_system_sw_interrupt_init(void)                                { return 0; }
int  hal_system_sw_interrupt_register_handler(int level, void *h)      { (void)level; (void)h; return 0; }
void hal_system_sw_interrupt_trigger(int level)                        { (void)level; }
int  hal_system_register_tick_callback(int slot, void *callback)       { (void)slot; (void)callback; return 0; }

/* `lock_count` is a counter that hal_critical.c reads/writes; the
 * legacy hal_system.c owned the storage. Provide it here so the
 * critical-section primitives link. */
uint32_t lock_count = 0u;

/* `hal_system_get_time` was the legacy ms-tick read used by
 * `Mcu_GetTickMs` and similar wrappers. All migrated callers now
 * read the Os counter directly via Os_GetCounterValue; the few
 * remaining legacy references just want a monotonic uint32 so
 * we forward to the standard OSEK API. */
extern uint8_t Os_GetCounterValue(uint8_t cid, uint32_t *value);

uint32_t hal_system_get_time(void)
{
    uint32_t v = 0u;
    (void)Os_GetCounterValue(0u /* OS_COUNTER_SYSTEM */, &v);
    return v;
}
