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
    add_executable(${PROJECT_NAME}
        src/main.c
        src/led_blink.c
    )
    if(NOT PLATFORM STREQUAL "posix")
        target_link_libraries(${PROJECT_NAME} PRIVATE bsw_core bsw_mcal)
        target_include_directories(${PROJECT_NAME} PRIVATE ${BSW_INCLUDE_DIRS})
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
