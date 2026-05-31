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
set(PLATFORM     "target"        CACHE STRING "Build platform: target | posix | renode")
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
    # Suppress BSW's bundled examples/tutorials/tests — they reference
    # framework symbols (debug_*, mem_*, dispatch_*) that aren't linked
    # by this template and would fail link otherwise.
    set(BUILD_EXAMPLES  OFF CACHE BOOL "" FORCE)
    set(BUILD_TESTS     OFF CACHE BOOL "" FORCE)
    set(BUILD_TUTORIALS OFF CACHE BOOL "" FORCE)
    add_subdirectory(${BSW_DIR})

    # BSW's bsw target hardcodes its include dirs and doesn't merge in
    # platform-specific paths from FW_INCLUDES. For PLATFORM=mspm0 that
    # means hal.h can't find hal_device.h — patch it post-hoc.
    if(PLATFORM STREQUAL "mspm0")
        set(_MSP_HAL_INCLUDES
            ${BSW_DIR}/platform/bsw-mcal-msp/legacy/hal
            ${BSW_DIR}/platform/bsw-mcal-msp/system
            ${BSW_DIR}/platform/bsw-mcal-msp/sdk
            ${BSW_DIR}/platform/bsw-mcal-msp/sdk/third_party/CMSIS/Core/Include
        )
        foreach(_tgt bsw mcal_hal mcal_mspm0 mcal_msp cdd_msp)
            if(TARGET ${_tgt})
                target_include_directories(${_tgt} PUBLIC ${_MSP_HAL_INCLUDES})
            endif()
        endforeach()
    endif()
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
    add_executable(${PROJECT_NAME}
        src/main.c
        src/led_blink.c
    )
    # MSPM0 SysConfig boot init (SYSCFG_DL_init) — BSW ships the source
    # file but doesn't link it into mcal_msp, so wire it up here.
    if(PLATFORM STREQUAL "mspm0")
        target_sources(${PROJECT_NAME} PRIVATE
            ${BSW_DIR}/platform/bsw-mcal-msp/system/ti_msp_dl_config.c
        )
    endif()
    # Renode SIL needs a real Cortex-M0+ vector table + reset handler
    # at 0x0, plus our own linker script matching the .repl geometry.
    if(PLATFORM STREQUAL "renode")
        # ASM language is enabled by the toolchain; explicitly add the file.
        enable_language(ASM)
        target_sources(${PROJECT_NAME} PRIVATE
            ${BSW_DIR}/legacy/framework/hal/cortex-m/startup_m0plus.S
        )
        target_link_options(${PROJECT_NAME} PRIVATE
            -T${CMAKE_SOURCE_DIR}/renode/renode_sil.ld
            -nostartfiles
        )
    endif()
    # Force .elf suffix for the firmware artifact so renode-test scripts
    # (and downstream flashers) can find a consistent path.
    if(NOT PLATFORM STREQUAL "posix")
        set_target_properties(${PROJECT_NAME} PROPERTIES SUFFIX ".elf")
    endif()
    if(NOT PLATFORM STREQUAL "posix")
        # Upstream BSW exposes the targets `bsw` + `mcal_hal` (renode/sil) and
        # `mcal_msp` (real mspm0 hardware). The template-doc-claimed
        # `bsw_core`/`bsw_mcal` aliases + `BSW_INCLUDE_DIRS` variable do not
        # exist, so we wire up include dirs explicitly here.
        # Wrap in --start-group/--end-group: bsw and mcal_* call each
        # other (e.g. mcal_hal/Dio.c → Det_ReportError in bsw), so single-
        # pass static link order isn't enough.
        # For real silicon (PLATFORM=mspm0) we additionally link the
        # platform-specific MCAL implementation (mcal_msp) and the
        # prebuilt TI driverlib for MSPM0G3507.
        if(PLATFORM STREQUAL "mspm0")
            set(_MSP_DRIVERLIB
                ${BSW_DIR}/platform/bsw-mcal-msp/sdk/ti/driverlib/lib/gcc/m0p/mspm0g1x0x_g3x0x/driverlib.a)
            target_link_libraries(${PROJECT_NAME} PRIVATE
                -Wl,--start-group
                mcal_msp
                mcal_hal
                mcal_mspm0
                bsw
                ${_MSP_DRIVERLIB}
                -Wl,--end-group
            )
        else()
            target_link_libraries(${PROJECT_NAME} PRIVATE
                -Wl,--start-group
                mcal_hal
                bsw
                -Wl,--end-group
            )
        endif()
        target_include_directories(${PROJECT_NAME} PRIVATE
            ${BSW_DIR}/legacy/framework/autosar
            ${BSW_DIR}/legacy/mcal/hal/Dio
            ${BSW_DIR}/legacy/mcal/hal/Mcu
        )
    else()
        target_include_directories(${PROJECT_NAME} PRIVATE tests/mock)
    endif()

    # Post-build artefacts
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${CMAKE_OBJCOPY} -O binary
            $<TARGET_FILE:${PROJECT_NAME}> ${PROJECT_NAME}.bin
        COMMAND ${CMAKE_OBJCOPY} -O ihex
            $<TARGET_FILE:${PROJECT_NAME}> ${PROJECT_NAME}.hex
        COMMENT "Generating .bin / .hex"
    )

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
