# MSPM0G3507 TIMG7 model for Renode SIL  (IRQ 20)
#
# TIMG7 base: 0x4086A000, size: 0x2000
#
# Register offsets:
#   0x1000  CLKDIV       RW  clock divider (bits[2:0]+1 = ratio)
#   0x1008  CLKSEL       RW  clock source select
#   0x110C  CPS          RW  prescaler divisor (CPS=32 -> 32MHz/32=1MHz)
#   0x1020  CPU_INT.IIDX RO  interrupt index: 0x01=ZERO_EVENT (read clears)
#   0x1028  CPU_INT.IMASK RW interrupt mask
#   0x1030  CPU_INT.RIS  RO  raw interrupt status
#   0x1048  CPU_INT.ICLR WO  interrupt clear
#   0x1800  CTR          RO  counter (always 0 in SIL)
#   0x1804  CTRCTL       RW  control -- EN (bit0) starts/stops LimitTimer
#   0x1808  LOAD         RW  reload value (period in ticks)
#
# SIL behaviour:
#   CTRCTL EN rising edge -> LimitTimer at BUSCLK/(CPS*LOAD) Hz
#   -> fires NVIC IRQ 20 with IIDX=ZERO_EVENT each period

TIMER_IRQ   = 20
BUSCLK_HZ   = 32000000
EN_BIT      = 0x1
ZERO_EVENT  = 0x01

if "regs" not in dir():
    regs = {}
if "lt_ref" not in dir():
    lt_ref = [None]
if "pending" not in dir():
    pending = [False]
if "nvic_ref" not in dir():
    nvic_ref = [None]

def get_nvic():
    if nvic_ref[0] is None:
        try:
            nvic_ref[0] = self.GetMachine()["sysbus.nvic"]
        except:
            pass
    return nvic_ref[0]

def on_zero():
    pending[0] = True
    nvic = get_nvic()
    if nvic is not None:
        try:
            nvic.SetPendingIRQ(TIMER_IRQ)
        except:
            pass

def stop_lt():
    if lt_ref[0] is not None:
        try:
            lt_ref[0].Enabled = False
        except:
            pass

def start_lt():
    load = regs.get(0x1808, 0) & 0xFFFF
    cps  = max(1, regs.get(0x110C, 0) & 0xFF)
    if load == 0:
        return
    irq_hz = max(1, BUSCLK_HZ // (cps * load))
    try:
        stop_lt()
        import clr
        clr.AddReference("Renode")
        from Antmicro.Renode.Peripherals.Timers import LimitTimer
        machine = self.GetMachine()
        lt = LimitTimer(machine.ClockSource, long(irq_hz), self, "timg7_lt")
        lt.Limit = long(1)
        lt.AutoUpdate = True
        lt.EventEnabled = True
        lt.LimitReached += on_zero
        lt_ref[0] = lt
        lt.Enabled = True
    except:
        pass

if request.isInit:
    regs.clear()
    pending[0] = False
    stop_lt()

elif request.isRead:
    o = request.Offset
    if o == 0x1020:       # CPU_INT.IIDX -- read clears pending
        request.Value = ZERO_EVENT if pending[0] else 0x00
        pending[0] = False
    elif o == 0x1030:     # CPU_INT.RIS
        request.Value = ZERO_EVENT if pending[0] else 0x00
    elif o == 0x1800:     # CTR -- always 0 in SIL
        request.Value = 0
    else:
        request.Value = regs.get(o, 0)

elif request.isWrite:
    o = request.Offset
    v = request.Value
    old = regs.get(o, 0)
    regs[o] = v
    if o == 0x1048:       # ICLR -- clear pending
        pending[0] = False
    elif o == 0x1804:     # CTRCTL -- EN edge detection
        if (v & EN_BIT) and not (old & EN_BIT):
            start_lt()
        elif not (v & EN_BIT):
            stop_lt()
