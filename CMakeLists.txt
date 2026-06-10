cmake_minimum_required(VERSION 3.20)

project(bsw_project_template
    VERSION 0.1.0
    DESCRIPTION "BSW Project Template — LP-MSPM0G Hello World"
    LANGUAGES C ASM
)

######################################
# Options
######################################
set(BOARD        "lp_mspm0g3507" CACHE STRING "Target board (boards/*.yaml)")
set(BSW_PLATFORM "bsw-mcal-msp"  CACHE STRING "BSW platform submodule")
set(PYOCD_TARGET "MSPM0G3507"    CACHE STRING "pyOCD target name")
set(PLATFORM     "mspm0"         CACHE STRING "Build platform — passed to BSW: posix | mspm0 | traveo")
set(APP_MODEL    "baremetal"     CACHE STRING "App entry model: baremetal | oslite | osrte")
option(BUILD_TESTS "Build unit tests (host build only)" OFF)

if(BUILD_TESTS)
    enable_testing()
endif()

######################################
# Board compile definition
######################################
string(TOUPPER ${BOARD} BOARD_UPPER)
add_compile_definitions(BOARD_${BOARD_UPPER})

# Map BOARD to chip-specific defines
if(BOARD STREQUAL "lp_mspm0g3507")
    set(MSPM0_CHIP_DEFINE "__MSPM0G3507__")
    set(MSPM0_CHIP_FAMILY "G")
elseif(BOARD STREQUAL "lp_mspm0c1104")
    set(MSPM0_CHIP_DEFINE "__MSPM0C1104__")
    set(MSPM0_CHIP_FAMILY "C")
else()
    message(FATAL_ERROR "Unknown BOARD=${BOARD}")
endif()

######################################
# Framework configuration (SRAM-tunable)
#
# Override via CMakePresets.json or -DFW_<VAR>=<value>.
# Non-empty values are passed as compile definitions to
# BSW targets, overriding #ifndef defaults in framework_config.h.
# Leave empty ("") to use the header's built-in default.
######################################
set(FW_HEAP_SIZE              "" CACHE STRING "Heap size in bytes")
set(FW_OS_IDLE_STACK_SIZE     "" CACHE STRING "OS idle task stack size in bytes")
set(FW_OS_STACK_SIZE          "" CACHE STRING "OS task stack size in bytes")
set(FW_OS_MAX_TASKS           "" CACHE STRING "Max OS tasks")
set(FW_OS_MAX_ALARMS          "" CACHE STRING "Max OS alarms")
set(FW_OS_MAX_RESOURCES       "" CACHE STRING "Max OS resources")
set(FW_MAX_TASKS              "" CACHE STRING "Max scheduler tasks")
set(FW_MAX_EVENTS             "" CACHE STRING "Max events")
set(FW_DBG_QUEUE_SIZE         "" CACHE STRING "Debug queue size in bytes")
set(FW_DBG_BUF_SIZE           "" CACHE STRING "Debug format buffer size in bytes")
set(FW_RTE_MAX_PORTS          "" CACHE STRING "RTE max ports")
set(FW_RTE_MAX_PORT_DATA_SIZE "" CACHE STRING "RTE max port data size in bytes")
set(FW_BUFFER_SIZE_UP         "" CACHE STRING "RTT upstream buffer size in bytes")
set(FW_BUFFER_SIZE_DOWN       "" CACHE STRING "RTT downstream buffer size in bytes")
set(FW_PORT_MAX_PINS          "" CACHE STRING "Max GPIO pins per port")
set(FW_ISOTP_BUFFER_SIZE      "" CACHE STRING "ISO-TP buffer size in bytes")
set(FW_J1939_MESSAGE_POOL_SIZE "" CACHE STRING "J1939 message pool size")
set(FW_J1939_MESSAGE_DATA_SIZE "" CACHE STRING "J1939 message data size in bytes")
set(FW_CAN_TX_QUEUE_SIZE      "" CACHE STRING "CAN TX queue depth")

# Build the list of compile-definition overrides from non-empty FW_ variables.
set(_fw_cfg_defs "")
macro(_fw_cfg var def)
    if(NOT "${${var}}" STREQUAL "")
        list(APPEND _fw_cfg_defs "${def}=${${var}}")
    endif()
