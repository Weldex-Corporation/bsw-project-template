# Renode mspm0_timg7.py — time-based IRQ gap

Status: **RESOLVED** in bsw-mcal-msp@76224df. This document is kept as
a debugging postmortem.

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

## Fix (landed)

bsw-mcal-msp@76224df, `renode/models/mspm0_timg7.py`. Two corrections
were needed for the LimitTimer + delegate to actually run:

  1. **Constructor flags, not property setters.** Setting `Enabled =
     True` and `AutoUpdate = True` AFTER construction left the timer
     disarmed. Passing `enabled=True` and `WorkMode.Periodic` as
     constructor arguments fixes it.

  2. **Strong reference to the delegate.** `timer.LimitReached += _do_fire`
     wraps the Python callable into a delegate; if the script's
     locals go out of scope the delegate is GC'd while the timer
     still holds it. Storing the wrapped `System.Action(_do_fire)`
     in module-level state keeps the reference alive.

A third, smaller fix in the same commit: NVIC pulse goes through
`OnGPIO(True)/OnGPIO(False)` instead of `SetPendingIRQ(...)`. Only the
former actually delivers the IRQ to the CPU from a Python callback
under the IronPython runtime Renode embeds.

After the fix, the diagnostic in `test_rte_os_diag.robot` shows
`dbg_sched = 200`, `dbg_arm = 200`, `dbg_fire = 199` over 200 ms of
emulation, and the rte_os boot test's `os_counter_ms` advances on
pure virtual time -- no manual IRQ injection from Robot needed.

## Related

- `renode/test_rte_os_boot.robot` — first test to surface the gap
  (the tick-advance + LED-toggle cases fail; the boot case passes).
- `renode/test_rte_os_diag.robot` — diagnostic probe that confirmed
  firmware-side correctness and pinpointed the model as the gap.
- `docs/upstream-issues.md` — Issue #1 (assembly failure) was the
  original blocker; #38 routes around it. This Renode gap is the
  remaining follow-up before SIL coverage matches real silicon.
