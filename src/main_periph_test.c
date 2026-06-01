#include "ti/devices/msp/m0p/mspm0g350x.h"
#include "ti/driverlib/dl_adc12.h"
#include "ti/driverlib/dl_timerg.h"
#include "ti/driverlib/dl_timer.h"

/* ADC0 result, populated after single SW-triggered conversion on ch0.
 * Signal value also written to GPIOB DOUT (0x400A3280) for SIL inspection. */
volatile uint32_t g_adc0_result;

int main(void)
{
    /* --- ADC0: single SW-triggered conversion on ch0 --- */
    DL_ADC12_enablePower(ADC0);
    DL_ADC12_reset(ADC0);

    DL_ADC12_initSingleSample(ADC0,
        DL_ADC12_REPEAT_MODE_DISABLED,
        DL_ADC12_SAMPLING_SOURCE_AUTO,
        DL_ADC12_TRIG_SRC_SOFTWARE,
        DL_ADC12_SAMP_CONV_RES_12_BIT,
        DL_ADC12_SAMP_CONV_DATA_FORMAT_UNSIGNED);

    DL_ADC12_configConversionMem(ADC0, DL_ADC12_MEM_IDX_0,
        DL_ADC12_INPUT_CHAN_0,
        DL_ADC12_REFERENCE_VOLTAGE_VDDA,
        DL_ADC12_SAMPLE_TIMER_SOURCE_SCOMP0,
        DL_ADC12_AVERAGING_MODE_DISABLED,
        DL_ADC12_BURN_OUT_SOURCE_DISABLED,
        DL_ADC12_TRIGGER_MODE_AUTO_NEXT,
        DL_ADC12_WINDOWS_COMP_MODE_DISABLED);

    DL_ADC12_enableConversions(ADC0);
    DL_ADC12_startConversion(ADC0);

    while (!DL_ADC12_getRawInterruptStatus(ADC0,
        DL_ADC12_INTERRUPT_MEM0_RESULT_LOADED));

    g_adc0_result = DL_ADC12_getMemResult(ADC0, DL_ADC12_MEM_IDX_0);
    DL_ADC12_clearInterruptStatus(ADC0, DL_ADC12_INTERRUPT_MEM0_RESULT_LOADED);

    /* Signal ADC result via GPIOB DOUTSET for SIL observation at 0x400A3280 */
    GPIOB->DOUTSET31_0 = (uint32_t)g_adc0_result;

    /* --- TIMG0: configure PWM — LOAD=999, CC0=749 (75% duty cycle) --- */
    DL_TimerG_enablePower(TIMG0);
    DL_TimerG_reset(TIMG0);
    DL_TimerG_setLoadValue(TIMG0, 999);
    DL_TimerG_setCaptureCompareValue(TIMG0, 749, DL_TIMER_CC_0_INDEX);
    DL_TimerG_startCounter(TIMG0);

    while (1) {
        __WFI();
    }
    return 0;
}
