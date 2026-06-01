# MSPM0G3507 UART model for Renode SIL
#
# Covers UART0 (0x40108000) and UART1 (0x40100000) -- same register map.
#
# Register offsets (from peripheral base):
#   0x0800  GPRCM block  (power/reset -- reads return 0, writes ignored)
#   0x1100  CTL0         RW  control
#   0x1104  LCRH         RW  line control
#   0x1108  STAT         RO  status -- always 0x44 (TXFE|RXFE, not busy)
#   0x1110  IBRD         RW  integer baud divisor
#   0x1114  FBRD         RW  fractional baud divisor
#   0x1118  IFLS         RW  FIFO threshold
#   0x1120  TXDATA       WO  transmit byte -> captured in tx_buf
#   0x1124  RXDATA       RO  receive byte <- drained from rx_buf
#
# STAT bits:
#   [0] BUSY  0 = idle
#   [2] RXFE  1 = RX FIFO empty
#   [6] TXFE  1 = TX FIFO empty
#
# TX capture register (test hook):
#   0x1FFC  TXBUF_LEN    RO  number of bytes in tx_buf
#   0x1FF8  TXBUF_DRAIN  RO  read one byte from tx_buf (0 if empty)
#   0x1FF4  TXBUF_CLEAR  WO  any write clears tx_buf
#
# RX inject register (test hook):
#   0x1FF0  RXBUF_PUSH   WO  write one byte into rx_buf

STAT_IDLE = 0x44  # TXFE(bit6) | RXFE(bit2)

if "regs" not in dir():
    regs = {}

if "tx_buf" not in dir():
    tx_buf = []

if "rx_buf" not in dir():
    rx_buf = []

if request.isInit:
    regs.clear()
    del tx_buf[:]
    del rx_buf[:]

elif request.isRead:
    o = request.Offset
    if o == 0x1020:                      # CPU_INT.IIDX -- EOT_DONE after DMA TX
        request.Value = 0x0D
    elif o == 0x1108:                    # STAT -- always idle
        request.Value = STAT_IDLE
    elif o == 0x1124:                    # RXDATA
        request.Value = rx_buf.pop(0) if rx_buf else 0
    elif o == 0x1FFC:                    # TXBUF_LEN (test hook)
        request.Value = len(tx_buf)
    elif o == 0x1FF8:                    # TXBUF_DRAIN (test hook)
        request.Value = tx_buf.pop(0) if tx_buf else 0
    else:
        request.Value = regs.get(o, 0)

elif request.isWrite:
    o = request.Offset
    v = request.Value
    if o == 0x1120:                      # TXDATA -- capture byte
        tx_buf.append(v & 0xFF)
    elif o == 0x1FF4:                    # TXBUF_CLEAR (test hook)
        del tx_buf[:]
    elif o == 0x1FF0:                    # RXBUF_PUSH (test hook)
        rx_buf.append(v & 0xFF)
    else:
        regs[o] = v
