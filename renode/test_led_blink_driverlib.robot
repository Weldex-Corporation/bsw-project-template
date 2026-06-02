*** Settings ***
Documentation     LP-MSPM0G3507 LED blink SIL test — TI driverlib binary.
...               Uses real hardware register addresses (mcal_msp + TI driverlib).
...               LED observation: GPIOA DOUT31_0 at 0x400A1280 (bit 0 = PA0).
...               SysTick drives Mcu_GetTickMs(); SYSCTL model ensures init completes.
...
...               Firmware starts in APP_MODE_OFF. Two button presses reach
...               BLINK_500MS mode (OFF→BLINK_100MS→BLINK_500MS).
...               Button simulation: GPIOA DIN31_0 at 0x400A1380, bit 14 = PA14.
Suite Setup       Setup
Suite Teardown    Teardown
Test Setup        Prepare Machine
Test Teardown     Test Teardown
Resource          ${RENODEKEYWORDS}

*** Variables ***
${ELF}          ${CURDIR}/../build/renode-driverlib/bsw_project_template.elf
${MODELS_DIR}   ${CURDIR}/../bsw-mcal-msp/renode/models
${DOUT_ADDR}    0x400A1280
${DIN_ADDR}     0x400A1380
${LED_PIN}      0
${BTN_MASK}     0x00004000

*** Test Cases ***
LED Stays OFF In Default Mode
    [Documentation]    Default mode is APP_MODE_OFF — LED remains LOW for 1 s.
    Execute Command    emulation RunFor "00:00:01.000"
    ${level}=    Read LED Level
    Should Be Equal As Integers    ${level}    0

LED Toggles ON At 500 ms In BLINK_500MS Mode
    [Documentation]    Two button presses set mode to BLINK_500MS.
    ...                After 500 ms the LED must have toggled HIGH (first blink edge).
    Enter Blink 500ms Mode
    Execute Command    emulation RunFor "00:00:00.500"
    ${level}=    Read LED Level
    Should Be Equal As Integers    ${level}    1

LED Completes Full 1 Hz Cycle In BLINK_500MS Mode
    [Documentation]    After 1000 ms in BLINK_500MS mode, LED returns LOW
    ...                (completed one full ON/OFF cycle).
    Enter Blink 500ms Mode
    Execute Command    emulation RunFor "00:00:01.000"
    ${level}=    Read LED Level
    Should Be Equal As Integers    ${level}    0

*** Keywords ***
Prepare Machine
    [Documentation]    Fresh machine + real driverlib ELF for every test.
    Reset Emulation
    Execute Command    mach create "lp_mspm0g3507"
    Execute Command    machine LoadPlatformDescription @${CURDIR}/../bsw/platform/bsw-mcal-msp/renode/mspm0g3507_driverlib.repl
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_gpio.py 0x400A0000 0x2000 False "gpioA"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_gpio.py 0x400A2000 0x2000 False "gpioB"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_sysctl.py 0x400AF000 0x3000 False "sysctl"
    Execute Command    sysbus LoadELF @${ELF}
    # Short boot settle (SysTick config + SYSCFG init)
    Execute Command    emulation RunFor "00:00:00.010"

Enter Blink 500ms Mode
    [Documentation]    Two button presses cycle: OFF -> BLINK_100MS -> BLINK_500MS.
    Press Button       30
    Release Button
    Press Button       30
    Release Button

Press Button
    [Documentation]    Simulate button held for hold_ms virtual ms (active low on PA14).
    [Arguments]        ${hold_ms}=30
    ${din_pressed}=    Evaluate    0xFFFFFFFF & ~${BTN_MASK}
    Execute Command    sysbus WriteDoubleWord ${DIN_ADDR} ${din_pressed}
    ${hold_s}=         Evaluate    "00:00:00.%03d" % ${hold_ms}
    Execute Command    emulation RunFor "${hold_s}"

Release Button
    [Documentation]    Release the button (PA14 HIGH).
    Execute Command    sysbus WriteDoubleWord ${DIN_ADDR} 0xFFFFFFFF
    Execute Command    emulation RunFor "00:00:00.010"

Read LED Level
    [Documentation]    Returns 0 or 1 for PA0 (LED_GREEN) from GPIOA DOUT31_0.
    ${raw}=     Execute Command    sysbus ReadDoubleWord ${DOUT_ADDR}
    ${value}=   Convert To Integer    ${raw}    16
    ${bit}=     Evaluate    (${value} >> ${LED_PIN}) & 1
    [Return]    ${bit}
