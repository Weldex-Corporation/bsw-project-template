# MSPM0G3507 WWDT model for Renode SIL
#
# Covers WWDT0 (0x40080000) and WWDT1 (0x40082000) -- same register map.
# Size: 0x1200 (covers WWDTCNTRST @ 0x1108)
#
# SIL contract: never trigger a watchdog reset.
# The WWDT starts enabled after HW reset; in SIL we simply absorb all
# service/config writes and always report a clean status.
#
# Register offsets:
#   0x0800  GPRCM.PWREN  RW  power enable (KEY unlock + ENABLE bit)
#   0x0804  GPRCM.RSTCTL WO  reset control
#   0x0814  GPRCM.STAT   RO  -> 0 (not reset)
#   0x1100  WWDTCTL0     RW  control 0 (KEY + period/window config)
#   0x1104  WWDTCTL1     RW  control 1 (KEY + sleep/debug config)
#   0x1108  WWDTCNTRST   WO  counter reset (KEY + 0x1 to service watchdog)
#   0x110C  WWDTSTAT     RO  -> 0 (no fault, no interrupt)

if "regs" not in dir():
    regs = {}

if request.isInit:
    regs.clear()

elif request.isRead:
    request.Value = regs.get(request.Offset, 0)

elif request.isWrite:
    regs[request.Offset] = request.Value
