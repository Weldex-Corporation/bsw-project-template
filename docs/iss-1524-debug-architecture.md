# ISS-1524 — BSW Debug Output Integration (Design)

Status: **Proposal**, design-only — no BSW code change yet
Related: ISS-1521, ISS-1522, ISS-1526 (BSW dual-path), ISS-1523/1530 (Renode SIL)

## 1. Problem

BSW core modules (EcuM, Det, ComM, Ea, CanIf, Dem, Dcm, …) call three
unresolved symbols out of the box:

```
debug_init()
debug_flush()
debug_time_printf(const char *fmt, ...)
```

These have **no implementation inside BSW**. Every consuming project has
to ship its own. The current project_template solves this with
`src/app_stubs.c` — six no-op functions plus `Det_ReportError` — which
is OK as a workaround but means:

- the application is responsible for transport-layer plumbing
  (RTT? UART? semihosting? stdout?), even though the application's
  job is to wire a board, not invent a debug bus;
- different applications will diverge on backend choice and behavior,
  defeating the point of a shared BSW;
- `bsw-mcal-msp` already ships a working RTT + DBG pair
  (`platform/bsw-mcal-msp/{rtt,dbg}/`) but it is gated behind
  `ENABLE_DEBUG=ON` and is not connected to the BSW `debug_*` surface
  EcuM expects.

## 2. Target architecture (AUTOSAR-style layering)

```
+---------------------------------------------------------+
|  BSW core (EcuM, Det, ComM, Ea, CanIf, Dem, Dcm, …)     |
|    calls  debug_init / debug_flush / debug_time_printf  |
+---------------------------------------------------------+
                          |
                          v
+---------------------------------------------------------+
|  bsw_debug (NEW, BSW frontend, platform-agnostic)       |
|    debug_init       -> Dbg_Init                         |
|    debug_flush      -> Dbg_Flush                        |
|    debug_time_printf-> snprintf + timestamp +           |
|                        Dbg_PutBuffer                    |
+---------------------------------------------------------+
                          |
                          v
+---------------------------------------------------------+
|  MCAL Dbg contract (NEW header)                         |
|    Std_ReturnType Dbg_Init   (void)                     |
|    void           Dbg_PutChar(uint8 c)                  |
|    void           Dbg_PutBuffer(const uint8 *buf,       |
|                                 uint16 len)             |
|    void           Dbg_Flush  (void)                     |
+---------------------------------------------------------+
                          |  (implemented per platform)
        +-----------------+-----------------+----------------+
        |                 |                 |                |
        v                 v                 v                v
+---------------+ +---------------+ +---------------+ +-----------+
| Dbg_Rtt       | | Dbg_Uart      | | Dbg_Semihost  | | Dbg_Stdout|
| SEGGER_RTT    | | mcal UART     | | ARM SH BKPT   | | POSIX     |
| (mspm0 real)  | | (renode SIL,  | | (mspm0 with   | | (host)    |
|               | |  any board    | |  J-Link)      | |           |
|               | |  with UART)   | |               | |           |
+---------------+ +---------------+ +---------------+ +-----------+
```

## 3. Where things live

| Artifact | Repo | Path | New / existing |
|----------|------|------|----------------|
| MCAL Dbg contract header | bsw | `bsw/legacy/mcal/hal/Dbg/Dbg.h` | NEW |
| BSW debug frontend | bsw | `bsw/legacy/framework/debug/bsw_debug.c` + header | NEW (folder + lib target) |
| RTT backend (mspm0) | bsw-mcal-msp | `dbg/Dbg_Rtt.c` (move/rename of `dbg/dbg.c`) | REWORK existing |
| UART backend (renode/board) | bsw | `bsw/legacy/mcal/<plat>/Dbg_Uart.c` | NEW per platform |
| Semihosting backend | bsw | `bsw/legacy/mcal/cortex_m/Dbg_Semihost.c` | NEW (optional) |
| POSIX/stdout backend | bsw | `bsw/legacy/mcal/posix/Dbg_Stdout.c` | NEW |

## 4. Build option surface

```
option(BSW_DEBUG_BACKEND
    "Debug backend: rtt | uart | semihost | stdout | none"
    "none")
```

Resolution rules baked into BSW:

