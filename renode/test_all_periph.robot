*** Settings ***
Documentation     LP-MSPM0G3507 all-peripheral SIL test suite.
...               Exercises all 15 new Renode Python peripheral models in one
...               firmware run using raw MMIO writes (no driverlib).
...
...               Peripheral model locations (PyDevFromFile base addresses):
...                 CRC       0x40440000  TRNG      0x40444000
...                 DAC0      0x40018000  VREF      0x40030000
...                 COMP0     0x40008000  OPA0      0x40020000
...                 MATHACL   0x40410000  WUC       0x40424000
...                 SPI0      0x40468000  I2C0      0x400F0000
...                 RTC       0x40094000  FLASHCTL  0x400CD000
...                 AES       0x40442000  TIMA0     0x40860000
...                 CANFD0    0x40508000 (size 0x8000)
Suite Setup       Setup
Suite Teardown    Teardown
Test Setup        Prepare Machine
Test Teardown     Test Teardown
Resource          ${RENODEKEYWORDS}

*** Variables ***
${ELF}           ${CURDIR}/../build/renode-driverlib-fullperiph/bsw_project_template.elf
${MODELS_DIR}    ${CURDIR}/../bsw-mcal-msp/renode/models

*** Test Cases ***
CRC CRCOUT Is Correct After CRCIN Write
    [Documentation]    Write SEED=0, CRCIN=0x01234567.
    ...                CRC-32 (poly 0xEDB88320) must yield 0x190EC766.
    ${v}=    Read Reg    0x40441108    # CRCIN (written by firmware, verifies write)
    Should Be Equal As Integers    ${v}    0x01234567
    ${v}=    Read Reg    0x4044110C    # CRCOUT
    Should Be Equal As Integers    ${v}    0x190EC766

TRNG DATA_CAPTURE Returns Non-Zero LFSR Value
    [Documentation]    After TRNG enable, reading DATA_CAPTURE must return
    ...                the first LFSR output (0xD6708000 from seed 0xACE10001).
    ${v}=    Read Reg    0x40445108    # DATA_CAPTURE (read advances LFSR)
    Should Be Equal As Integers    ${v}    0xD6708000

DAC0 DATA0 Reads Back Written Value
    [Documentation]    Firmware writes DATA0=0xABC; register must read back 0xABC.
    ${v}=    Read Reg    0x40019200    # DAC0 + 0x1200
    Should Be Equal As Integers    ${v}    0xABC

VREF CTL1 READY Is Set After Enable
    [Documentation]    Firmware spins on CTL1.READY after CTL0.ENABLE=1.
    ...                Test verifies READY bit is 1 (firmware would hang if not).
    ${v}=    Read Reg    0x40031104    # VREF + CTL1
    Should Be Equal As Integers    ${v}    1

COMP0 STAT OUT Is Zero By Default
    [Documentation]    Firmware enables COMP0 but does not inject output.
    ...                STAT.OUT must be 0 (no comparator output injected).
    ${v}=    Read Reg    0x40009120    # COMP0 + STAT
    Should Be Equal As Integers    ${v}    0

OPA0 STAT RDY Is Set After Enable
    [Documentation]    Firmware spins on STAT.RDY after CTL.ENABLE=1.
    ...                Test verifies RDY bit is 1 (firmware would hang if not).
    ${v}=    Read Reg    0x40021118    # OPA0 + STAT
    Should Be Equal As Integers    ${v}    1

MATHACL RES1 Is 30 After 5x6 Multiply
    [Documentation]    Write OP2=6, OP1=5 in MPY32 mode.
    ...                RES1 must read 30 (5*6).
    ${v}=    Read Reg    0x40411120    # MATHACL + RES1
    Should Be Equal As Integers    ${v}    30

WUC FSUB_0 Reads Back Written Value
    [Documentation]    Firmware writes FSUB_0=0x55; register must read back 0x55.
    ${v}=    Read Reg    0x40424400    # WUC + 0x400 (FSUB_0)
    Should Be Equal As Integers    ${v}    0x55

SPI0 RXDATA Returns Loopback TX Byte
    [Documentation]    Firmware writes TXDATA=0xA5; loopback pushes it to RX FIFO.
    ...                Reading RXDATA must return 0xA5.
    ${v}=    Read Reg    0x40469130    # SPI0 + 0x1130 (RXDATA)
    Should Be Equal As Integers    ${v}    0xA5

