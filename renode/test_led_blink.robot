*** Settings ***
Suite Setup       Setup
Suite Teardown    Teardown
Test Teardown     Test Teardown
Resource          ${RENODEKEYWORDS}

*** Variables ***
${PLATFORM}    ${CURDIR}/lp_mspm0g3507.repl
${ELF}         ${CURDIR}/../build/renode-sil/bsw_project_template.elf
${LED_GPIO}    sysbus.gpioA
${LED_PIN}     0

*** Test Cases ***
LED Should Start OFF
    [Documentation]    LED_GREEN (PA0) must be LOW before first tick
    Create Machine
    Load ELF
    Start Emulation
    Sleep    0.1s
    ${level}=    Execute Command    ${LED_GPIO} GetGPIO ${LED_PIN}
    Should Be Equal As Integers    ${level}    0

LED Should Toggle ON After 500 ms
    [Documentation]    After 500 ms of simulated time LED_GREEN must go HIGH
    Create Machine
    Load ELF
    Start Emulation
    Execute Command    emulation RunFor "00:00:00.500"
    ${level}=    Execute Command    ${LED_GPIO} GetGPIO ${LED_PIN}
    Should Be Equal As Integers    ${level}    1

LED Should Complete Full 1 Hz Cycle
    [Documentation]    After 1000 ms LED_GREEN must be LOW again (full period)
    Create Machine
    Load ELF
    Start Emulation
    Execute Command    emulation RunFor "00:00:01.000"
    ${level}=    Execute Command    ${LED_GPIO} GetGPIO ${LED_PIN}
    Should Be Equal As Integers    ${level}    0

*** Keywords ***
Create Machine
    Execute Command    mach create "lp_mspm0g3507"
    Execute Command    machine LoadPlatformDescription @${PLATFORM}

Load ELF
    Execute Command    sysbus LoadELF @${ELF}

Start Emulation
    Execute Command    start
