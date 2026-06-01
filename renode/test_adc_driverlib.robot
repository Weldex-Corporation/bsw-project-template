*** Settings ***
Documentation     LP-MSPM0G3507 ADC12 SIL test — TI driverlib binary.
...               Verifies that DL_ADC12_getMemResult() returns the injected
...               value after a SW-triggered single conversion on ADC0/ch0.
...
...               ADC0 register model at 0x40000000 (mspm0_adc12.py):
...                 - Detects SC bit write in CTL1 → raises MEMRESIFG0 in RIS.
...               ADC0 SVT region at 0x40556000 (MappedMemory in .repl):
...                 - MEMRES[0] at offset 0x280 (absolute 0x40556280).
...                 - Pre-loaded by robot before firmware start.
...               Firmware signals result via GPIOB DOUTSET (bit-OR into DOUT):
...                 - GPIOB DOUT31_0 readable at 0x400A3280.
Suite Setup       Setup
Suite Teardown    Teardown
Test Setup        Prepare Machine
Test Teardown     Test Teardown
Resource          ${RENODEKEYWORDS}

*** Variables ***
${ELF}           ${CURDIR}/../build/renode-driverlib-periph/bsw_project_template.elf
${MODELS_DIR}    ${CURDIR}/../bsw/platform/bsw-mcal-msp/renode/models
${SVT_ADDR}      0x40556280
${GPIOB_DOUT}    0x400A3280

*** Test Cases ***
ADC Result Matches Injected Value 0x0800
    [Documentation]    Pre-inject 0x0800 (2048) into ADC0 SVT MEMRES[0].
    ...                Firmware reads ADC result and writes it to GPIOB DOUT.
    ...                Robot verifies GPIOB DOUT equals the injected value.
    Inject ADC Result    0x0800
    Execute Command      emulation RunFor "00:00:00.100"
    ${raw}=    Read GPIOB DOUT
    Should Be Equal As Integers    ${raw}    2048

ADC Result Matches Injected Value 0x0FFF
    [Documentation]    Pre-inject 0x0FFF (4095 = full-scale 12-bit) and verify.
    Inject ADC Result    0x0FFF
    Execute Command      emulation RunFor "00:00:00.100"
    ${raw}=    Read GPIOB DOUT
    Should Be Equal As Integers    ${raw}    4095

ADC Result Matches Injected Value 0x0000
    [Documentation]    Pre-inject 0x0000 (zero volts) and verify.
    Inject ADC Result    0x0000
    Execute Command      emulation RunFor "00:00:00.100"
    ${raw}=    Read GPIOB DOUT
    Should Be Equal As Integers    ${raw}    0

*** Keywords ***
Prepare Machine
    [Documentation]    Fresh machine for every test; load ADC + GPIO models.
    Reset Emulation
    Execute Command    mach create "lp_mspm0g3507_periph"
    Execute Command    machine LoadPlatformDescription @${CURDIR}/../bsw/platform/bsw-mcal-msp/renode/mspm0g3507_periph.repl
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_adc12.py 0x40000000 0x2000 False "adc0"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_timg.py 0x40084000 0x2000 False "timg0"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_gpio.py 0x400A0000 0x2000 False "gpioA"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_gpio.py 0x400A2000 0x2000 False "gpioB"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_sysctl.py 0x400AF000 0x3000 False "sysctl"

Inject ADC Result
    [Documentation]    Write the injected result into the ADC0 SVT MappedMemory
    ...                before the ELF is loaded; firmware reads this via DL_ADC12_getMemResult.
    [Arguments]        ${value}
    Execute Command    sysbus WriteDoubleWord ${SVT_ADDR} ${value}
    Execute Command    sysbus LoadELF @${ELF}
    Execute Command    emulation RunFor "00:00:00.010"

Read GPIOB DOUT
    [Documentation]    Returns the current GPIOB DOUT31_0 value (32-bit integer).
    ${raw}=    Execute Command    sysbus ReadDoubleWord ${GPIOB_DOUT}
    ${value}=  Convert To Integer    ${raw}    16
    [Return]   ${value}
