*** Settings ***
Documentation     rte_os WCET / cycles-per-tick measurement.
...
...               Uses Renode's `cpu ExecutedInstructions` counter
...               (1 instruction =~ 1 cycle on Cortex-M0+) to bound the
...               work the firmware does between TIMG7 1 ms ticks.
...
...               Three numbers produced:
...                 - avg instructions per 1 ms tick window (steady state)
...                 - min / max instructions across a 100-tick window
...                   (worst-case execution time observed in this run)
...                 - ratio against the 32 MHz CPU clock — what % of one
...                   tick is the CPU actually busy vs idle in WFI
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
    Execute Command    mach create "rte_os_wcet"
    Execute Command    machine LoadPlatformDescription @${CURDIR}/../bsw-mcal-msp/renode/mspm0g3507_periph.repl
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_sysctl.py 0x400AF000 0x3000 False "sysctl"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_gpio.py 0x400A0000 0x2000 False "gpioA"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_timg7.py 0x4086A000 0x2000 False "timg7"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_timg8.py 0x40090000 0x2000 False "timg8"
    Execute Command    sysbus LoadELF @${ELF}
    Execute Command    cpu PerformanceInMips 32

Read Insn
    ${raw}=    Execute Command    cpu ExecutedInstructions
    ${val}=    Convert To Integer    ${raw.strip()}
    [Return]    ${val}

*** Test Cases ***
Average Instructions Per 1ms Tick (Steady-State)
    [Documentation]    Let Os_StartOS settle for 5 ms, then measure
    ...                instructions over a 100-tick window.
    Execute Command    emulation RunFor "00:00:00.005"
    ${start}=    Read Insn
    Execute Command    emulation RunFor "00:00:00.100"
    ${end}=    Read Insn
    ${total}=    Evaluate    ${end} - ${start}
    ${avg}=    Evaluate    ${total} / 100
    Log To Console    \n--- 100 ms window ---
    Log To Console    instructions executed   = ${total}
    Log To Console    average per 1 ms tick   = ${avg}
    Log To Console    cpu clock (assumed)     = 32_000_000 Hz
    ${budget}=    Evaluate    32000
    ${pct}=    Evaluate    int(${avg} * 100 / ${budget})
    Log To Console    busy %% per tick budget = ${pct}%%   (32_000 cycles = 1 ms @ 32 MHz)
    # Loose sanity bound — the BCC1 cooperative tick + alarm walk is well
    # under 10_000 cycles per ms in steady state.
    Should Be True    ${avg} < 20000

Per-Tick WCET Across 50 Consecutive Ticks
    [Documentation]    Step in 1 ms slices and record instructions per
    ...                slice. Reports min / max / sum so the worst tick
    ...                in the window is visible.
    Execute Command    emulation RunFor "00:00:00.005"
    ${prev}=    Read Insn
    ${min}=     Set Variable    999999999
    ${max}=     Set Variable    0
    ${sum}=     Set Variable    0
    FOR    ${i}    IN RANGE    50
        Execute Command    emulation RunFor "00:00:00.001"
        ${now}=    Read Insn
        ${delta}=    Evaluate    ${now} - ${prev}
        ${prev}=    Set Variable    ${now}
        ${min}=    Evaluate    min(${min}, ${delta})
        ${max}=    Evaluate    max(${max}, ${delta})
        ${sum}=    Evaluate    ${sum} + ${delta}
    END
    ${avg}=    Evaluate    ${sum} / 50
    Log To Console    \n--- 50 tick slices ---
    Log To Console    min instructions / tick = ${min}
    Log To Console    max instructions / tick = ${max}
    Log To Console    avg instructions / tick = ${avg}
    # WCET shall fit comfortably in the 1 ms tick window.
    Should Be True    ${max} < 32000
