*** Settings ***
Documentation     LP-MSPM0G3507 LED-blink SIL test (Renode emulation).
...               Reads PA0 by sampling the GPIOA DOUT register the firmware
...               actually writes through hal_gpio_write at 0x400A0080.
Suite Setup       Setup
Suite Teardown    Teardown
Test Setup        Prepare Machine
Test Teardown     Test Teardown
Resource          ${RENODEKEYWORDS}

*** Variables ***
${PLATFORM}     ${CURDIR}/lp_mspm0g3507.repl
${ELF}          ${CURDIR}/../build/renode-sil/bsw_project_template.elf
${DOUT_ADDR}    0x400A0080
${LED_PIN}      0

*** Test Cases ***
LED Should Start OFF
    [Documentation]    Before the first BLINK_PERIOD_MS elapses, PA0 must be LOW.
    Execute Command    emulation RunFor "00:00:00.050"
    ${level}=    Read LED Level
    Should Be Equal As Integers    ${level}    0

LED Should Toggle ON After 500 ms
    [Documentation]    After BLINK_PERIOD_MS = 500 ms, PA0 must be HIGH.
    Execute Command    emulation RunFor "00:00:00.500"
    ${level}=    Read LED Level
    Should Be Equal As Integers    ${level}    1

LED Should Complete Full 1 Hz Cycle
    [Documentation]    After 1000 ms PA0 must return LOW (one full period).
    Execute Command    emulation RunFor "00:00:01.000"
    ${level}=    Read LED Level
    Should Be Equal As Integers    ${level}    0

*** Keywords ***
Prepare Machine
    [Documentation]    Fresh machine + ELF for every test, so each case starts
    ...                from a known reset state. emulation RunFor drives the
    ...                clock; we do NOT call `start` because RunFor and start
    ...                are mutually exclusive in Renode.
    Reset Emulation
    Execute Command    mach create "lp_mspm0g3507"
    Execute Command    machine LoadPlatformDescription @${PLATFORM}
    Execute Command    sysbus LoadELF @${ELF}

Read LED Level
    [Documentation]    Returns 0 or 1 — the value of bit LED_PIN in the GPIOA
    ...                DOUT register, sampled directly from the modeled memory.
    ${raw}=     Execute Command    sysbus ReadDoubleWord ${DOUT_ADDR}
    ${value}=   Convert To Integer    ${raw}    16
    ${bit}=     Evaluate    (${value} >> ${LED_PIN}) & 1
    [Return]    ${bit}
