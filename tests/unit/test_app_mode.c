/**
 * Unit Tests — AppMode module (button mode cycling)
 * Framework: Unity
 * Build: cmake --preset host-test && ctest --preset host-test
 *
 * Button (channel 14) is active-low. Mock initialises it HIGH (not pressed).
 * Tests set mock_dio_channel_level[14] = STD_LOW to simulate a press.
 */

#include "unity.h"
#include "app_mode.h"
#include "Dio.h"
#include "Std_Types.h"

#define BTN  14u

void setUp(void)
{
    Dio_Init(NULL);     /* resets all channels; sets BTN HIGH (not pressed) */
    AppMode_Init();
}
void tearDown(void) {}

/* ── Helpers ─────────────────────────────────────────────────── */

static void press_button_ms(uint32_t ms)
{
    mock_dio_channel_level[BTN] = STD_LOW;
    AppMode_Tick(ms);
}

static void release_button_ms(uint32_t ms)
{
    mock_dio_channel_level[BTN] = STD_HIGH;
    AppMode_Tick(ms);
}

/* ── Tests ───────────────────────────────────────────────────── */

void test_initial_mode_is_off(void)
{
    TEST_ASSERT_EQUAL(APP_MODE_OFF, AppMode_Get());
}

void test_short_press_below_debounce_does_not_advance(void)
{
    press_button_ms(10u);   /* below 20 ms debounce */
    TEST_ASSERT_EQUAL(APP_MODE_OFF, AppMode_Get());
}

void test_press_at_debounce_advances_to_blink100(void)
{
    press_button_ms(20u);
    TEST_ASSERT_EQUAL(APP_MODE_BLINK_100MS, AppMode_Get());
}

void test_second_press_advances_to_blink500(void)
{
    press_button_ms(20u);
    release_button_ms(10u);
    press_button_ms(20u);
    TEST_ASSERT_EQUAL(APP_MODE_BLINK_500MS, AppMode_Get());
}

void test_third_press_wraps_back_to_off(void)
{
    press_button_ms(20u);
    release_button_ms(10u);
    press_button_ms(20u);
    release_button_ms(10u);
    press_button_ms(20u);
    TEST_ASSERT_EQUAL(APP_MODE_OFF, AppMode_Get());
}

void test_hold_does_not_advance_twice(void)
{
    /* Holding longer than debounce must not re-trigger */
    press_button_ms(20u);
    press_button_ms(100u);  /* still held */
    TEST_ASSERT_EQUAL(APP_MODE_BLINK_100MS, AppMode_Get());
}

void test_partial_press_resets_on_release(void)
{
    press_button_ms(10u);   /* 10 ms — not yet triggered */
    release_button_ms(5u);  /* release resets counter */
    press_button_ms(10u);   /* restart — still only 10 ms */
    TEST_ASSERT_EQUAL(APP_MODE_OFF, AppMode_Get());
}

void test_small_tick_accumulation_triggers(void)
{
    /* 4 × 5 ms = 20 ms → should trigger */
    mock_dio_channel_level[BTN] = STD_LOW;
    AppMode_Tick(5u);
    AppMode_Tick(5u);
    AppMode_Tick(5u);
    AppMode_Tick(5u);
    TEST_ASSERT_EQUAL(APP_MODE_BLINK_100MS, AppMode_Get());
}

/* ── Main ─────────────────────────────────────────────────────── */

int main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_initial_mode_is_off);
    RUN_TEST(test_short_press_below_debounce_does_not_advance);
    RUN_TEST(test_press_at_debounce_advances_to_blink100);
    RUN_TEST(test_second_press_advances_to_blink500);
    RUN_TEST(test_third_press_wraps_back_to_off);
    RUN_TEST(test_hold_does_not_advance_twice);
    RUN_TEST(test_partial_press_resets_on_release);
    RUN_TEST(test_small_tick_accumulation_triggers);
    return UNITY_END();
}
