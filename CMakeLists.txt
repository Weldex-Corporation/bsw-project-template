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
    set(_app_sources
        src/main.c
        src/led_blink.c
    )
    if(NOT PLATFORM STREQUAL "posix")
        list(APPEND _app_sources src/app_stubs.c)
    endif()
    # Board layer (PLATFORM=mspm0 only for now): provides SYSCFG_DL_init
    # overrides + SysTick handler for the chosen ${BOARD}.
    if(PLATFORM STREQUAL "mspm0")
        set(_board_dir "${CMAKE_SOURCE_DIR}/boards/${BOARD}")
        if(EXISTS "${_board_dir}/syscfg_lp.c")
            list(APPEND _app_sources "${_board_dir}/syscfg_lp.c")
        else()
            message(FATAL_ERROR
                "Board file missing: ${_board_dir}/syscfg_lp.c\n"
                "Each mspm0 BOARD must ship its own SYSCFG_DL_init overrides.")
        endif()
        # TI MSPM0 driverlib — bsw-mcal-msp ships the headers and .c files
        # but does not compile them. Build a static library here so the
        # firmware can resolve DL_Common_delayCycles, DL_Timer_*, DL_GPIO_*
        # etc. that mcal_msp and the board init reference.
        set(_msp_driverlib_dir
            "${CMAKE_SOURCE_DIR}/bsw/platform/bsw-mcal-msp/sdk/ti/driverlib")
        file(GLOB _msp_driverlib_sources "${_msp_driverlib_dir}/*.c")
        add_library(ti_driverlib STATIC ${_msp_driverlib_sources})
        target_include_directories(ti_driverlib PUBLIC
            "${CMAKE_SOURCE_DIR}/bsw/platform/bsw-mcal-msp/sdk"
            "${CMAKE_SOURCE_DIR}/bsw/platform/bsw-mcal-msp/sdk/third_party/CMSIS/Core/Include"
            "${CMAKE_SOURCE_DIR}/bsw/platform/bsw-mcal-msp/sdk/ti/devices"
            "${CMAKE_SOURCE_DIR}/bsw/platform/bsw-mcal-msp/sdk/ti/driverlib")
        target_compile_definitions(ti_driverlib PUBLIC
            PLATFORM_MSPM0 __MSPM0G3507__ __ARM_ARCH_6M__ __FPU_PRESENT=0)
    endif()
    add_executable(${PROJECT_NAME} ${_app_sources})
    if(PLATFORM STREQUAL "mspm0")
        target_link_libraries(${PROJECT_NAME} PRIVATE ti_driverlib)
    endif()
    # Application links the BSW framework + the True MCAL implementation for
    # the chosen PLATFORM. mcal_hal is BSW-internal legacy (HAL-wrapping); new
    # applications go through the MCAL contract headers (Mcu.h/Dio.h/Os.h/...)
    # provided directly by mcal_<platform>.
    if(PLATFORM STREQUAL "mspm0")
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