endmacro()
_fw_cfg(FW_HEAP_SIZE              HEAP_SIZE)
_fw_cfg(FW_OS_IDLE_STACK_SIZE     OS_IDLE_STACK_SIZE)
_fw_cfg(FW_OS_STACK_SIZE          OS_STACK_SIZE)
_fw_cfg(FW_OS_MAX_TASKS           OS_MAX_TASKS)
_fw_cfg(FW_OS_MAX_ALARMS          OS_MAX_ALARMS)
_fw_cfg(FW_OS_MAX_RESOURCES       OS_MAX_RESOURCES)
_fw_cfg(FW_MAX_TASKS              MAX_TASKS)
_fw_cfg(FW_MAX_EVENTS             MAX_EVENTS)
_fw_cfg(FW_DBG_QUEUE_SIZE         DBG_QUEUE_SIZE)
_fw_cfg(FW_DBG_BUF_SIZE           DBG_BUF_SIZE)
_fw_cfg(FW_RTE_MAX_PORTS          RTE_MAX_PORTS)
_fw_cfg(FW_RTE_MAX_PORT_DATA_SIZE RTE_MAX_PORT_DATA_SIZE)
_fw_cfg(FW_BUFFER_SIZE_UP         BUFFER_SIZE_UP)
_fw_cfg(FW_BUFFER_SIZE_DOWN       BUFFER_SIZE_DOWN)
_fw_cfg(FW_PORT_MAX_PINS          PORT_MAX_PINS)
_fw_cfg(FW_ISOTP_BUFFER_SIZE      ISOTP_BUFFER_SIZE)
_fw_cfg(FW_J1939_MESSAGE_POOL_SIZE J1939_MESSAGE_POOL_SIZE)
_fw_cfg(FW_J1939_MESSAGE_DATA_SIZE J1939_MESSAGE_DATA_SIZE)
_fw_cfg(FW_CAN_TX_QUEUE_SIZE      CAN_TX_QUEUE_SIZE)

######################################
# BSW + platform MCAL (firmware build only)
######################################
if(NOT PLATFORM STREQUAL "posix")
    set(BSW_DIR "${CMAKE_SOURCE_DIR}/bsw")
    if(NOT EXISTS "${BSW_DIR}/CMakeLists.txt")
        message(FATAL_ERROR
            "BSW submodule not initialized.\n"
            "Run: git submodule update --init bsw")
    endif()
    # The template builds only its own LED-blink executable; BSW examples /
    # tests / tutorials are unrelated to this build.
    set(BUILD_EXAMPLES  OFF CACHE BOOL "" FORCE)
    set(BUILD_TESTS     OFF CACHE BOOL "" FORCE)
    set(BUILD_TUTORIALS OFF CACHE BOOL "" FORCE)

    # Platform MCAL — sibling submodule (bsw-mcal-<platform>). Publish
    # MCAL_MSP_DIR BEFORE add_subdirectory(${BSW_DIR}) so the framework picks
    # up the sibling path instead of the obsolete bsw/platform/bsw-mcal-msp
    # fallback (sibling submodule promotion: bsw commit 8e40779).
    if(PLATFORM STREQUAL "mspm0")
        set(_mcal_dir "${CMAKE_SOURCE_DIR}/bsw-mcal-msp")
        if(NOT EXISTS "${_mcal_dir}/CMakeLists.txt")
            message(FATAL_ERROR
                "bsw-mcal-msp submodule not initialized.\n"
                "Run: git submodule update --init bsw-mcal-msp")
        endif()
        set(MCAL_MSP_DIR "${_mcal_dir}")
        # Activate codegen: YAML → Dio_Cfg / Port_Cfg / Mcu_Cfg auto-generation.
        set(BOARD_CONFIG_YAML "${CMAKE_SOURCE_DIR}/boards/${BOARD}.yaml")
    endif()

    # BSW submodule expects APP_MODEL=rte_os for full AUTOSAR builds.
    # Map osrte → rte_os before entering the submodule scope, then restore.
    set(_saved_app_model "${APP_MODEL}")
    if(APP_MODEL STREQUAL "osrte")
        set(APP_MODEL "rte_os")
    endif()

    add_subdirectory(${BSW_DIR})

    set(APP_MODEL "${_saved_app_model}")

    if(PLATFORM STREQUAL "mspm0")
        add_subdirectory(${_mcal_dir} bsw_mcal_msp)
    endif()

    # Apply framework configuration overrides to BSW targets.
    # These -D flags take precedence over #ifndef defaults in
    # framework_config.h, Rte.h, Port.h, rtt_conf.h, etc.
    if(_fw_cfg_defs)
        target_compile_definitions(bsw PUBLIC ${_fw_cfg_defs})
        target_compile_definitions(bsw_platform_bsp PUBLIC ${_fw_cfg_defs})
        if(PLATFORM STREQUAL "mspm0")
            target_compile_definitions(mcal_msp PUBLIC ${_fw_cfg_defs})
        endif()
    endif()
