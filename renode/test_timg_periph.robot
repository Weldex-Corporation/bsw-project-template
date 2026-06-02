*** Settings ***
Documentation     LP-MSPM0G3507 TIMG0/TIMG6/TIMG12 + ADC1 SIL test suite.
...               Covers the 3 IRQ-capable TimerG models and ADC1 instance
...               that were previously missing from the Renode SIL model set.
...
...               Model base addresses:
...                 TIMG0   0x40084000  (size 0x2000) — IRQ 16, SW trigger test
...                 TIMG6   0x40868000  (size 0x2000) — IRQ 17, SW trigger test
...                 TIMG12  0x40870000  (size 0x2000) — IRQ 21, SW trigger test
...                 ADC1    0x40002000  (size 0x2000) — reuses mspm0_adc12.py
...                 ADC1 SVT            0x40558000  (size 0x1000) — MappedMemory
...
...               Test result slots (SRAM 0x20206000):
...                 0x20206000  timg0_ris      (RIS after ISET: want 1)
...                 0x20206004  timg0_ris_clr  (RIS after ICLR: want 0)
...                 0x20206008  timg6_ris      (RIS after ISET: want 1)
...                 0x2020600C  timg6_ris_clr  (RIS after ICLR: want 0)
...                 0x20206010  timg12_ris     (RIS after ISET: want 1)
...                 0x20206014  timg12_ris_clr (RIS after ICLR: want 0)
...                 0x20206018  adc1_result    (pre-injected 0x07FF)
Suite Setup       Setup
Suite Teardown    Teardown
Test Setup        Prepare Machine
Test Teardown     Test Teardown
Resource          ${RENODEKEYWORDS}

*** Variables ***
${ELF}              ${CURDIR}/../build/renode-driverlib-timg-test/bsw_project_template.elf
${MODELS_DIR}       ${CURDIR}/../bsw-mcal-msp/renode/models
# ADC1 SVT pre-inject address (ADC1_PERIPHERALREGIONSVT + 0x280)
${ADC1_SVT_MEMRES0}    0x40558280
# Result slots
${RES_T0_RIS}     0x20206000
${RES_T0_CLR}     0x20206004
${RES_T6_RIS}     0x20206008
${RES_T6_CLR}     0x2020600C
${RES_T12_RIS}    0x20206010
${RES_T12_CLR}    0x20206014
${RES_ADC1}       0x20206018

*** Test Cases ***
TIMG0 RIS Is 1 After ISET Software Trigger
    [Documentation]    Firmware writes ISET bit0 on TIMG0 (IRQ 16).
    ...                RIS bit0 (ZERO_EVENT) must be 1 immediately.
    ${v}=    Read Reg    ${RES_T0_RIS}
    Should Be Equal As Integers    ${v}    1

TIMG0 RIS Is 0 After ICLR Write
    [Documentation]    Firmware writes ICLR bit0 on TIMG0; RIS must return 0.
    ${v}=    Read Reg    ${RES_T0_CLR}
    Should Be Equal As Integers    ${v}    0

TIMG6 RIS Is 1 After ISET Software Trigger
    [Documentation]    Firmware writes ISET bit0 on TIMG6 (IRQ 17).
    ...                RIS bit0 (ZERO_EVENT) must be 1 immediately.
    ${v}=    Read Reg    ${RES_T6_RIS}
    Should Be Equal As Integers    ${v}    1

TIMG6 RIS Is 0 After ICLR Write
    [Documentation]    Firmware writes ICLR bit0 on TIMG6; RIS must return 0.
    ${v}=    Read Reg    ${RES_T6_CLR}
    Should Be Equal As Integers    ${v}    0

TIMG12 RIS Is 1 After ISET Software Trigger
    [Documentation]    Firmware writes ISET bit0 on TIMG12 (IRQ 21).
    ...                RIS bit0 (ZERO_EVENT) must be 1 immediately.
    ${v}=    Read Reg    ${RES_T12_RIS}
    Should Be Equal As Integers    ${v}    1

TIMG12 RIS Is 0 After ICLR Write
    [Documentation]    Firmware writes ICLR bit0 on TIMG12; RIS must return 0.
    ${v}=    Read Reg    ${RES_T12_CLR}
    Should Be Equal As Integers    ${v}    0

ADC1 MEMRES0 Returns Pre-Injected Value 0x07FF
    [Documentation]    Robot pre-injects 0x07FF into ADC1 SVT MEMRES[0].
    ...                Firmware reads via ADC1_PERIPHERALREGIONSVT + 0x280.
    ...                Result must equal 0x07FF.
    ${v}=    Read Reg    ${RES_ADC1}
    Should Be Equal As Integers    ${v}    0x07FF

*** Keywords ***
Prepare Machine
    [Documentation]    Build Renode machine with TIMG0/6/12 and ADC1 models.
    Reset Emulation
    Execute Command    mach create "lp_mspm0g3507_timg"
    Execute Command    machine LoadPlatformDescription @${CURDIR}/../bsw/platform/bsw-mcal-msp/renode/mspm0g3507_periph.repl
    # Support models
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_sysctl.py 0x400AF000 0x3000 False "sysctl"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_gpio.py 0x400A0000 0x2000 False "gpioA"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_gpio.py 0x400A2000 0x2000 False "gpioB"
    # 3 TIMG models under test
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_timg0.py 0x40084000 0x2000 False "timg0"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_timg6.py 0x40868000 0x2000 False "timg6"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_timg12.py 0x40870000 0x2000 False "timg12"
    # ADC1: same model as ADC0, loaded at ADC1 base address
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_adc12.py 0x40002000 0x2000 False "adc1"
    # ADC1 SVT (adc1_svt MappedMemory) is already in mspm0g3507_periph.repl
    # Pre-inject ADC1 result before LoadELF
    Execute Command    sysbus WriteDoubleWord ${ADC1_SVT_MEMRES0} 0x07FF
    Execute Command    sysbus LoadELF @${ELF}
    Execute Command    emulation RunFor "00:00:00.200"

Read Reg
    [Documentation]    Read a 32-bit register and return as integer.
    [Arguments]        ${addr}
    ${raw}=    Execute Command    sysbus ReadDoubleWord ${addr}
    ${val}=    Convert To Integer    ${raw}    16
    [Return]   ${val}
