*** Settings ***
Documentation     LP-MSPM0G3507 LED-blink SIL test — Os_Lite scheduler variant.
...               Same LED behaviour as the bare-metal test (500 ms period);
...               verifies that Os_Lite dispatches Task_LedBlink at the right time.
Suite Setup       Setup
Suite Teardown    Teardown
Test Setup        Prepare Machine
Test Teardown     Test Teardown
Resource          ${RENODEKEYWORDS}

*** Variables ***
${ELF}          ${CURDIR}/../build/renode-sil-oslite/bsw_project_template.elf
${BOARD_DIR}    ${CURDIR}/../boards/lp_mspm0g3507
${MODELS_DIR}   ${CURDIR}/../bsw/tools/hw_smoke/renode/models
${DOUT_ADDR}    0x400A0080
${LED_PIN}      0

*** Test Cases ***
LED Should Start OFF
    [Documentation]    Before the first 500 ms period elapses, PA0 must be LOW.
    Execute Command    emulation RunFor "00:00:00.050"
    ${level}=    Read LED Level
    Should Be Equal As Integers    ${level}    0

LED Should Toggle ON After 500 ms
    [Documentation]    After the first Os_Lite period (500 ms) PA0 must be HIGH.
    Execute Command    emulation RunFor "00:00:00.600"
    ${level}=    Read LED Level
    Should Be Equal As Integers    ${level}    1

LED Should Complete Full 1 Hz Cycle
    [Documentation]    After ~1 s PA0 must return LOW (one full period).
    Execute Command    emulation RunFor "00:00:01.100"
    ${level}=    Read LED Level
    Should Be Equal As Integers    ${level}    0

*** Keywords ***
Prepare Machine
    Reset Emulation
    Execute Command    mach create "lp_mspm0g3507"
    Execute Command    machine LoadPlatformDescription @${CURDIR}/../bsw/tools/hw_smoke/renode/mspm0g3507.repl
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_wwdt.py 0x40080000 0x1200 True "wwdt0"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_wwdt.py 0x40082000 0x1200 True "wwdt1"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_timg8.py 0x40090000 0x2000 True "timg8"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_timg7.py 0x4086A000 0x2000 True "timg7"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_dma.py 0x4042A000 0x1400 True "dma"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_uart.py 0x40100000 0x2000 True "uart1"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_uart.py 0x40108000 0x2000 True "uart0"
    Execute Command    sysbus LoadELF @${ELF}

Read LED Level
    ${raw}=     Execute Command    sysbus ReadDoubleWord ${DOUT_ADDR}
    ${value}=   Convert To Integer    ${raw}    16
    ${bit}=     Evaluate    (${value} >> ${LED_PIN}) & 1
    [Return]    ${bit}
