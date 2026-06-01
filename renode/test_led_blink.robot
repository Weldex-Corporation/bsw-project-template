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
${ELF}          ${CURDIR}/../build/renode-sil/bsw_project_template.elf
${BOARD_DIR}    ${CURDIR}/../boards/lp_mspm0g3507
${MODELS_DIR}   ${CURDIR}/../bsw/tools/hw_smoke/renode/models
${DOUT_ADDR}    0x400A0080
${LED_PIN}      0

*** Test Cases ***
LED Should Start OFF
    [Documentation]    Before the first BLINK_PERIOD_MS elapses, PA0 must be LOW.
    Execute Command    emulation RunFor "00:00:00.050"
    ${level}=    Read LED Level
    Should Be Equal As Integers    ${level}    0

LED Should Toggle ON After 500 ms
    [Documentation]    After BLINK_PERIOD_MS = 500 ms PA0 must be HIGH.
    ...                Adds a small RunFor margin (100 ms) so the polling
    ...                main loop has time to observe Mcu_GetTickMs >= 500
    ...                and to run the Dio_WriteChannel store after the
    ...                state toggle.
    Execute Command    emulation RunFor "00:00:00.600"
    ${level}=    Read LED Level
    Should Be Equal As Integers    ${level}    1

LED Should Complete Full 1 Hz Cycle
    [Documentation]    After ~1 s PA0 must return LOW (one full period).
    ...                Same RunFor margin as the 500 ms case so the second
    ...                toggle is captured.
    Execute Command    emulation RunFor "00:00:01.100"
    ${level}=    Read LED Level
    Should Be Equal As Integers    ${level}    0

*** Keywords ***
Prepare Machine
    [Documentation]    Fresh machine + ELF for every test, so each case starts
    ...                from a known reset state. All paths are absolute so they
    ...                resolve correctly regardless of Renode's working directory.
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
    [Documentation]    Returns 0 or 1 — the value of bit LED_PIN in the GPIOA
    ...                DOUT register, sampled directly from the modeled memory.
    ${raw}=     Execute Command    sysbus ReadDoubleWord ${DOUT_ADDR}
    ${value}=   Convert To Integer    ${raw}    16
    ${bit}=     Evaluate    (${value} >> ${LED_PIN}) & 1
    [Return]    ${bit}
