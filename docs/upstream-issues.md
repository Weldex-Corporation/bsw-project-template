# Upstream Issues — discovered while bringing up `APP_MODEL=rte_os`

Status: open (Issue #1 — worked around in PR #38, see below)
Last updated: 2026-06-02

Problems encountered in `bsw` / `bsw-mcal-msp` submodules while wiring the
full AUTOSAR (RTE + Os) integration style for LP-MSPM0G3507. Each item
needs a fix upstream before the `rte_os` preset reaches *runtime-verified*
status. The template can ship the SWC / RTE / Os structure today; runtime
on real silicon depends on these landing.

---

## 1. `bsw-mcal-msp` — `hal_system.c` fails to compile on Cortex-M0+

**Status**: ✅ **Worked around in template** ([bsw-project-template
#38](https://github.com/Weldex-Corporation/bsw-project-template/pull/38)).
The upstream `hal_system.c` is no longer compiled by `APP_MODEL=rte_os`;
the symbols that legacy framework code (`dispatch.c`, `Rte.c`, …) still
references are provided by a tiny local `src/hal_system_shim.c`. The
upstream `.syntax unified` patch described below is now optional —
useful only for anyone building the legacy dispatch-backed Os on
Cortex-M0+, which our rte_os path no longer does.


**Symptom**

```
arm-none-eabi-gcc … -mcpu=cortex-m0plus -mthumb -mfloat-abi=soft …
  bsw-mcal-msp/legacy/hal/hal_system.c
/tmp/cclJX9Qv.s: Assembler messages:
/tmp/cclJX9Qv.s:502: Error: instruction not supported in Thumb16 mode -- `adds r1,r1,#4'
```

**Where**

`bsw-mcal-msp/legacy/hal/hal_system.c:153-174`, the inline assembly
block inside `hal_system_start_application` (bootloader
application-jump pattern). The `adds` mnemonic with `s`-suffix is
**UAL syntax** that requires `.syntax unified`; GCC's inline-asm scaffolding
emits `.syntax divided` immediately before every inline asm block, so
the assembler falls back to pre-UAL Thumb-1 grammar where `adds Rd, Rn,
#imm3` is unrecognised.

Verified by reproducing standalone (`adds r1, #4`, `adds r2, r1, #4`,
`adds r1, r1, #4` all reject identically under `-mcpu=cortex-m0plus
-mthumb`); inspecting the generated `.s` confirms `.syntax divided` is
active when the inline asm is processed.

(The `-Warray-bounds` warnings on line 146 are independent — they
flag the C-level cast `(uint32_t *)(start_address + 4)` and would
remain even after the assembly fix; cosmetic, not blocking.)

**Impact (historical, before the workaround)**

Blocked `APP_MODEL=rte_os` link: BSW `dispatch.c` / legacy `Os.c`
referenced `hal_system_register_tick_callback` and
`hal_system_sw_interrupt_trigger`, which live in `hal_system.c` —
and that TU did not compile for M0+. The Os_bcc1 + EcuM_bcc1 refactor
routed around the legacy dispatch backing entirely, but `dispatch.c`
itself is still pulled into rte_os builds (Rte/SchM use it), so the
template now ships an `src/hal_system_shim.c` with no-op stubs for the
4 sw-interrupt entry points + `lock_count` + `hal_system_get_time`
(forwards to `Os_GetCounterValue`). This satisfies the link without
bringing `hal_system.c` into the build.

**Fix upstream (optional, low priority now)**

Smallest diff — keep UAL semantics, prefix the inline asm with a
syntax directive:

```diff
   __asm volatile (
+      ".syntax unified\n"
       "mov r3, %0\n"
       …
       "blx r3\n"
+      ".syntax divided\n"
       :
```

Alternative — drop the `s` suffix (`adds` → `add`). Equivalent on
Thumb-1 because low-register `add` implicitly sets flags, and the
flag side-effect is unused here. Less explicit, so the directive
approach is preferred.

**Suggested location for the fix**

`bsw-mcal-msp` repo, separate PR. With the template workaround in
place this is no longer blocking — useful only for users who want
to compile the legacy dispatch-backed Os against `bsw-mcal-msp` on
Cortex-M0+ (i.e. not the rte_os path this template uses).

---

## 2. `bsw-mcal-msp` — `gen_cfg.py` UART instance-name duplication

**Symptom**

Run `tools/gen_cfg.py boards/lp_mspm0g3507.yaml /tmp/out/`:

```
ValueError: No IOMUX function for (PA10, UARTUART0, TX) on chip 'MSPM0G3507'.
  Available on PA10: ['UART0_TX', 'SPI0_MISO', 'TIMA1_CCP0', 'TIMG12_CCP0', 'TIMA0_CCP2']
```

**Where**

`bsw-mcal-msp/tools/gen_cfg.py`, `gen_uart()` function around line
~329 (`_func(chip, tx, periph, 'TX')` call). The `periph` variable
appears to be the full string `"UART0"` from the YAML `instance:` field,
which then gets prepended with `"UART"` to produce `"UARTUART0_TX"` —
the chip DB has the entry as `"UART0_TX"`.

Likely root cause: `periph` should be the bare instance number (`0`)
when the IOMUX-function-name builder appends a fixed prefix, or the
prefix should be dropped when `periph` already contains it.

**Input YAML that triggers it**

```yaml
uart:
  - instance:  UART0
    tx_pin:    PA10
    rx_pin:    PA11
    baudrate:  115200
```

(Identical to what the BSW example `mcal_mspm0_led/board_config.yaml`
gets away with — that example may simply not exercise UART, or the
chip DB it uses differs.)

**Impact**

Blocks the `CFG_FROM_YAML=ON` toggle in this template — `gen_cfg.py`
aborts before producing `Port_Cfg` / `Dio_Cfg`. Workaround today:
`CFG_FROM_YAML=OFF` (default) uses the hand-written `src/cfg/`.

**Suggested location for the fix**

`bsw-mcal-msp` repo, `tools/gen_cfg.py` (`gen_uart`).

---

## 3. `bsw-mcal-msp` — chip database not tracked in the submodule

**Symptom**

`tools/gen_cfg.py` requires
`bsw-mcal-msp/tools/chips/<chip_lower>.json` (e.g.
`mspm0g3507.json`). A fresh `git clone` of `bsw-mcal-msp` does **not**
contain this file — only `tools/chips/pkg/*.json` (SysConfig-exported
per-package JSONs) are tracked.

The merged `tools/chips/<chip>.json` is produced by
`tools/extract_syscfg_db.py` (requires TI SysConfig CLI) or
`parse_iomux.py` (requires the SDK iomux header). Neither is run
automatically.

**Impact**

Even after fix #2 lands, `CFG_FROM_YAML=ON` cannot work on a fresh
clone without an extra setup step.

**Possible fixes**

1. Commit the merged `tools/chips/<chip>.json` for the chips this MCAL
   officially supports (small files, ~13 KB each — currently 1 file per
   chip family).
2. Add a `bsw-mcal-msp` CMake step that auto-runs `parse_iomux.py` from
   the SDK header at configure time, with a clear error if the SDK
   header is not found.
3. Add `_shared/setup.py` (template-side) bootstrap to fetch / regenerate
   the chip DB on first run.

**Suggested location for the fix**

Combination — primary in `bsw-mcal-msp` (option 1 or 2), template
support in `_shared/setup.py` (option 3).

---

## 5. (Watching) `bsw-mcal-msp` — Renode TIMG7 model doesn't fire time-based IRQ

**Symptom (SIL-only, real silicon unaffected)**

`renode/models/mspm0_timg7.py` correctly models register writes from
`Gpt_Init` / `Gpt_StartTimer` (PWREN / CPS / IMASK / CTRCTL=EN|REPEAT /
LOAD all latch as expected) but the time-based fire path never
delivers an IRQ to NVIC. `os_counter_ms` therefore stays at 0 in the
rte_os SIL even though the firmware is configured correctly.

The software-trigger (ISET) path inside the same model works —
`test_missing_periph.robot` exercises it. Only the time-based
`ScheduleAction` / `LimitTimer` paths are broken.

**Impact**

SIL coverage of any periodic-tick firmware (rte_os, oslite) is
incomplete. Real-silicon and bare-metal builds are unaffected
because TI driverlib programs the actual TIMG7 IP which fires for
real on a LaunchPad.

**Suggested fix**

See `docs/renode-timg7-model-gap.md` — the cleanest fix is to add a
native Renode `LimitTimer` in `mspm0g3507.repl` wired to NVIC IRQ 20.
The Python model continues to handle register state; the native timer
handles IRQ generation. A heavier alternative is to rewrite the model
as a proper C# peripheral.

**Suggested location for the fix**

`bsw-mcal-msp` repo, `renode/mspm0g3507.repl` + `renode/models/`.

---

## 4. (Watching) `bsw` — `Fls.h` redefines `MEMIF_JOB_FAILED`

**Symptom (warning, not blocking)**

```
bsw/legacy/framework/../mcal/hal/Fls/Fls.h:34: warning: "MEMIF_JOB_FAILED" redefined
   34 | #define MEMIF_JOB_FAILED    ((MemIf_JobResultType)1u)
   33 | #define MEMIF_JOB_FAILED        0x01u
```

Two AUTOSAR Fls/MemIf headers define the same macro with different
types. Currently warning-only; would become an error under
`-Werror=macro-redefined`.

**Impact**

Cosmetic for the template today. Worth tracking in case a future
`-Werror` tightening breaks the build.

**Suggested location for the fix**

`bsw` repo, MCAL contract headers (`bsw/legacy/mcal/hal/Fls/Fls.h` vs
the AUTOSAR `MemIf` definition).

---

## How this list is used

Each entry needs a separate PR in the corresponding submodule. When a
fix lands upstream, bump the submodule pointer here and remove the
entry. The template's `rte_os` runtime status moves from
"structure-only" → "link-verified for Cortex-M0+" (current, after
PR #38) → "runtime-verified on LP-MSPM0G3507" once Renode SIL +
hardware soak land.

Cross-references:
- `docs/iss-1524-debug-architecture.md` — earlier upstream concern
  about BSW debug frontend, also separate from this PR.
- `CMakeLists.txt` — search `APP_MODEL STREQUAL "rte_os"` for the
  shim wiring that supersedes the original #1 blocker.
- `src/hal_system_shim.c` — the local shim file that replaces the
  M0+-broken `hal_system.c` for rte_os builds.
