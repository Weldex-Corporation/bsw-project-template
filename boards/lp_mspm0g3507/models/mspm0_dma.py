# MSPM0G3507 DMA model for Renode SIL
#
# DMA base: 0x4042A000, size: 0x1400
#
# Register layout (offsets from base):
#   0x1100          DMAPRIO           RW  channel priority
#   0x1110 + ch*4   DMATCTL[ch]       RW  trigger select  (ch 0-15)
#   0x1200 + ch*16  DMACTL[ch]  +0x0  RW  control (DMAEN = bit 1)
#                               +0x4  RW  DMASA  source address
#                               +0x8  RW  DMADA  destination address
#                               +0xC  RW  DMASZ  transfer size (lower 16 bits)
#
# SIL behaviour on DMAEN rising edge:
#   1. Copy DMASZ bytes from sysbus[DMASA] -> sysbus[DMADA]
#   2. Clear DMASZ and DMAEN (transfer complete)
#   3. Fire UART TX IRQ determined by DMADA range:
#        UART1 [0x40100000, 0x40102000) -> IRQ 13
#        UART0 [0x40108000, 0x4010A000) -> IRQ 15

DMAEN_BIT = 0x2

UART_IRQ_MAP = [
    (0x40100000, 0x40102000, 13),
    (0x40108000, 0x4010A000, 15),
]

if "regs" not in dir():
    regs = {}

if "nvic_ref" not in dir():
    nvic_ref = [None]

def get_nvic():
    if nvic_ref[0] is None:
        try:
            nvic_ref[0] = self.GetMachine()["sysbus.nvic"]
        except:
            pass
    return nvic_ref[0]

def irq_for_addr(addr):
    for lo, hi, irq in UART_IRQ_MAP:
        if lo <= addr < hi:
            return irq
    return None

def do_transfer(ch):
    ctl_off = 0x1200 + ch * 0x10
    src  = regs.get(ctl_off + 0x4, 0)
    dst  = regs.get(ctl_off + 0x8, 0)
    size = regs.get(ctl_off + 0xC, 0) & 0xFFFF
    if size == 0:
        return
    try:
        bus = self.GetMachine().SystemBus
        for i in range(size):
            bus.WriteByte(dst + i, bus.ReadByte(src + i))
    except:
        pass
    regs[ctl_off + 0xC] = 0
    regs[ctl_off]       = regs.get(ctl_off, 0) & ~DMAEN_BIT
    irq = irq_for_addr(dst)
    if irq is not None:
        nvic = get_nvic()
        if nvic is not None:
            try:
                nvic.SetPendingIRQ(irq)
            except:
                pass

if request.isInit:
    regs.clear()

elif request.isRead:
    request.Value = regs.get(request.Offset, 0)

elif request.isWrite:
    o = request.Offset
    v = request.Value
    old = regs.get(o, 0)
    regs[o] = v
    # DMACTL register: detect DMAEN rising edge
    if 0x1200 <= o < 0x1300 and (o & 0xF) == 0x0:
        if (v & DMAEN_BIT) and not (old & DMAEN_BIT):
            do_transfer((o - 0x1200) // 0x10)
