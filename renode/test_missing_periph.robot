*** Settings ***
Documentation     LP-MSPM0G3507 missing-peripheral SIL test suite.
...               Covers the 5 models not included in test_all_periph.robot:
...               UART0, DMA, WWDT0, TIMG7, TIMG8.
...
...               Model base addresses:
...                 UART0    0x40108000  (size 0x2000) — TX capture + RX inject hooks
...                 DMA      0x4042A000  (size 0x1400) — ch0 SRAM-to-SRAM copy
...                 WWDT0    0x40080000  (size 0x1200) — always-service watchdog
...                 TIMG7    0x4086A000  (size 0x2000) — IRQ 20, SW trigger test
...                 TIMG8    0x40090000  (size 0x2000) — IRQ 2,  SW trigger test
...
...               Test result slots written by firmware at fixed SRAM addresses:
...                 0x20204000  uart_rx_result   (byte read from RXDATA)
...                 0x20204004  wwdt_stat_result (WWDTSTAT should be 0)
...                 0x20204008  timg7_ris        (RIS after ISET: want 1)
...                 0x2020400C  timg7_ris_clr    (RIS after ICLR: want 0)
...                 0x20204010  timg8_ris        (RIS after ISET: want 1)
...                 0x20204014  timg8_ris_clr    (RIS after ICLR: want 0)
...
...               DMA destination checked directly:
...                 0x20205100  (copy of 0xCAFEBABE from 0x20205000)
Suite Setup       Setup
Suite Teardown    Teardown
Test Setup        Prepare Machine
Test Teardown     Test Teardown
Resource          ${RENODEKEYWORDS}

*** Variables ***
${ELF}              ${CURDIR}/../build/renode-driverlib-missing-periph/bsw_project_template.elf
${MODELS_DIR}       ${CURDIR}/../bsw/platform/bsw-mcal-msp/renode/models
# UART0 test-hook registers (model-specific, not in real HW)
${UART0_TXBUF_LEN}    0x40109FFC
${UART0_TXBUF_DRAIN}    0x40109FF8
${UART0_RXBUF_PUSH}    0x40109FF0
${UART0_STAT}    0x40109108
# DMA channel 0 registers
${DMA_CH0_CTL}    0x4042B200
${DMA_CH0_DMASZ}    0x4042B20C
${DMA_DST}    0x20205100
# Result slots in SRAM
${RES_UART_RX}    0x20204000
${RES_WWDT_STAT}    0x20204004
${RES_TIM7_RIS}    0x20204008
${RES_TIM7_CLR}    0x2020400C
${RES_TIM8_RIS}    0x20204010
${RES_TIM8_CLR}    0x20204014

*** Test Cases ***
UART0 TX Buffer Captures 3 Written Bytes
    [Documentation]    Firmware writes 'A','B','C' to TXDATA.
    ...                TXBUF_LEN hook must read 3.
    ${v}=    Read Reg    ${UART0_TXBUF_LEN}
    Should Be Equal As Integers    ${v}    3

UART0 TX Drain Returns First Byte 0x41
    [Documentation]    TXBUF_DRAIN pops the oldest byte from the TX buffer.
    ...                First byte written was 'A' = 0x41.
    ${v}=    Read Reg    ${UART0_TXBUF_DRAIN}
    Should Be Equal As Integers    ${v}    0x41

UART0 STAT Is Always Idle 0x44
    [Documentation]    STAT register always returns 0x44 (TXFE|RFE — not busy).
    ${v}=    Read Reg    ${UART0_STAT}
    Should Be Equal As Integers    ${v}    0x44

UART0 RXDATA Returns Pre-Injected Byte 0x5A
    [Documentation]    Robot pre-injected 0x5A via RXBUF_PUSH hook.
    ...                Firmware reads RXDATA and stores in result[0].
    ...                Result must equal 0x5A.
    ${v}=    Read Reg    ${RES_UART_RX}
    Should Be Equal As Integers    ${v}    0x5A

