/* MSPM0G3507 comprehensive peripheral SIL test — raw register access.
 * Exercises all 15 new Renode Python peripheral models in sequence.
 * No driverlib calls; direct MMIO writes let each model respond.
 * Robot reads result registers after emulation RunFor completes.
 */
#include <stdint.h>

#define REG32(a)     (*((volatile uint32_t *)(uint32_t)(a)))
#define PWREN(b)     REG32((b) + 0x800u) = 0x26000001u
#define RSTCTL(b)    REG32((b) + 0x804u) = 0xB1000001u

/* Peripheral base addresses (MSPM0G350x) */
#define CRC_BASE      0x40440000u
#define TRNG_BASE     0x40444000u
#define DAC0_BASE     0x40018000u
#define VREF_BASE     0x40030000u
#define COMP0_BASE    0x40008000u
#define OPA0_BASE     0x40020000u
#define MATHACL_BASE  0x40410000u
#define WUC_BASE      0x40424000u
#define SPI0_BASE     0x40468000u
#define I2C0_BASE     0x400F0000u
#define RTC_BASE      0x40094000u
#define FLASHCTL_BASE 0x400CD000u
#define AES_BASE      0x40442000u
#define TIMA0_BASE    0x40860000u
#define CANFD0_BASE   0x40508000u

