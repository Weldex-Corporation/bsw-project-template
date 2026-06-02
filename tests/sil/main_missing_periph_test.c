/* MSPM0G3507 missing peripheral SIL test — raw MMIO.
 * Tests: UART0 TX/RX, DMA ch0 memory copy, WWDT0, TIMG7, TIMG8.
 * Results stored at fixed SRAM addresses readable by robot via sysbus.
 */
#include <stdint.h>

#define REG32(a)     (*((volatile uint32_t *)(uint32_t)(a)))
#define PWREN(b)     REG32((b) + 0x800u) = 0x26000001u
#define RSTCTL(b)    REG32((b) + 0x804u) = 0xB1000001u

#define UART0_BASE   0x40108000u
#define DMA_BASE     0x4042A000u
#define WWDT0_BASE   0x40080000u
#define TIMG7_BASE   0x4086A000u
#define TIMG8_BASE   0x40090000u

/* Test result slots in SRAM (address known to robot) */
#define RES_BASE     0x20204000u
#define RES32(i)     (*((volatile uint32_t *)(RES_BASE + (i) * 4u)))
/* index: 0=uart_rx  1=wwdt_stat  2=timg7_ris  3=timg7_clr
 *        4=timg8_ris  5=timg8_clr                           */

/* DMA memory-copy source and destination in SRAM */
#define DMA_SRC      0x20205000u
#define DMA_DST      0x20205100u

int main(void)
{
    uint32_t i;
    for (i = 0; i < 6u; i++) RES32(i) = 0u;  /* clear result slots       */

    /* ── UART0 (0x40108000) ───────────────────────────────────────────
     * Robot pre-injects 0x5A into RXBUF via RXBUF_PUSH hook
     * (0x40109FF0) after PyDevFromFile and before LoadELF.
     * Write 'A','B','C' to TXDATA; read RXDATA → result[0].
     * STAT (offset 0x1108) always returns 0x44 (TFE|RFE = idle).
     */
    PWREN(UART0_BASE);
    REG32(UART0_BASE + 0x1100u) = 1u;          /* CTL0: ENABLE              */
    REG32(UART0_BASE + 0x1120u) = (uint32_t)'A'; /* TXDATA byte 0           */
    REG32(UART0_BASE + 0x1120u) = (uint32_t)'B'; /* TXDATA byte 1           */
    REG32(UART0_BASE + 0x1120u) = (uint32_t)'C'; /* TXDATA byte 2           */
    RES32(0) = REG32(UART0_BASE + 0x1124u);    /* RXDATA → result[0]        */

    /* ── DMA ch0 (0x4042A000) ─────────────────────────────────────────
     * Write source word to SRAM; set up ch0; enable → triggers copy.
     * Model clears DMASZ and DMAEN bit on completion.
     */
    REG32(DMA_SRC)             = 0xCAFEBABEu;  /* source data               */
    REG32(DMA_BASE + 0x1204u)  = DMA_SRC;      /* DMASA ch0                 */
    REG32(DMA_BASE + 0x1208u)  = DMA_DST;      /* DMADA ch0                 */
    REG32(DMA_BASE + 0x120Cu)  = 4u;           /* DMASZ ch0 = 4 bytes       */
    REG32(DMA_BASE + 0x1200u)  = 0x2u;         /* DMACTL ch0: DMAEN → fires */
    /* DMA_DST now contains 0xCAFEBABE; DMASZ and DMAEN cleared by model    */

    /* ── WWDT0 (0x40080000) ───────────────────────────────────────────
     * Write config + service; WWDTSTAT must read 0 (no fault).
     */
    PWREN(WWDT0_BASE);
    REG32(WWDT0_BASE + 0x1100u) = 0xA9996420u; /* WWDTCTL0: KEY + config    */
    REG32(WWDT0_BASE + 0x1108u) = 0x3B000001u; /* WWDTCNTRST: KEY + service */
    RES32(1) = REG32(WWDT0_BASE + 0x110Cu);    /* WWDTSTAT → result[1]      */

    /* ── TIMG7 (0x4086A000, IRQ 20) ───────────────────────────────────
     * Software trigger via ISET; RIS must be 1; ICLR clears to 0.
     */
    PWREN(TIMG7_BASE);
    REG32(TIMG7_BASE + 0x110Cu) = 32u;         /* CPS = 32 → 1 MHz tick    */
    REG32(TIMG7_BASE + 0x1808u) = 100u;        /* LOAD = 100 ticks          */
    REG32(TIMG7_BASE + 0x1028u) = 0x1u;        /* IMASK: ZERO_EVENT enable  */
    REG32(TIMG7_BASE + 0x1040u) = 0x1u;        /* ISET: software trigger    */
    RES32(2) = REG32(TIMG7_BASE + 0x1030u);    /* RIS → result[2] (want 1)  */
    REG32(TIMG7_BASE + 0x1048u) = 0x1u;        /* ICLR                      */
    RES32(3) = REG32(TIMG7_BASE + 0x1030u);    /* RIS → result[3] (want 0)  */

    /* ── TIMG8 (0x40090000, IRQ 2) ────────────────────────────────────
     * Same pattern as TIMG7; different base address and IRQ number.
     */
    PWREN(TIMG8_BASE);
    REG32(TIMG8_BASE + 0x110Cu) = 32u;         /* CPS = 32                  */
    REG32(TIMG8_BASE + 0x1808u) = 500u;        /* LOAD = 500 ticks          */
    REG32(TIMG8_BASE + 0x1028u) = 0x1u;        /* IMASK: ZERO_EVENT enable  */
    REG32(TIMG8_BASE + 0x1040u) = 0x1u;        /* ISET: software trigger    */
    RES32(4) = REG32(TIMG8_BASE + 0x1030u);    /* RIS → result[4] (want 1)  */
    REG32(TIMG8_BASE + 0x1048u) = 0x1u;        /* ICLR                      */
    RES32(5) = REG32(TIMG8_BASE + 0x1030u);    /* RIS → result[5] (want 0)  */

    while (1) {
        __asm__ volatile ("wfi");
    }
    return 0;
}
