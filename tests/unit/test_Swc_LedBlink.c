/**
 * Unit Tests — Swc_LedBlink (host build, Unity).
 *
 * Drives the SWC via the static RTE backend (Rte_Write_Mode_Value sets the
 * shared Mode port). LED commanded state is observed through Dio_WriteChannel
 * → mock_dio_channel_level[DIO_CH_LED_GREEN].
 *
 * SWE.4 trace: each test maps to a single behaviour clause of Swc_LedBlink.
 */
#include "unity.h"
#include "Swc_LedBlink.h"
#include "Rte_LedBlink.h"
#include "Rte_ModeSelector.h"
#include "Rte_Ports.h"
#include "Dio.h"
#include "Dio_Cfg.h"

#define LED  ((Dio_ChannelType)DIO_CH_LED_GREEN)

void setUp(void)
{
    Dio_Init(NULL);
    (void)Rte_Write_Mode_Value(RTE_MODE_OFF);
    SwcLedBlink_Init();
}
void tearDown(void) {}

/* ── Tests ───────────────────────────────────────────────────── */

void test_init_drives_led_low(void)
{
    TEST_ASSERT_EQUAL(STD_LOW, mock_dio_channel_level[LED]);
}

void test_mode_off_keeps_led_low(void)
{
    (void)Rte_Write_Mode_Value(RTE_MODE_OFF);
    SwcLedBlink_Run(1000u);
    TEST_ASSERT_EQUAL(STD_LOW, mock_dio_channel_level[LED]);
}

void test_blink_500ms_no_toggle_before_period(void)
{
    (void)Rte_Write_Mode_Value(RTE_MODE_BLINK_500MS);
    SwcLedBlink_Run(499u);
    TEST_ASSERT_EQUAL(STD_LOW, mock_dio_channel_level[LED]);
}

void test_blink_500ms_toggles_on_at_period(void)
{
    (void)Rte_Write_Mode_Value(RTE_MODE_BLINK_500MS);
    SwcLedBlink_Run(500u);
    TEST_ASSERT_EQUAL(STD_HIGH, mock_dio_channel_level[LED]);
}

void test_blink_500ms_full_cycle(void)
{
    (void)Rte_Write_Mode_Value(RTE_MODE_BLINK_500MS);
    SwcLedBlink_Run(500u);  /* ON  */
    SwcLedBlink_Run(500u);  /* OFF */
    TEST_ASSERT_EQUAL(STD_LOW, mock_dio_channel_level[LED]);
}

void test_blink_100ms_period(void)
{
    (void)Rte_Write_Mode_Value(RTE_MODE_BLINK_100MS);
    SwcLedBlink_Run(99u);
    TEST_ASSERT_EQUAL(STD_LOW, mock_dio_channel_level[LED]);
    SwcLedBlink_Run(1u);
    TEST_ASSERT_EQUAL(STD_HIGH, mock_dio_channel_level[LED]);
}

void test_mode_change_resets_phase(void)
{
    /* Get partway through a 500 ms period, then switch mode. */
    (void)Rte_Write_Mode_Value(RTE_MODE_BLINK_500MS);
    SwcLedBlink_Run(400u);
    (void)Rte_Write_Mode_Value(RTE_MODE_BLINK_100MS);
    SwcLedBlink_Run(99u);
    /* Phase was reset on mode change → no toggle yet. */
    TEST_ASSERT_EQUAL(STD_LOW, mock_dio_channel_level[LED]);
    SwcLedBlink_Run(1u);
    TEST_ASSERT_EQUAL(STD_HIGH, mock_dio_channel_level[LED]);
}

/* ── Runner ──────────────────────────────────────────────────── */

int main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_init_drives_led_low);
    RUN_TEST(test_mode_off_keeps_led_low);
    RUN_TEST(test_blink_500ms_no_toggle_before_period);
    RUN_TEST(test_blink_500ms_toggles_on_at_period);
    RUN_TEST(test_blink_500ms_full_cycle);
    RUN_TEST(test_blink_100ms_period);
    RUN_TEST(test_mode_change_resets_phase);
    return UNITY_END();
}
