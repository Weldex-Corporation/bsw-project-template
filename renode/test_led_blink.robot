*** Settings ***
Suite Setup       Setup
Suite Teardown    Teardown
Test Teardown     Test Teardown
Resource          ${RENODEKEYWORDS}

*** Variables ***
${PLATFORM}      ${CURDIR}/lp_mspm0g3507.repl
${ELF}           ${CURDIR}/../build/renode-sil/bsw_project_template.elf
# Diagnostic byte exposed by firmware: 0xFF when LED ON, 0x00 when LED OFF.
${LED_ADDR}      0x400A00F8

*** Test Cases ***
LED Should Start OFF
    [Documentation]    Before the first 500 ms tick LED_GREEN must be LOW
    Prepare Machine
    Execute Command    emulation RunFor "00:00:00.050"
    LED Should Match    0x00

LED Should Toggle ON After 500 ms
    [Documentation]    After 500 ms of simulated time LED_GREEN must be HIGH
    Prepare Machine
    Execute Command    emulation RunFor "00:00:00.520"
    LED Should Match    0xFF

LED Should Complete Full 1 Hz Cycle
    [Documentation]    After 1000 ms LED_GREEN must be LOW again (full period)
    Prepare Machine
    Execute Command    emulation RunFor "00:00:01.020"
    LED Should Match    0x00

*** Keywords ***
Prepare Machine
    Execute Command    mach create "lp_mspm0g3507"
    Execute Command    machine LoadPlatformDescription @${PLATFORM}
    Execute Command    sysbus LoadELF @${ELF}

LED Should Match
    [Arguments]    ${expected_hex}
    # Renode's ReadByte returns "0x00\n\n" or "0xff\n\n". Should Contain is
    # substring-based, so trailing whitespace and the 0x prefix don't matter.
    ${value}=    Execute Command    sysbus ReadByte ${LED_ADDR}
    Should Contain    ${value}    ${expected_hex}
