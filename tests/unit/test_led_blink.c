/**
 * Unit Tests — LedBlink module
 * Framework: Unity
 * Build: cmake --preset host-test && ctest --preset host-test
 */

#include "unity.h"
#include "led_blink.h"

/* Unity required callbacks */
void setUp(void)    { LedBlink_Init(); }
void tearDown(void) {}

/* ── Unit Tests ──────────────────────────────────────────────── */

void test_initial_state_is_off(void)
{
    TEST_ASSERT_EQUAL(LED_BLINK_STATE_OFF, LedBlink_GetState());
}

void test_no_toggle_before_period(void)
{
    LedBlink_Tick(499u);
    TEST_ASSERT_EQUAL(LED_BLINK_STATE_OFF, LedBlink_GetState());
}

void test_toggles_on_at_500ms(void)
{
    LedBlink_Tick(500u);
    TEST_ASSERT_EQUAL(LED_BLINK_STATE_ON, LedBlink_GetState());
}

void test_toggles_off_at_1000ms(void)
{
    LedBlink_Tick(500u);
    LedBlink_Tick(500u);
    TEST_ASSERT_EQUAL(LED_BLINK_STATE_OFF, LedBlink_GetState());
}

void test_multiple_periods(void)
{
    for (int i = 0; i < 6; i++)
    {
        LedBlink_Tick(500u);
    }
    /* 6 toggles from OFF → ON → OFF → ON → OFF → ON → OFF */
    TEST_ASSERT_EQUAL(LED_BLINK_STATE_OFF, LedBlink_GetState());
}

void test_small_tick_accumulation(void)
{
    /* 50 × 10ms = 500ms → should toggle */
    for (int i = 0; i < 50; i++)
    {
        LedBlink_Tick(10u);
    }
    TEST_ASSERT_EQUAL(LED_BLINK_STATE_ON, LedBlink_GetState());
}

void test_reinit_resets_state(void)
{
    LedBlink_Tick(500u);
    TEST_ASSERT_EQUAL(LED_BLINK_STATE_ON, LedBlink_GetState());
    LedBlink_Init();
    TEST_ASSERT_EQUAL(LED_BLINK_STATE_OFF, LedBlink_GetState());
}

/* ── Main ──────────────────────────────────────────────────────── */

int main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_initial_state_is_off);
    RUN_TEST(test_no_toggle_before_period);
    RUN_TEST(test_toggles_on_at_500ms);
    RUN_TEST(test_toggles_off_at_1000ms);
    RUN_TEST(test_multiple_periods);
    RUN_TEST(test_small_tick_accumulation);
    RUN_TEST(test_reinit_resets_state);
    return UNITY_END();
}
