/*
 * Renode SIL test firmware: TIMG0 / TIMG6 / TIMG12 IRQ model verification.
 *
 * Tests ISET software-trigger and ICLR clear on three TimerG instances
 * that were previously missing IRQ-capable Renode models.
 *
 * Result slots written to fixed SRAM addresses (read back by Robot):
 *   0x20206000  timg0_ris      (RIS after ISET: want 1)
 *   0x20206004  timg0_ris_clr  (RIS after ICLR: want 0)
 *   0x20206008  timg6_ris      (RIS after ISET: want 1)
 *   0x2020600C  timg6_ris_clr  (RIS after ICLR: want 0)
 *   0x20206010  timg12_ris     (RIS after ISET: want 1)
 *   0x20206014  timg12_ris_clr (RIS after ICLR: want 0)
 *   0x20206018  adc1_result    (readback of pre-loaded ADC1 MEMRES[0])
 */

#include <stdint.h>

/* Result-slot helpers */
#define RES_BASE  0x20206000u
#define RES32(i)  (*((volatile uint32_t *)(RES_BASE + (i) * 4u)))

/* Generic GPTIMER register offsets */
#define TIMG_ISET  0x1040u
#define TIMG_ICLR  0x1048u
#define TIMG_RIS   0x1030u

/* Peripheral base addresses */
#define TIMG0_BASE   0x40084000u
#define TIMG6_BASE   0x40868000u
#define TIMG12_BASE  0x40870000u
#define ADC1_BASE    0x40002000u

#define REG32(base, off)  (*((volatile uint32_t *)((base) + (off))))

/* ADC1 PERIPHERALREGIONSVT base (ADC1_BASE + 0x556000) and MEMRES[0] at +0x280 */
#define ADC1_SVT_MEMRES0  0x40558280u

static void test_timg(uint32_t base, uint32_t slot_ris, uint32_t slot_clr)
{
    /* Software-trigger ZERO_EVENT via ISET bit0 */
    REG32(base, TIMG_ISET) = 0x1u;
    RES32(slot_ris) = REG32(base, TIMG_RIS) & 0x1u;

    /* Clear via ICLR bit0 */
    REG32(base, TIMG_ICLR) = 0x1u;
    RES32(slot_clr) = REG32(base, TIMG_RIS) & 0x1u;
}

int main(void)
{
    /* TIMG0 — IRQ 16 */
    test_timg(TIMG0_BASE,  0u, 1u);

    /* TIMG6 — IRQ 17 */
    test_timg(TIMG6_BASE,  2u, 3u);

    /* TIMG12 — IRQ 21 */
    test_timg(TIMG12_BASE, 4u, 5u);

    /* ADC1: read MEMRES[0] from SVT alias (ADC1_PERIPHERALREGIONSVT + 0x280) */
    RES32(6u) = *((volatile uint32_t *)ADC1_SVT_MEMRES0);

    for (;;) {}
}