int main(void)
{
    /* ── CRC (0x40440000) ──────────────────────────────────────────────────
     * Write SEED=0 then CRCIN=0x01234567.
     * Robot reads CRCOUT (0x40441808+offset 0x110C) and expects 0x190EC766.
     */
    PWREN(CRC_BASE);
    RSTCTL(CRC_BASE);
    REG32(CRC_BASE + 0x1104u) = 0u;           /* SEED = 0                  */
    REG32(CRC_BASE + 0x1108u) = 0x01234567u;  /* CRCIN → advances CRC-32   */

    /* ── TRNG (0x40444000) ─────────────────────────────────────────────────
     * Enable, then let robot read DATA_CAPTURE (non-zero LFSR value).
     */
    PWREN(TRNG_BASE);
    RSTCTL(TRNG_BASE);
    REG32(TRNG_BASE + 0x1100u) = 1u;          /* CTL.ENABLE                */

    /* ── DAC0 (0x40018000) ─────────────────────────────────────────────────
     * Write DATA0=0xABC; robot reads it back.
     */
    PWREN(DAC0_BASE);
    RSTCTL(DAC0_BASE);
    REG32(DAC0_BASE + 0x1100u) = 1u;          /* CTL0.ENABLE               */
    REG32(DAC0_BASE + 0x1200u) = 0xABCu;      /* DATA0                     */

    /* ── VREF (0x40030000) ─────────────────────────────────────────────────
     * Enable → CTL1.READY must become 1 (spin-wait tests model behaviour).
     */
    PWREN(VREF_BASE);
    RSTCTL(VREF_BASE);
    REG32(VREF_BASE + 0x1100u) = 1u;          /* CTL0.ENABLE               */
    while (!(REG32(VREF_BASE + 0x1104u) & 1u));  /* wait CTL1.READY        */

    /* ── COMP0 (0x40008000) ────────────────────────────────────────────────
     * Enable; STAT.OUT defaults to 0 (no injected output).
     */
    PWREN(COMP0_BASE);
    RSTCTL(COMP0_BASE);
    REG32(COMP0_BASE + 0x1104u) = 1u;         /* CTL1.ENABLE               */

    /* ── OPA0 (0x40020000) ─────────────────────────────────────────────────
     * Enable → STAT.RDY must become 1.
     */
    PWREN(OPA0_BASE);
    RSTCTL(OPA0_BASE);
    REG32(OPA0_BASE + 0x1100u) = 1u;          /* CTL.ENABLE                */
    while (!(REG32(OPA0_BASE + 0x1118u) & 1u));  /* wait STAT.RDY          */

    /* ── MATHACL (0x40410000) ──────────────────────────────────────────────
     * MPY32 mode: OP2=6, OP1=5 → RES1 must read 30 (5×6).
     */
    PWREN(MATHACL_BASE);
    RSTCTL(MATHACL_BASE);
    REG32(MATHACL_BASE + 0x1100u) = 0u;       /* CTL: MPY32 mode           */
    REG32(MATHACL_BASE + 0x1118u) = 6u;       /* OP2                       */
    REG32(MATHACL_BASE + 0x111Cu) = 5u;       /* OP1 — write triggers 5×6  */

    /* ── WUC (0x40424000) ──────────────────────────────────────────────────
     * Event subscriber register store/read-back test.
     */
    PWREN(WUC_BASE);
    RSTCTL(WUC_BASE);
    REG32(WUC_BASE + 0x400u) = 0x55u;         /* FSUB_0                    */

    /* ── SPI0 (0x40468000) ─────────────────────────────────────────────────
     * TX→RX loopback: write 0xA5 to TXDATA; robot reads RXDATA.
     */
    PWREN(SPI0_BASE);
    RSTCTL(SPI0_BASE);
    REG32(SPI0_BASE + 0x1104u) = 1u;          /* CTL1.ENABLE               */
    REG32(SPI0_BASE + 0x1140u) = 0xA5u;       /* TXDATA → pushed to RX FIFO*/

    /* ── I2C0 (0x400F0000) ─────────────────────────────────────────────────
     * Master write to addr 0x50: write MTXDATA then MCTR START+STOP.
     * Spin-wait on MTXDONE (RIS bit1) before continuing.
     */
    PWREN(I2C0_BASE);
    RSTCTL(I2C0_BASE);
    REG32(I2C0_BASE + 0x1210u) = 0xA0u;       /* MSA: addr 0x50 << 1, W=0  */
    REG32(I2C0_BASE + 0x1220u) = 0x42u;       /* MTXDATA                   */
    REG32(I2C0_BASE + 0x1214u) = 0x6u;        /* MCTR: START(1) | STOP(2)  */
    while (!(REG32(I2C0_BASE + 0x1030u) & 0x2u)); /* wait MTXDONE(bit1)    */

    /* ── RTC (0x40094000) ──────────────────────────────────────────────────
     * After reset model restores YEAR=0x2026; robot reads YEAR and STA.RTCRDY.
     */
    PWREN(RTC_BASE);
    RSTCTL(RTC_BASE);

    /* ── FLASHCTL (0x400CD000) ─────────────────────────────────────────────
     * Program command: set CMDTYPE=PROGRAM, write CMDDATA0, execute.
     * Spin-wait on STATCMD.CMDDONE (bit0).
     */
    PWREN(FLASHCTL_BASE);
    RSTCTL(FLASHCTL_BASE);
    REG32(FLASHCTL_BASE + 0x1104u) = 1u;      /* CMDTYPE=PROGRAM           */
    REG32(FLASHCTL_BASE + 0x1120u) = 0u;      /* CMDADDR=0x0               */
    REG32(FLASHCTL_BASE + 0x1130u) = 0xDEADBEEFu; /* CMDDATA0              */
    REG32(FLASHCTL_BASE + 0x1100u) = 1u;      /* CMDEXEC=1 → instant done  */
    while (!(REG32(FLASHCTL_BASE + 0x13D0u) & 1u)); /* wait CMDDONE        */

    /* ── AES (0x40442000) ──────────────────────────────────────────────────
     * AES-128 ECB encrypt with null key.
     * Key: 4×0x00000000; Plaintext: 0x01020304 0x05060708 0x090A0B0C 0x0D0E0F10
     * Model: out[i] = in[i] XOR key[i] → out[0]=0x01020304.
     */
    PWREN(AES_BASE);
    RSTCTL(AES_BASE);
    REG32(AES_BASE + 0x1100u) = 0u;           /* AESACTL0: encrypt AES-128 */
    REG32(AES_BASE + 0x110Cu) = 0u;           /* AESAKEY word 0            */
    REG32(AES_BASE + 0x110Cu) = 0u;           /* AESAKEY word 1            */
    REG32(AES_BASE + 0x110Cu) = 0u;           /* AESAKEY word 2            */
    REG32(AES_BASE + 0x110Cu) = 0u;           /* AESAKEY word 3            */
    REG32(AES_BASE + 0x1110u) = 0x01020304u;  /* AESADIN word 0            */
    REG32(AES_BASE + 0x1110u) = 0x05060708u;  /* AESADIN word 1            */
    REG32(AES_BASE + 0x1110u) = 0x090A0B0Cu;  /* AESADIN word 2            */
    REG32(AES_BASE + 0x1110u) = 0x0D0E0F10u;  /* AESADIN word 3 → triggers */
    while (!(REG32(AES_BASE + 0x1030u) & 1u)); /* wait AESRDY              */

    /* ── TIMA0 (0x40860000) ────────────────────────────────────────────────
     * Set LOAD=1999, CC0=999 (50% duty), DBCTL=10 (dead-band cycles).
     * TIMA model returns STAT.PWRACT(bit0); skip spin-wait on RESETSTKY.
     */
    PWREN(TIMA0_BASE);
    RSTCTL(TIMA0_BASE);
    PWREN(TIMA0_BASE);                        /* re-assert PWREN after reset*/
    REG32(TIMA0_BASE + 0x1808u) = 1999u;      /* LOAD                      */
    REG32(TIMA0_BASE + 0x1810u) = 999u;       /* CC_01[0]                  */
    REG32(TIMA0_BASE + 0x18A4u) = 10u;        /* DBCTL: 10 dead-band cycles */

    /* ── CANFD0 (0x40508000) ───────────────────────────────────────────────
     * Enable clock, init MCAN, request TX buffer 0.
     * Robot reads TXBTO bit0=1 (instant TX complete in model).
     */
    REG32(CANFD0_BASE + 0x7900u) = 1u;        /* MCANSS_CLKEN: enable      */
    REG32(CANFD0_BASE + 0x7018u) = 3u;        /* CCCR: INIT=1, CCE=1       */
    REG32(CANFD0_BASE + 0x701Cu) = 0x00001A03u; /* NBTP: nominal bitrate   */
    REG32(CANFD0_BASE + 0x70C0u) = 0x04000004u; /* TXBC: 4 dedicated bufs  */
    REG32(CANFD0_BASE + 0x7018u) = 0u;        /* CCCR: clear INIT → run    */
    REG32(CANFD0_BASE + 0x70D0u) = 1u;        /* TXBAR: request buffer 0   */

    while (1) {
        __asm__ volatile ("wfi");
    }
    return 0;
}