endif()

######################################
# Firmware application
######################################
if(NOT BUILD_TESTS)
    if(APP_MODEL STREQUAL "oslite")
        set(_app_sources src/main_oslite.c)
        # Os_Lite (header + .c) is owned by bsw — it ships Os_Lite.c
        # in libbsw.a and publishes OS_USE_LITE PUBLIC, so this block
        # only needs to pick the application entry point.
    elseif(APP_MODEL STREQUAL "osrte")
        # Full AUTOSAR stack — BSW Rte + Os (Task + Alarm). Pulls in the
        # bsw framework lib for real (not stripped by gc-sections) since the
        # symbols Os_Init / Rte_Init / EcuM_Init / Os_StartOS are called.
        set(_app_sources src/main_osrte.c)
    elseif(APP_MODEL STREQUAL "periph_test")
        # Standalone peripheral test — no BSW app framework, driverlib only.
        set(_app_sources tests/sil/main_periph_test.c)
    elseif(APP_MODEL STREQUAL "fullperiph_test")
        # All-peripheral SIL test — raw MMIO, no driverlib or BSW framework.
        set(_app_sources tests/sil/main_fullperiph_test.c)
    elseif(APP_MODEL STREQUAL "missing_periph_test")
        # UART/DMA/WWDT/TIMG7/TIMG8 SIL test — raw MMIO, no driverlib or BSW framework.
        set(_app_sources tests/sil/main_missing_periph_test.c)
    elseif(APP_MODEL STREQUAL "timg_test")
        # TIMG0/TIMG6/TIMG12 IRQ model test + ADC1 — raw MMIO.
        set(_app_sources tests/sil/main_timg_test.c)
    else()
        set(_app_sources src/main_baremetal.c)
    endif()
    set(_is_periph_test OFF)
    if(APP_MODEL STREQUAL "periph_test"
       OR APP_MODEL STREQUAL "fullperiph_test"
       OR APP_MODEL STREQUAL "missing_periph_test"
       OR APP_MODEL STREQUAL "timg_test")
        set(_is_periph_test ON)
    endif()
    if(NOT _is_periph_test)
        # Application SWCs + per-style RTE backend.
        # SWCs are bit-identical across baremetal / oslite / osrte; the
        # selected RTE backend is the only thing that differs.
        # Cfg .c files come from codegen (mcal_cfg/) when BOARD_CONFIG_YAML
        # is set, otherwise fall back to hand-written src/cfg/.
        set(_cfg_dir "${CMAKE_BINARY_DIR}/mcal_cfg")
        if(DEFINED BOARD_CONFIG_YAML AND EXISTS "${BOARD_CONFIG_YAML}")
            set(_cfg_c_files ${_cfg_dir}/Port_Cfg.c ${_cfg_dir}/Dio_Cfg.c)
            set_source_files_properties(${_cfg_c_files} PROPERTIES GENERATED TRUE)
        else()
            set(_cfg_c_files src/cfg/Port_Cfg.c src/cfg/Dio_Cfg.c)
        endif()
        list(APPEND _app_sources
            src/swc/Swc_ModeSelector.c
            src/swc/Swc_LedBlink.c
            ${_cfg_c_files}
        )
        if(APP_MODEL STREQUAL "osrte")
            list(APPEND _app_sources src/rte/bsw/Rte_Impl.c)
        else()
            list(APPEND _app_sources src/rte/static/Rte_Impl.c)
        endif()
    endif()
    # Board layer (mspm0 — both real silicon and Renode SIL targets). Provides:
    #   - Cortex-M0+ startup file (vector table, Reset_Handler) from SDK
    #   - SDK SysConfig + board syscfg_lp.c overrides
    #   - Standalone linker script (vector table at 0x00000000, SRAM at
    #     0x20200000) — shared with the LP launchpad rgb_led_pwm demo.
    # Renode is a simulator that runs the same mspm0 firmware; it is not a
    # separate build platform.
    set(_msp_dir "${CMAKE_SOURCE_DIR}/bsw-mcal-msp")
    if(PLATFORM STREQUAL "mspm0")
        if(MSPM0_CHIP_FAMILY STREQUAL "G")
            set(_startup_file "${_msp_dir}/sdk/ti/devices/msp/m0p/startup_system_files/gcc/startup_mspm0g350x_gcc.c")
        elseif(MSPM0_CHIP_FAMILY STREQUAL "C")
            set(_startup_file "${_msp_dir}/sdk/ti/devices/msp/m0p/startup_system_files/gcc/startup_mspm0c110x_gcc.c")
        endif()
        list(APPEND _app_sources "${_startup_file}")
        if(NOT _is_periph_test)
            # Board SYSCFG_DL_init overrides — not needed for periph_test which
            # initialises peripherals directly via driverlib (no BSW framework).
            set(_board_dir "${CMAKE_SOURCE_DIR}/boards/${BOARD}")
            if(NOT EXISTS "${_board_dir}/syscfg_lp.c")
                message(FATAL_ERROR
                    "Board file missing: ${_board_dir}/syscfg_lp.c\n"
                    "Each BOARD must ship its own SYSCFG_DL_init overrides.")
            endif()
            list(APPEND _app_sources
                "${_msp_dir}/system/ti_msp_dl_config.c"
                "${_board_dir}/syscfg_lp.c")
        endif()
        # TI MSPM0 driverlib — bsw-mcal-msp ships the headers and .c files
        # but does not compile them. Build a static library here so the
        # firmware can resolve DL_Common_delayCycles, DL_Timer_*, DL_GPIO_*
        # etc. that the SDK SysConfig and syscfg_lp.c reference.
        file(GLOB _msp_driverlib_sources "${_msp_dir}/sdk/ti/driverlib/*.c")
        add_library(ti_driverlib STATIC ${_msp_driverlib_sources})
        target_include_directories(ti_driverlib PUBLIC
            "${_msp_dir}/sdk"
            "${_msp_dir}/sdk/third_party/CMSIS/Core/Include"
            "${_msp_dir}/sdk/ti/devices"
            "${_msp_dir}/sdk/ti/driverlib")
        target_compile_definitions(ti_driverlib PUBLIC
            PLATFORM_MSPM0 ${MSPM0_CHIP_DEFINE} __ARM_ARCH_6M__ __FPU_PRESENT=0)
    endif()
    if(PLATFORM STREQUAL "mspm0")
        # Board-specific GPIO and clock config.
        # MCU_HW_SYSTICK_WEAK intentionally omitted: syscfg_lp.c does NOT
        # define SysTick_Handler, so Mcu_Hw.c must provide a strong definition
        # to override the startup file's weak Default_Handler alias.
        string(TOUPPER ${BOARD} _lp_board_upper)
        string(REPLACE "-" "_" _lp_board_upper "${_lp_board_upper}")
        target_compile_definitions(mcal_msp PUBLIC ${_lp_board_upper})
    endif()
    add_executable(${PROJECT_NAME} ${_app_sources})
    if(NOT _is_periph_test)
        # App-side include paths (SWC + Rte).
        # Cfg headers come from codegen (mcal_cfg/) via mcal_msp PUBLIC
        # include, or fall back to hand-written src/cfg/.
        target_include_directories(${PROJECT_NAME} PRIVATE
            "${CMAKE_SOURCE_DIR}/src/swc"
            "${CMAKE_SOURCE_DIR}/src/rte")
        if(NOT DEFINED BOARD_CONFIG_YAML OR NOT EXISTS "${BOARD_CONFIG_YAML}")
            target_include_directories(${PROJECT_NAME} PRIVATE
                "${CMAKE_SOURCE_DIR}/src/cfg")
        endif()
        # Ensure codegen runs before compiling app sources.
        if(TARGET mcal_cfg_gen)
            add_dependencies(${PROJECT_NAME} mcal_cfg_gen)
        endif()
    endif()
    # Os_Lite.h lives in bsw's autosar/ PUBLIC include dir now, so
    # APP_MODEL=oslite no longer needs a side include path.
    if(PLATFORM STREQUAL "mspm0")
        # Include paths for syscfg_lp.c + ti_msp_dl_config.c + startup file
        # to find ti_msp_dl_config.h and the SDK headers.
        target_include_directories(${PROJECT_NAME} PRIVATE
            "${_msp_dir}/system"
            "${_msp_dir}/legacy/hal"
            "${_msp_dir}/sdk"
            "${_msp_dir}/sdk/third_party/CMSIS/Core/Include"
            "${_msp_dir}/sdk/ti/devices"
            "${_msp_dir}/sdk/ti/driverlib")
        target_compile_definitions(${PROJECT_NAME} PRIVATE
            PLATFORM_MSPM0 ${MSPM0_CHIP_DEFINE} __ARM_ARCH_6M__ __FPU_PRESENT=0)
        # Note: ti_driverlib is re-linked at the END of the libraries
        # list below so it can resolve DL_Timer_* / DL_GPIO_* / …
        # references coming out of mcal_msp (Gpt_Hw.c etc.). Order
        # matters for static archive linkers.
        target_link_libraries(${PROJECT_NAME} PRIVATE ti_driverlib)
        if(MSPM0_CHIP_FAMILY STREQUAL "G")
            set(_linker_script "${_msp_dir}/examples/rgb_led_pwm/mspm0g3507.ld")
        elseif(MSPM0_CHIP_FAMILY STREQUAL "C")
            set(_linker_script "${_msp_dir}/sdk/ti/devices/msp/m0p/linker_files/gcc/mspm0c1104.lds")
        endif()
        target_link_options(${PROJECT_NAME} PRIVATE
            "-T${_linker_script}"
            "-Wl,-Map=${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.map")
        if(MSPM0_CHIP_FAMILY STREQUAL "C")
            # MSPM0C has only 1 KiB SRAM — use newlib-nano to shrink impure_data
            target_link_options(${PROJECT_NAME} PRIVATE "--specs=nano.specs")
        endif()
        set_target_properties(${PROJECT_NAME} PROPERTIES
            LINK_DEPENDS "${_linker_script}")
    endif()
    # Application links the BSW framework + the True MCAL implementation for
    # the chosen PLATFORM. mcal_hal is BSW-internal legacy (HAL-wrapping); new
    # applications go through the MCAL contract headers (Mcu.h/Dio.h/Os.h/...)
    # provided directly by mcal_<platform>.
    # periph_test uses TI driverlib directly; no BSW or MCAL layer is linked.
    if(_is_periph_test)
        # driverlib-only; ti_driverlib already linked above via the mspm0 block
    elseif(PLATFORM STREQUAL "mspm0")
        # mspm0: mcal_msp (from bsw-mcal-msp submodule) ships the full AUTOSAR
        # contract (Dio_Hw.c, …) AND the low-level hal_*.c for this platform.
        # mcal_mspm0 (in BSW framework) provides only mcal/mspm0/*_Hw.c overrides.
        target_link_libraries(${PROJECT_NAME} PRIVATE bsw mcal_mspm0 mcal_msp
            ti_driverlib)
        # osrte no longer pulls any bsw-mcal-msp/legacy/hal/*.c file:
        #   - dispatch.c / Rte.c (the old hal_critical / hal_system /
        #     hal_mem consumers) are excluded by bsw CMake when
        #     APP_MODEL=rte_os; Rte_bcc1.c replaces Rte.c's surface.
        #   - critical.h's CRITICAL_SECTION_ENTER/EXIT macros now expand
        #     inline to PRIMASK assembly, so debug.c / mem.c / pool.c
        #     don't need hal_critical.c either.
        #   - debug.c's hal_system_get_time call was migrated to
        #     Os_GetCounterValue.
        # docs/upstream-issues.md Issue #1 is therefore unblocked at
        # the source level -- no shim file required on the template
        # side either.
    elseif(PLATFORM STREQUAL "traveo")
        # Traveo target hookup left for the platform owner; mcal_traveo is the
        # BSW-side stub. The Infineon PDL target name to link is project-specific.
        target_link_libraries(${PROJECT_NAME} PRIVATE bsw mcal_traveo)
    elseif(PLATFORM STREQUAL "posix")
        target_include_directories(${PROJECT_NAME} PRIVATE tests/mock)
    else()
        message(FATAL_ERROR "Unknown PLATFORM=${PLATFORM} (expected: posix | mspm0 | traveo)")
    endif()

    # Post-build artefacts (skip for host build — objcopy is bare-metal only)
    if(NOT PLATFORM STREQUAL "posix")
        add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
            COMMAND ${CMAKE_OBJCOPY} -O binary
                $<TARGET_FILE:${PROJECT_NAME}> ${PROJECT_NAME}.bin
            COMMAND ${CMAKE_OBJCOPY} -O ihex
                $<TARGET_FILE:${PROJECT_NAME}> ${PROJECT_NAME}.hex
            COMMAND ${CMAKE_COMMAND} -E copy
                $<TARGET_FILE:${PROJECT_NAME}> ${PROJECT_NAME}.elf
            COMMENT "Generating .bin / .hex / .elf"
        )
    endif()

    # Flash via pyOCD: ninja flash
    add_custom_target(flash
        COMMAND pyocd flash --target ${PYOCD_TARGET}
            $<TARGET_FILE:${PROJECT_NAME}>
        DEPENDS ${PROJECT_NAME}
        COMMENT "Flashing via pyOCD (target=${PYOCD_TARGET})"
    )
endif()

######################################
# Unit tests (host build)
######################################
if(BUILD_TESTS)
    add_subdirectory(tests)
endif()
