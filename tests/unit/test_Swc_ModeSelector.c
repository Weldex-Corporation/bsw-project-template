/**
 * Unit Tests — Swc_ModeSelector (host build, Unity).
 *
 * Button (DIO_CH_BTN_S2) is active-low. The mock initialises it HIGH
 * (pull-up, not pressed). Tests set mock_dio_channel_level[DIO_CH_BTN_S2]
 * = STD_LOW to simulate a press, STD_HIGH to release.
 *
 * Mode is observed through the static RTE backend's Rte_Read_Mode_Value.
 *
 * SWE.4 trace: each test exercises one debounce / cycle clause.
 */
#include "unity.h"
#include "Swc_ModeSelector.h"
#include "Rte_ModeSelector.h"
#include "Rte_LedBlink.h"     /* for Rte_Read_Mode_Value — test observer */
#include "Rte_Ports.h"
#include "Dio.h"
#include "Dio_Cfg.h"

#define BTN  ((Dio_ChannelType)DIO_CH_BTN_S2)

void setUp(void)
{
    Dio_Init(NULL);                  /* BTN starts HIGH (not pressed) */
    SwcModeSelector_Init();
}
void tearDown(void) {}

/* ── Helpers ─────────────────────────────────────────────────── */

static Rte_AppMode_t current_mode(void)
{
    Rte_AppMode_t m = RTE_MODE_OFF;
    (void)Rte_Read_Mode_Value(&m);
    return m;
}

static void press_for_ms(uint32_t ms)
{
    mock_dio_channel_level[BTN] = STD_LOW;
    SwcModeSelector_Run(ms);
}

static void release_for_ms(uint32_t ms)
{
    mock_dio_channel_level[BTN] = STD_HIGH;
    SwcModeSelector_Run(ms);
}

/* ── Tests ───────────────────────────────────────────────────── */

void test_initial_mode_is_off(void)
{
    TEST_ASSERT_EQUAL(RTE_MODE_OFF, current_mode());
}

void test_short_press_does_not_advance(void)
{
    press_for_ms(19u);              /* 1 ms under DEBOUNCE_MS=20 */
    TEST_ASSERT_EQUAL(RTE_MODE_OFF, current_mode());
}

void test_press_at_debounce_advances_to_100ms(void)
{
    press_for_ms(20u);
    TEST_ASSERT_EQUAL(RTE_MODE_BLINK_100MS, current_mode());
}

void test_holding_does_not_advance_twice(void)
{
    press_for_ms(20u);              /* → BLINK_100MS */
    press_for_ms(100u);             /* still held — must NOT advance */
    TEST_ASSERT_EQUAL(RTE_MODE_BLINK_100MS, current_mode());
}

void test_release_then_press_advances_to_500ms(void)
{
    press_for_ms(20u);              /* → BLINK_100MS */
    release_for_ms(5u);             /* re-arm */
    press_for_ms(20u);              /* → BLINK_500MS */
    TEST_ASSERT_EQUAL(RTE_MODE_BLINK_500MS, current_mode());
}

void test_third_press_wraps_to_off(void)
{
    press_for_ms(20u);
    release_for_ms(5u);
    press_for_ms(20u);
    release_for_ms(5u);
    press_for_ms(20u);              /* OFF → 100 → 500 → OFF */
    TEST_ASSERT_EQUAL(RTE_MODE_OFF, current_mode());
}

/* ── Runner ──────────────────────────────────────────────────── */

int main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_initial_mode_is_off);
    RUN_TEST(test_short_press_does_not_advance);
    RUN_TEST(test_press_at_debounce_advances_to_100ms);
    RUN_TEST(test_holding_does_not_advance_twice);
    RUN_TEST(test_release_then_press_advances_to_500ms);
    RUN_TEST(test_third_press_wraps_to_off);
    return UNITY_END();
}
