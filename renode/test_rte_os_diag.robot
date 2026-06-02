*** Settings ***
Documentation     rte_os boot diagnostics — trace symbols + TIMG7 regs to
...               figure out why Os_IncrementCounter isn't firing in Renode.
...
...               Finding (2026-06-02): firmware-side is correct. After 500 ms:
...                 os_running = 1, os_isr_nest = 0 (main loop entered);
...                 TIMG7 PWREN/PWRSTAT/CPS=32/IMASK=1/CTRCTL=3 (EN|REPEAT)
...                 /LOAD=1000 all match what Gpt_Hw.c should program;
...                 BUT os_counter_ms = 0 and TIMG7 RIS = 0.
...               Conclusion: the Renode Python mspm0_timg7.py model's
...               time-based fire path (_schedule -> _do_fire) is not
...               firing — only its software-trigger (ISET) path works
...               (which is what test_missing_periph.robot exercises).
...               TODO follow-up — replace the Python model with a proper
...               C# peripheral, or fix the ScheduleAction lambda capture.
Suite Setup       Setup
Suite Teardown    Teardown
Test Setup        Prepare Machine
Resource          ${RENODEKEYWORDS}

*** Variables ***
${ELF}          ${CURDIR}/../build/bsw-mcal-msp-rte/bsw_project_template.elf
${MODELS_DIR}   ${CURDIR}/../bsw-mcal-msp/renode/models

*** Keywords ***
Prepare Machine
    Reset Emulation
    Execute Command    mach create "rte_os_diag"
    Execute Command    machine LoadPlatformDescription @${CURDIR}/../bsw-mcal-msp/renode/mspm0g3507_periph.repl
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_sysctl.py 0x400AF000 0x3000 False "sysctl"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_gpio.py 0x400A0000 0x2000 False "gpioA"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_timg7.py 0x4086A000 0x2000 False "timg7"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_timg8.py 0x40090000 0x2000 False "timg8"
    Execute Command    sysbus LoadELF @${ELF}
    Execute Command    cpu PerformanceInMips 32

Read Sym U32
    [Arguments]    ${sym}
    ${addr_raw}=    Execute Command    sysbus GetSymbolAddress "${sym}"
    ${addr}=    Convert To Integer    ${addr_raw.strip()}    16
    ${val_raw}=    Execute Command    sysbus ReadDoubleWord ${addr}
    ${val}=    Convert To Integer    ${val_raw.strip()}    16
    [Return]    ${val}

Read Reg U32
    [Arguments]    ${addr}
    ${val_raw}=    Execute Command    sysbus ReadDoubleWord ${addr}
    ${val}=    Convert To Integer    ${val_raw.strip()}    16
    [Return]    ${val}

*** Test Cases ***
Boot Diagnostics — Symbols + TIMG7 Regs After 500ms
    [Documentation]    Run for 500 ms then log everything interesting.
    Execute Command    emulation RunFor "00:00:00.500"

    # Os_Counter.c state
    ${counter}=    Read Sym U32    os_counter_ms
    Log To Console    \nos_counter_ms      = ${counter}

    # Os_bcc1 state
    ${running}=    Read Sym U32    os_running
    Log To Console    os_running         = ${running}
    ${current}=    Read Sym U32    os_current
    Log To Console    os_current         = ${current}
    ${isr_nest}=    Read Sym U32    os_isr_nest
    Log To Console    os_isr_nest        = ${isr_nest}

    # TIMG7 register snapshot (channel 0 = system tick)
    ${pwren}=      Read Reg U32    0x4086A800
    Log To Console    TIMG7 PWREN       = ${pwren}
    ${pwrstat}=    Read Reg U32    0x4086A814
    Log To Console    TIMG7 PWRSTAT     = ${pwrstat}
    ${cps}=        Read Reg U32    0x4086B10C
    Log To Console    TIMG7 CPS         = ${cps}
    ${imask}=      Read Reg U32    0x4086B028
    Log To Console    TIMG7 IMASK       = ${imask}
    ${ctrctl}=     Read Reg U32    0x4086B804
    Log To Console    TIMG7 CTRCTL      = ${ctrctl}
    ${load}=       Read Reg U32    0x4086B808
    Log To Console    TIMG7 LOAD        = ${load}
    ${ris}=        Read Reg U32    0x4086B030
    Log To Console    TIMG7 RIS         = ${ris}

    # TIMG8 (Predef Timer)
    ${pwren8}=     Read Reg U32    0x40090800
    Log To Console    TIMG8 PWREN       = ${pwren8}
    ${ctr8}=       Read Reg U32    0x40091800
    Log To Console    TIMG8 CTR         = ${ctr8}

    # CPU current PC
    ${pc}=    Execute Command    cpu PC
    Log To Console    CPU PC            = ${pc.strip()}

    # Just so the test always passes — we're using it as a probe.
    Should Be True    True
