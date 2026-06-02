*** Settings ***
Documentation     LP-MSPM0G3507 TIMG0 PWM SIL test — TI driverlib binary.
...               Verifies that DL_TimerG_setLoadValue and
...               DL_TimerG_setCaptureCompareValue write the expected values
...               to the TIMG0 model registers (observable via sysbus reads).
...
...               TIMG0 register model at 0x40084000 (mspm0_timg.py):
...                 - LOAD register at 0x40085808  (TIMG0_BASE + 0x1808)
...                 - CC_01[0]      at 0x40085810  (TIMG0_BASE + 0x1810)
...               Firmware sets LOAD=999, CC0=749 and starts the counter.
Suite Setup       Setup
Suite Teardown    Teardown
Test Setup        Prepare Machine
Test Teardown     Test Teardown
Resource          ${RENODEKEYWORDS}

*** Variables ***
${ELF}           ${CURDIR}/../build/renode-driverlib-periph/bsw_project_template.elf
${MODELS_DIR}    ${CURDIR}/../bsw-mcal-msp/renode/models
${SVT_ADDR}      0x40556280
${TIMG0_LOAD}    0x40085808
${TIMG0_CC0}     0x40085810

*** Test Cases ***
TIMG0 LOAD Register Is 999 After Init
    [Documentation]    After firmware configures TIMG0 PWM,
    ...                LOAD register must read back 999.
    Execute Command    emulation RunFor "00:00:00.100"
    ${raw}=    Read Register    ${TIMG0_LOAD}
    Should Be Equal As Integers    ${raw}    999

TIMG0 CC0 Register Is 749 After Init
    [Documentation]    After firmware configures TIMG0 PWM,
    ...                CC_01[0] register must read back 749 (75% duty cycle).
    Execute Command    emulation RunFor "00:00:00.100"
    ${raw}=    Read Register    ${TIMG0_CC0}
    Should Be Equal As Integers    ${raw}    749

*** Keywords ***
Prepare Machine
    [Documentation]    Fresh machine for every test; load ADC + TimerG + GPIO models.
    Reset Emulation
    Execute Command    mach create "lp_mspm0g3507_periph"
    Execute Command    machine LoadPlatformDescription @${CURDIR}/../bsw/platform/bsw-mcal-msp/renode/mspm0g3507_periph.repl
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_adc12.py 0x40000000 0x2000 False "adc0"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_timg.py 0x40084000 0x2000 False "timg0"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_gpio.py 0x400A0000 0x2000 False "gpioA"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_gpio.py 0x400A2000 0x2000 False "gpioB"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_sysctl.py 0x400AF000 0x3000 False "sysctl"
    # Pre-inject ADC result so firmware doesn't hang in the ADC spin-wait
    Execute Command    sysbus WriteDoubleWord ${SVT_ADDR} 0x0000
    Execute Command    sysbus LoadELF @${ELF}
    Execute Command    emulation RunFor "00:00:00.010"

Read Register
    [Documentation]    Reads a 32-bit register and returns an integer.
    [Arguments]        ${addr}
    ${raw}=    Execute Command    sysbus ReadDoubleWord ${addr}
    ${value}=  Convert To Integer    ${raw}    16
    [Return]   ${value}
