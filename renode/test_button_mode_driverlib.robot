*** Settings ***
Documentation     LP-MSPM0G3507 button mode-cycling SIL test — TI driverlib binary.
...               Uses real hardware register addresses (mcal_msp + TI driverlib).
...               PA14 (USER button S2) cycles the LED mode:
...               OFF -> BLINK_100ms -> BLINK_500ms -> OFF -> ...
...
...               Button simulation:
...                 GPIOA DIN31_0 at 0x400A1380 (bit 14 = PA14).
...                 Model initialises din = 0xFFFFFFFF (all released).
...                 Write bit 14 = 0 to simulate press; write bit 14 = 1 to release.
...
...               LED observation: GPIOA DOUT31_0 at 0x400A1280 (bit 0 = PA0).
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
${BTN_PIN}      14
${BTN_MASK}     0x00004000

*** Test Cases ***
LED Stays OFF Before Any Button Press
    [Documentation]    Initial mode is OFF — LED must remain LOW for 1 s.
    Execute Command    emulation RunFor "00:00:01.000"
    ${level}=    Read LED Level
    Should Be Equal As Integers    ${level}    0

LED Blinks At 100 ms After First Button Press
    [Documentation]    Press button -> mode becomes BLINK_100ms.
    ...                After 150 ms the LED must have toggled ON at least once.
    Press Button       30
    Execute Command    emulation RunFor "00:00:00.150"
    ${level}=    Read LED Level
    Should Be Equal As Integers    ${level}    1

LED Blinks At 500 ms After Second Button Press
    [Documentation]    Second press -> mode becomes BLINK_500ms.
    ...                After 600 ms the LED must be HIGH (first 500 ms edge).
    Press Button       30
    Release Button
    Press Button       30
    Execute Command    emulation RunFor "00:00:00.600"
    ${level}=    Read LED Level
    Should Be Equal As Integers    ${level}    1

LED Returns OFF After Third Button Press
    [Documentation]    Third press wraps mode back to OFF — LED must be LOW.
    Press Button       30
    Release Button
    Press Button       30
    Release Button
    Press Button       30
    Execute Command    emulation RunFor "00:00:00.100"
    ${level}=    Read LED Level
    Should Be Equal As Integers    ${level}    0

*** Keywords ***
Prepare Machine
    [Documentation]    Fresh machine + real driverlib ELF for every test.
    Reset Emulation
    Execute Command    mach create "lp_mspm0g3507"
    Execute Command    machine LoadPlatformDescription @${CURDIR}/../bsw-mcal-msp/renode/mspm0g3507_driverlib.repl
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_gpio.py 0x400A0000 0x2000 False "gpioA"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_gpio.py 0x400A2000 0x2000 False "gpioB"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_sysctl.py 0x400AF000 0x3000 False "sysctl"
    Execute Command    sysbus LoadELF @${ELF}
    # Short boot settle (SysTick config + SYSCFG init)
    Execute Command    emulation RunFor "00:00:00.010"

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
