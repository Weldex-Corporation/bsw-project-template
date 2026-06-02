# Renode mspm0_timg7.py — time-based IRQ gap

Status: open. Affects SIL coverage of any firmware that relies on
TIMG7 firing periodic interrupts (rte_os, oslite, anything driven by
the Gpt MCAL system tick).

## Symptom

Running the `rte_os` firmware in Renode with the
`bsw-mcal-msp/renode/models/mspm0_timg7.py` peripheral loaded:

  - Firmware boots cleanly, reaches `Os_StartOS` (`os_running = 1`).
  - All register writes from `Gpt_Init` + `Gpt_StartTimer` land in the
    model:
      - `PWREN = 0x26000001` (powered)
      - `PWRSTAT = 1`
      - `CPS = 32`           (32 MHz BUSCLK / 32 = 1 MHz tick)
      - `IMASK = 1`          (ZERO_EVENT unmasked)
      - `CTRCTL = 3`         (`EN | REPEAT`)
      - `LOAD = 1000`        (1 ms period)
  - **`RIS` never sets** and `Os_Counter.c`'s `os_counter_ms` stays at 0
    over 500 ms of emulated time.

## Root cause (suspected)

The Python peripheral's `_schedule()` tries two paths to register a
periodic time event, both wrapped in silent `try/except`:

  1. `self.GetMachine().ScheduleAction(TimeInterval.FromMicroseconds(us),
      lambda _ts: _do_fire())`.
  2. Fallback to `Antmicro.Renode.Peripherals.Timers.LimitTimer`
     with `_do_fire` hooked into the `LimitReached` event.

The software-trigger path (write `ISET=1`) works — that's what
`test_missing_periph.robot` exercises and why this model has never
been observed broken before. But neither time-based path delivers
the IRQ from a `CTRCTL = EN|REPEAT` write.

Most likely failure mode (not yet confirmed):

  - `ScheduleAction`'s Python-lambda → .NET-Action conversion fails
    in IronPython 2.7 (used by Renode's `PythonPeripheral`), or the
    Python-side reference is GC'd before the action fires.
  - `LimitTimer.LimitReached += _do_fire` similarly loses the Python
    callable reference because each register access re-evaluates the
    script and rebinds `_do_fire` to a fresh function object — the
    delegate the timer is holding points at the *old* function whose
    closure is no longer wired to live module state.

## Workarounds

For now, the rte_os refactor PRs (#209 / #5 / #38) link cleanly and
the test SIL gap is documented (`test_rte_os_diag.robot` records the
full register snapshot). Real-silicon (LP-MSPM0G3507) and bare-metal
LimitTimer-based projects on the same chip are not affected because
TI driverlib programs the actual TIMG7 IP, which fires for real.

Three possible follow-ups, roughly in increasing effort:

  1. **Native `.repl` timer.** Add a top-level `LimitTimer` peripheral
     to `bsw-mcal-msp/renode/mspm0g3507.repl` (or a dedicated
     `rte_os.repl` overlay) and wire its `IRQ -> nvic@20`. The Python
     model continues to handle register state; the native LimitTimer
     handles IRQ generation. Cleanest from a Renode standpoint.

  2. **C# peripheral.** Rewrite `mspm0_timg7` as a proper C# peripheral
     in `Antmicro.Renode.Peripherals.MSPM0`. This is the official way
     and removes the IronPython delegate friction entirely. Heaviest.

  3. **Polling shim inside the firmware** (NOT recommended). Have the
     idle loop poll `Gpt_GetPredefTimerValue` and call
     `Os_IncrementCounter` manually. Defeats the architecture and only
     papers over the SIL issue, so this is documented only to be
     rejected.

## Related

- `renode/test_rte_os_boot.robot` — first test to surface the gap
  (the tick-advance + LED-toggle cases fail; the boot case passes).
- `renode/test_rte_os_diag.robot` — diagnostic probe that confirmed
  firmware-side correctness and pinpointed the model as the gap.
- `docs/upstream-issues.md` — Issue #1 (assembly failure) was the
  original blocker; #38 routes around it. This Renode gap is the
  remaining follow-up before SIL coverage matches real silicon.