DMA Channel 0 Copies 0xCAFEBABE To Destination
    [Documentation]    Firmware writes 0xCAFEBABE to DMA_SRC (0x20205000),
    ...                sets up ch0, enables DMAEN.  Model copies 4 bytes to
    ...                DMA_DST (0x20205100). Read destination and verify.
    ${v}=    Read Reg    ${DMA_DST}
    Should Be Equal As Integers    ${v}    0xCAFEBABE

DMA Channel 0 DMASZ Is Zero After Transfer
    [Documentation]    Model clears DMASZ to 0 after transfer completes.
    ${v}=    Read Reg    ${DMA_CH0_DMASZ}
    Should Be Equal As Integers    ${v}    0

DMA Channel 0 DMAEN Is Cleared After Transfer
    [Documentation]    Model clears DMAEN bit (bit1) in DMACTL after transfer.
    ${v}=    Read Reg    ${DMA_CH0_CTL}
    ${dmaen}=    Evaluate    ${v} & 2
    Should Be Equal As Integers    ${dmaen}    0

WWDT0 STAT Is Zero (No Fault)
    [Documentation]    Firmware writes WWDTCTL0 and services WWDTCNTRST.
    ...                WWDTSTAT must be 0 — no fault, no interrupt pending.
    ${v}=    Read Reg    ${RES_WWDT_STAT}
    Should Be Equal As Integers    ${v}    0

TIMG7 RIS Is 1 After ISET Software Trigger
    [Documentation]    Firmware writes ISET bit0 (software trigger).
    ...                RIS bit0 (ZERO_EVENT) must be 1 immediately.
    ${v}=    Read Reg    ${RES_TIM7_RIS}
    Should Be Equal As Integers    ${v}    1

TIMG7 RIS Is 0 After ICLR Write
    [Documentation]    Firmware writes ICLR bit0 to clear pending interrupt.
    ...                RIS must return 0.
    ${v}=    Read Reg    ${RES_TIM7_CLR}
    Should Be Equal As Integers    ${v}    0

TIMG8 RIS Is 1 After ISET Software Trigger
    [Documentation]    Same flow as TIMG7 but on TIMG8 (IRQ 2, base 0x40090000).
    ${v}=    Read Reg    ${RES_TIM8_RIS}
    Should Be Equal As Integers    ${v}    1

TIMG8 RIS Is 0 After ICLR Write
    [Documentation]    Firmware writes ICLR bit0 on TIMG8; RIS must be 0.
    ${v}=    Read Reg    ${RES_TIM8_CLR}
    Should Be Equal As Integers    ${v}    0

*** Keywords ***
Prepare Machine
    [Documentation]    Build Renode machine with all 5 tested models.
    ...                Pre-inject 0x5A into UART0 RX buffer after PyDev load
    ...                (isInit fires on PyDevFromFile, not on LoadELF).
    Reset Emulation
    Execute Command    mach create "lp_mspm0g3507_missing"
    Execute Command    machine LoadPlatformDescription @${CURDIR}/../bsw/platform/bsw-mcal-msp/renode/mspm0g3507_periph.repl
    # Support models (SYSCTL needed for startup; GPIO for compatibility)
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_sysctl.py 0x400AF000 0x3000 False "sysctl"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_gpio.py 0x400A0000 0x2000 False "gpioA"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_gpio.py 0x400A2000 0x2000 False "gpioB"
    # 5 models under test
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_uart.py 0x40108000 0x2000 False "uart0"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_dma.py 0x4042A000 0x1400 False "dma"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_wwdt.py 0x40080000 0x1200 False "wwdt0"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_timg7.py 0x4086A000 0x2000 False "timg7"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_timg8.py 0x40090000 0x2000 False "timg8"
    # Pre-inject RX byte AFTER PyDevFromFile (isInit already fired) but BEFORE LoadELF
    Execute Command    sysbus WriteDoubleWord ${UART0_RXBUF_PUSH} 0x5A
    Execute Command    sysbus LoadELF @${ELF}
    Execute Command    emulation RunFor "00:00:00.200"

Read Reg
    [Documentation]    Read a 32-bit register and return as integer.
    [Arguments]        ${addr}
    ${raw}=    Execute Command    sysbus ReadDoubleWord ${addr}
    ${val}=    Convert To Integer    ${raw}    16
    [Return]   ${val}
