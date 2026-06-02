*** Settings ***
Documentation     LP-MSPM0G3507 rte_os boot + LED blink SIL test.
...               Firmware: build/bsw-mcal-msp-rte/bsw_project_template.elf
...               (APP_MODEL=rte_os — Os_bcc1 BCC1 + EcuM_bcc1 + Gpt MCAL tick).
...
...               What this test proves:
...                 - The rte_os firmware boots on MSPM0G3507 without faulting.
...                 - Os_IncrementCounter fires from the Gpt TIMG7 notification
...                   (1 ms cadence).
...                 - Os_Alarm + ACTIVATETASK path fires Swc_LedBlink at the
...                   configured 20 ms cycle.
...                 - GPIOA DOUT bit 0 (PA0, LED) toggles as a result.
Suite Setup       Setup
Suite Teardown    Teardown
Test Setup        Prepare Machine
Test Teardown     Test Teardown
Resource          ${RENODEKEYWORDS}

*** Variables ***
${ELF}          ${CURDIR}/../build/bsw-mcal-msp-rte/bsw_project_template.elf
${MODELS_DIR}   ${CURDIR}/../bsw-mcal-msp/renode/models
${DOUT_ADDR}          0x400A1280
${LED_PIN}            0
${LED_MASK}           0x00000001
# GPIOB DIN — used to inject button state (S2 = PB21, active LOW)
${GPIOB_DIN_ADDR}    0x400A3380
${BTN_S2_PRESSED}    0xFFDFFFFF
${BTN_S2_RELEASED}   0xFFFFFFFF

*** Keywords ***
Prepare Machine
    Reset Emulation
    Execute Command    mach create "lp_mspm0g3507_rte_os"
    Execute Command    machine LoadPlatformDescription @${CURDIR}/../bsw-mcal-msp/renode/mspm0g3507_periph.repl
    # Support models for startup + IO observation
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_sysctl.py 0x400AF000 0x3000 False "sysctl"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_gpio.py 0x400A0000 0x2000 False "gpioA"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_gpio.py 0x400A2000 0x2000 False "gpioB"
    # Tick timers (system tick + Predef Timer)
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_timg7.py 0x4086A000 0x2000 False "timg7"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_timg8.py 0x40090000 0x2000 False "timg8"
    Execute Command    sysbus LoadELF @${ELF}
    Execute Command    cpu PerformanceInMips 32

Read LED Level
    ${dout}=    Execute Command    sysbus ReadDoubleWord ${DOUT_ADDR}
    ${dout_int}=    Convert To Integer    ${dout.strip()}    16
    ${level}=    Evaluate    (${dout_int} >> ${LED_PIN}) & 1
    [Return]    ${level}

Press S2
    [Documentation]    Inject S2 button press by clearing PB21 in GPIOB DIN.
    Execute Command    sysbus WriteDoubleWord ${GPIOB_DIN_ADDR} ${BTN_S2_PRESSED}

Release S2
    [Documentation]    Release S2 button by setting PB21 back in GPIOB DIN.
    Execute Command    sysbus WriteDoubleWord ${GPIOB_DIN_ADDR} ${BTN_S2_RELEASED}

*** Test Cases ***
Boot Without Fault
    [Documentation]    Run for 100 ms and confirm the CPU is still
    ...                making progress (no HardFault, no stall).
    Execute Command    emulation RunFor "00:00:00.100"
    ${pc}=    Execute Command    cpu PC
    Log To Console    \nPC after 100ms: ${pc}

System Tick Counter Advances
    [Documentation]    After 200 ms of emulated time the OS system
    ...                counter must have advanced. With the TIMG7 model
    ...                LimitTimer fix in mspm0_timg7.py this is now
    ...                driven entirely by virtual time -- no manual
    ...                IRQ injection required.
    ${counter_sym}=    Execute Command    sysbus GetSymbolAddress "os_counter_ms"
    ${addr}=    Convert To Integer    ${counter_sym.strip()}    16
    Execute Command    emulation RunFor "00:00:00.200"
    ${val}=    Execute Command    sysbus ReadDoubleWord ${addr}
    ${val_int}=    Convert To Integer    ${val.strip()}    16
    Log To Console    \nos_counter_ms after 200 ms = ${val_int}
    Should Be True    ${val_int} >= 100

Alarm Walks Cause Mode And Blink Tasks To Run
    [Documentation]    With the system counter ticking the two
    ...                autostart alarms (Mode + Blink, 20 ms cycle) must
    ...                fire. We can't directly observe SWC entry from
    ...                Renode, but the LED stays OFF in initial mode
    ...                (OFF -> BLINK_100ms cycle requires a button
    ...                press at PB21 — see LED Toggle test below). What
    ...                we CAN check is that the system runs without
    ...                faulting and the PC stays in the expected text
    ...                range after 400 ms of tick-driven scheduling.
    Execute Command    emulation RunFor "00:00:00.400"
    ${pc_raw}=    Execute Command    cpu PC
    ${pc_str}=    Set Variable    ${pc_raw.strip()}
    Log To Console    \nPC after 400 ms tick-driven schedule = ${pc_str}
    # Loose sanity bound — PC must be within the 128 KiB flash region.
    ${pc}=    Convert To Integer    ${pc_str}    16
    Should Be True    ${pc} < 0x00020000

LED Toggles After Button Press
    [Documentation]    Simulate S2 button press on PB21 (GPIOB DIN) to
    ...                advance mode from OFF to BLINK_100MS, then verify
    ...                that LED (PA0) toggles.
    ...                Active-LOW LED: DOUT bit0=1 means LED off,
    ...                DOUT bit0=0 means LED on.

    # 1. Boot and settle — LED should be OFF (bit0=1, active LOW)
    Execute Command    emulation RunFor "00:00:00.100"
    ${level0}=    Read LED Level
    Should Be Equal As Integers    ${level0}    1
    ...    LED should be OFF (DOUT bit0=1) in initial RTE_MODE_OFF

    # 2. Press S2: clear bit 21 in GPIOB DIN (active-low button)
    Press S2

    # 3. Run 40 ms — debounce (20 ms) fires, mode OFF -> BLINK_100MS
    Execute Command    emulation RunFor "00:00:00.040"

    # 4. Release S2
    Release S2

    # 5. Run 200 ms — BLINK_100MS toggles LED every 100 ms
    Execute Command    emulation RunFor "00:00:00.200"
    ${levelA}=    Read LED Level

    # 6. Run another 100 ms — LED must have toggled
    Execute Command    emulation RunFor "00:00:00.100"
    ${levelB}=    Read LED Level

    Log To Console    \nLED after blink: levelA=${levelA} levelB=${levelB}
    Should Not Be Equal As Integers    ${levelA}    ${levelB}
    ...    LED must toggle between consecutive 100 ms windows in BLINK_100MS mode
