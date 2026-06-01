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
set(PLATFORM     "mspm0"         CACHE STRING "Build platform — passed to BSW: posix | mspm0 | renode | traveo")
set(APP_MODEL    "baremetal"     CACHE STRING "App entry model: baremetal | oslite")
option(BUILD_TESTS "Build unit tests (host build only)" OFF)

if(BUILD_TESTS)
    enable_testing()
endif()

######################################
# BSW submodule (firmware build only)
######################################
if(NOT PLATFORM STREQUAL "posix")
    set(BSW_DIR "${CMAKE_SOURCE_DIR}/bsw")
    if(NOT EXISTS "${BSW_DIR}/CMakeLists.txt")
        message(FATAL_ERROR
            "BSW submodule not initialized.\n"
            "Run: _shared/bootstrap.sh --platform ${BSW_PLATFORM}  (Linux/macOS)\n"
            "  or _shared\\bootstrap.ps1 -Platform ${BSW_PLATFORM}  (Windows)")
    endif()
    # The template builds only its own LED-blink executable; BSW examples /
    # tests / tutorials are unrelated to this build.
    set(BUILD_EXAMPLES  OFF CACHE BOOL "" FORCE)
    set(BUILD_TESTS     OFF CACHE BOOL "" FORCE)
    set(BUILD_TUTORIALS OFF CACHE BOOL "" FORCE)
    add_subdirectory(${BSW_DIR})
endif()

######################################
# Board compile definition
######################################
string(TOUPPER ${BOARD} BOARD_UPPER)
add_compile_definitions(BOARD_${BOARD_UPPER})

######################################
# Firmware application
######################################
if(NOT BUILD_TESTS)
    if(APP_MODEL STREQUAL "oslite")
        set(_app_sources src/main_oslite.c)
        add_compile_definitions(OS_USE_LITE)
        # Os_Lite.c is not part of mcal_msp; compile it here
        list(APPEND _app_sources
            "${CMAKE_SOURCE_DIR}/bsw/platform/${BSW_PLATFORM}/src/Os_Lite.c")
    elseif(APP_MODEL STREQUAL "periph_test")
        # Standalone peripheral test — no BSW app framework, driverlib only.
        set(_app_sources src/main_periph_test.c)
    else()
        set(_app_sources src/main_baremetal.c)
    endif()
    if(NOT APP_MODEL STREQUAL "periph_test")
        # Shared application sources (baremetal + oslite only)
        list(APPEND _app_sources
            src/app_tasks.c
            src/app_mode.c
            src/led_blink.c
        )
    endif()
    if(NOT PLATFORM STREQUAL "posix" AND NOT APP_MODEL STREQUAL "periph_test")
        list(APPEND _app_sources src/app_stubs.c)
    endif()
    # Board layer (mspm0 + renode SIL both target the MSPM0G3507 silicon
    # model). Provides:
    #   - Cortex-M0+ startup file (vector table, Reset_Handler) from SDK
    #   - SDK SysConfig + board syscfg_lp.c overrides
    #   - Standalone linker script (vector table at 0x00000000, SRAM at
    #     0x20200000) — shared with the LP launchpad rgb_led_pwm demo.
    # Renode SIL uses the same startup and linker script as mspm0, but
    # links mcal_renode instead of mcal_msp/driverlib for HW access.
    set(_msp_dir "${CMAKE_SOURCE_DIR}/bsw/platform/bsw-mcal-msp")
    if(PLATFORM STREQUAL "mspm0" OR PLATFORM STREQUAL "renode")
        list(APPEND _app_sources
            "${_msp_dir}/sdk/ti/devices/msp/m0p/startup_system_files/gcc/startup_mspm0g350x_gcc.c")
        if(NOT APP_MODEL STREQUAL "periph_test")
            # Board SYSCFG_DL_init overrides — not needed for periph_test which
            # initialises peripherals directly via driverlib (no BSW framework).
            set(_board_dir "${CMAKE_SOURCE_DIR}/boards/${BOARD}")
            if(NOT EXISTS "${_board_dir}/syscfg_lp.c")
                message(FATAL_ERROR
                    "Board file missing: ${_board_dir}/syscfg_lp.c\n"
                    "Each mspm0g* BOARD must ship its own SYSCFG_DL_init overrides.")
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
            PLATFORM_MSPM0 __MSPM0G3507__ __ARM_ARCH_6M__ __FPU_PRESENT=0)
    endif()
    if(PLATFORM STREQUAL "mspm0")
        # LP_MSPM0G3507: board-specific GPIO and clock config.
        # MCU_HW_SYSTICK_WEAK intentionally omitted: syscfg_lp.c does NOT
        # define SysTick_Handler, so Mcu_Hw.c must provide a strong definition
        # to override the startup file's weak Default_Handler alias.
        target_compile_definitions(mcal_msp PUBLIC LP_MSPM0G3507)
    endif()
    add_executable(${PROJECT_NAME} ${_app_sources})
    if(APP_MODEL STREQUAL "oslite")
        target_include_directories(${PROJECT_NAME} PRIVATE
            "${CMAKE_SOURCE_DIR}/bsw/platform/${BSW_PLATFORM}/include")
    endif()
    if(PLATFORM STREQUAL "mspm0" OR PLATFORM STREQUAL "renode")
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
            PLATFORM_MSPM0 __MSPM0G3507__ __ARM_ARCH_6M__ __FPU_PRESENT=0)
        target_link_libraries(${PROJECT_NAME} PRIVATE ti_driverlib)
        set(_linker_script
            "${_msp_dir}/examples/rgb_led_pwm/mspm0g3507.ld")
        target_link_options(${PROJECT_NAME} PRIVATE
            "-T${_linker_script}"
            "-Wl,-Map=${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.map")
        set_target_properties(${PROJECT_NAME} PROPERTIES
            LINK_DEPENDS "${_linker_script}")
    endif()
    # Application links the BSW framework + the True MCAL implementation for
    # the chosen PLATFORM. mcal_hal is BSW-internal legacy (HAL-wrapping); new
    # applications go through the MCAL contract headers (Mcu.h/Dio.h/Os.h/...)
    # provided directly by mcal_<platform>.
    # periph_test uses TI driverlib directly; no BSW or MCAL layer is linked.
    if(APP_MODEL STREQUAL "periph_test")
        # driverlib-only; ti_driverlib already linked above via the mspm0/renode block
    elseif(PLATFORM STREQUAL "mspm0")
        # mspm0: mcal_msp (from bsw-mcal-msp submodule) ships the full AUTOSAR
        # contract (Dio_Hw.c, …) AND the low-level hal_*.c for this platform.
        # mcal_mspm0 (in BSW framework) provides only mcal/mspm0/*_Hw.c overrides.
        target_link_libraries(${PROJECT_NAME} PRIVATE bsw mcal_mspm0 mcal_msp)
    elseif(PLATFORM STREQUAL "renode")
        target_link_libraries(${PROJECT_NAME} PRIVATE bsw mcal_renode)
    elseif(PLATFORM STREQUAL "traveo")
        # Traveo target hookup left for the platform owner; mcal_traveo is the
        # BSW-side stub. The Infineon PDL target name to link is project-specific.
        target_link_libraries(${PROJECT_NAME} PRIVATE bsw mcal_traveo)
    elseif(PLATFORM STREQUAL "posix")
        target_include_directories(${PROJECT_NAME} PRIVATE tests/mock)
    else()
        message(FATAL_ERROR "Unknown PLATFORM=${PLATFORM} (expected: posix | mspm0 | renode | traveo)")
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