| BSW_DEBUG_BACKEND | PLATFORM | Selected backend lib | Notes |
|-------------------|----------|----------------------|-------|
| `none`            | any      | `bsw_debug_null`     | All `debug_*` are no-ops. Today's default behaviour (= app_stubs.c). |
| `rtt`             | mspm0    | `Dbg_Rtt` (from bsw-mcal-msp) | Requires J-Link or RTT-aware probe. Default for real boards. |
| `uart`            | mspm0    | `Dbg_Uart_mspm0`     | Uses UART0 via mcal_msp. |
| `uart`            | renode   | `Dbg_Uart_renode`    | Writes to the LiteX_UART model already in the .repl — SIL log captured. |
| `semihost`        | mspm0    | `Dbg_Semihost`       | ARM semihosting bkpt. Good for first-bringup debug. |
| `stdout`          | posix    | `Dbg_Stdout`         | Host build. Trivial. |

Cross-platform behaviour: invalid (backend, platform) combinations are
caught at configure time with a FATAL_ERROR message.

## 5. Migration plan (incremental, no big-bang)

This epic is intentionally NOT a prerequisite for any other Sprint 208
ticket. It can land independently and asynchronously.

1. **PR-1 (BSW)** — introduce the contract + frontend skeleton.
   - Add `bsw/legacy/mcal/hal/Dbg/Dbg.h` (contract).
   - Add `bsw_debug` STATIC library with `debug_init` / `debug_flush` /
     `debug_time_printf` defined on top of the Dbg contract.
   - Add `bsw_debug_null` backend (no-op Dbg_*). This is the default
     when `BSW_DEBUG_BACKEND=none`.
   - Wire `bsw` target to PUBLIC-link `bsw_debug`, so the
     `debug_init/...` symbols are no longer unresolved when a consumer
     just links `bsw + mcal_<platform>`. This **removes the need for
     `src/app_stubs.c` in project_template**.
2. **PR-2 (BSW-mcal-msp)** — adapt the existing `rtt/SEGGER_RTT.c` +
   `dbg/dbg.c` into a real Dbg backend that implements the contract.
   - Rename `dbg.c` → `Dbg_Rtt.c`, refit its `dbg_init` to be
     `Dbg_Init`, expose `Dbg_PutBuffer` over `SEGGER_RTT_Write`.
   - Add `Dbg_Rtt` STATIC library target.
3. **PR-3 (BSW renode + UART backend)** — for SIL.
   - Add a tiny `Dbg_Uart_renode.c` that writes to the LiteX_UART
     model. Renode `Mach_StartGDBServer`/`uart0 CreateUARTLogger`
     plumbing in the .robot test captures the output.
4. **PR-4 (project_template)** — pick `BSW_DEBUG_BACKEND=uart` for
   `renode-sil`, `BSW_DEBUG_BACKEND=rtt` for `bsw-mcal-msp`,
   `BSW_DEBUG_BACKEND=none` for `host-test`. Delete
   `src/app_stubs.c` (the only remaining symbol after this — once
   `Det_ReportError` is also placed in `bsw_debug` or in `Det.c`
   itself).

## 6. Open design questions (resolve before PR-1)

1. **Should `Det_ReportError` live in `bsw_debug` too, or in `Det.c`
   itself?** Today's `src/app_stubs.c` defines it as a no-op. The
   cleanest home is `Det.c` (it is literally the Det module), but
   moving it there means a tiny BSW PR before this epic — call out
   in PR-1.

2. **`debug_time_printf` timestamp source.** The existing `dbg.c`
   reads `Mcu_GetTickMs()`. That is fine on real silicon. On Renode,
   `Mcu_GetTickMs` only advances when SysTick is wired (ISS-1530).
   Use the same source either way — SIL just inherits the timing fix
   ISS-1530 lands.

3. **RTT availability in Renode.** Renode does not model SEGGER RTT
   out of the box. SIL builds therefore must NOT pick
   `BSW_DEBUG_BACKEND=rtt`. The configure-time matrix in §4
   enforces this.

4. **Backwards compatibility with `BSW_USE_LEGACY_HAL=ON` consumers.**
   When the legacy HAL path is enabled, existing application code may
   already provide its own `debug_*` strong definitions. The new
   `bsw_debug` library's symbols should be marked `__attribute__((weak))`
   so application overrides still win without breaking the build.

## 7. Out of scope

- Telemetry / RTT viewer integration (separate ticket if needed).
- Log filtering, log levels, severity (existing `DBG_MAX_LEVEL` in
  `dbg.h` is a starting point; not changed here).
- Persistent error log to flash (Dem/Det responsibility, not Dbg).