I2C0 RIS Shows MTXDONE And MSTOP After Transaction
    [Documentation]    Firmware performs a master write with START+STOP.
    ...                RIS must have MTXDONE(bit1)=1 and MSTOP(bit8)=1 → 0x102.
    ${v}=    Read Reg    0x400F1030    # I2C0 + 0x1030 (RIS)
    Should Be Equal As Integers    ${v}    0x102

RTC YEAR Is 2026 And RTCRDY Is Set
    [Documentation]    After RSTCTL, model restores YEAR=0x2026 and STA.RTCRDY=1.
    ${year}=    Read Reg    0x4009512C    # RTC + 0x112C (YEAR)
    Should Be Equal As Integers    ${year}    0x2026
    ${rdy}=     Read Reg    0x4009510C    # RTC + 0x110C (STA)
    Should Be Equal As Integers    ${rdy}     1

FLASHCTL STATCMD Shows CMDDONE And CMDPASS
    [Documentation]    Firmware executes PROGRAM command via CMDEXEC=1.
    ...                STATCMD must show CMDDONE(bit0)=1 and CMDPASS(bit1)=1 → 0x03.
    ${v}=    Read Reg    0x400CE3D0    # FLASHCTL + 0x13D0 (STATCMD)
    Should Be Equal As Integers    ${v}    3

AES Output Word 0 Matches Expected XOR
    [Documentation]    AES-128 ECB with null key: out[i] = in[i] XOR 0.
    ...                AESADOUT word 0 must be 0x01020304 (plaintext word 0).
    ${v}=    Read Reg    0x40443114    # AES + 0x1114 (AESADOUT)
    Should Be Equal As Integers    ${v}    0x01020304

TIMA0 LOAD And CC0 And DBCTL Read Back Correctly
    [Documentation]    Firmware writes LOAD=1999, CC0=999, DBCTL=10.
    ...                All three registers must read back the written values.
    ${load}=    Read Reg    0x40861808    # TIMA0 + 0x1808
    Should Be Equal As Integers    ${load}    1999
    ${cc0}=     Read Reg    0x40861810    # TIMA0 + 0x1810
    Should Be Equal As Integers    ${cc0}     999
    ${db}=      Read Reg    0x408618A4    # TIMA0 + 0x18A4 (DBCTL)
    Should Be Equal As Integers    ${db}      10

CANFD0 TXBTO Bit0 Set After TXBAR Request
    [Documentation]    Firmware writes TXBAR=1 (request buffer 0).
    ...                TXBTO must have bit0=1 (instant TX complete in SIL model).
    ${v}=    Read Reg    0x4050F0D8    # CANFD0 + 0x70D8 (TXBTO)
    Should Be Equal As Integers    ${v}    1

*** Keywords ***
Prepare Machine
    [Documentation]    Load all 15 peripheral models + run firmware.
    Reset Emulation
    Execute Command    mach create "lp_mspm0g3507_fullperiph"
    Execute Command    machine LoadPlatformDescription @${CURDIR}/../bsw/platform/bsw-mcal-msp/renode/mspm0g3507_periph.repl
    # Startup safety: SYSCTL + GPIO
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_sysctl.py 0x400AF000 0x3000 False "sysctl"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_gpio.py 0x400A0000 0x2000 False "gpioA"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_gpio.py 0x400A2000 0x2000 False "gpioB"
    # 15 new peripheral models
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_crc.py 0x40440000 0x2000 False "crc0"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_trng.py 0x40444000 0x2000 False "trng"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_dac.py 0x40018000 0x2000 False "dac0"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_vref.py 0x40030000 0x2000 False "vref"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_comp.py 0x40008000 0x2000 False "comp0"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_opa.py 0x40020000 0x2000 False "opa0"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_mathacl.py 0x40410000 0x2000 False "mathacl"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_wuc.py 0x40424000 0x2000 False "wuc"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_spi.py 0x40468000 0x2000 False "spi0"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_i2c.py 0x400F0000 0x2000 False "i2c0"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_rtc.py 0x40094000 0x2000 False "rtc"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_flashctl.py 0x400CD000 0x2000 False "flashctl"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_aes.py 0x40442000 0x2000 False "aes"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_tima.py 0x40860000 0x2000 False "tima0"
    Execute Command    machine PyDevFromFile @${MODELS_DIR}/mspm0_canfd.py 0x40508000 0x8000 False "canfd0"
    Execute Command    sysbus LoadELF @${ELF}
    Execute Command    emulation RunFor "00:00:00.200"

Read Reg
    [Documentation]    Read a 32-bit register and return as integer.
    [Arguments]        ${addr}
    ${raw}=    Execute Command    sysbus ReadDoubleWord ${addr}
    ${val}=    Convert To Integer    ${raw}    16
    [Return]   ${val}
