######################################
# ARM GNU Toolchain (arm-none-eabi)
# Supports: Cortex-M0+, M4, M7, etc.
######################################

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)

# Skip compiler test for bare-metal
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
set(CMAKE_C_COMPILER_WORKS   1)
set(CMAKE_CXX_COMPILER_WORKS 1)

set(TOOLCHAIN_VERSION "13.3.rel1")

# Toolchain search order:
#  1. Environment variable ARM_GCC_PATH
#  2. Workspace-level _shared (server / CI)
#  3. Repo-local bootstrap/ (fresh clone)
#  4. System PATH (installed globally)
if(DEFINED ENV{ARM_GCC_PATH})
    set(_TC_ROOT "$ENV{ARM_GCC_PATH}")
elseif(EXISTS "/srv/workspaces/_shared/tools/compilers/gnu-arm/${TOOLCHAIN_VERSION}")
    set(_TC_ROOT "/srv/workspaces/_shared/tools/compilers/gnu-arm/${TOOLCHAIN_VERSION}")
elseif(EXISTS "${CMAKE_SOURCE_DIR}/bootstrap/tools/compilers/gnu-arm/${TOOLCHAIN_VERSION}")
    set(_TC_ROOT "${CMAKE_SOURCE_DIR}/bootstrap/tools/compilers/gnu-arm/${TOOLCHAIN_VERSION}")
else()
    set(_TC_ROOT "")
    message(STATUS "ARM GCC: using system PATH (run bootstrap/bootstrap to install locally)")
endif()

if(_TC_ROOT)
    set(_TC_BIN "${_TC_ROOT}/bin/")
    message(STATUS "ARM GCC toolchain: ${_TC_ROOT}")
endif()

# Windows ships GCC as *.exe; explicit absolute paths must include the
# extension or project()/enable_language() rejects them.
if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    set(_TC_EXE ".exe")
else()
    set(_TC_EXE "")
endif()

set(CMAKE_C_COMPILER   "${_TC_BIN}arm-none-eabi-gcc${_TC_EXE}")
set(CMAKE_CXX_COMPILER "${_TC_BIN}arm-none-eabi-g++${_TC_EXE}")
set(CMAKE_ASM_COMPILER "${_TC_BIN}arm-none-eabi-gcc${_TC_EXE}")
set(CMAKE_OBJCOPY      "${_TC_BIN}arm-none-eabi-objcopy${_TC_EXE}")
set(CMAKE_SIZE         "${_TC_BIN}arm-none-eabi-size${_TC_EXE}")

# Cortex-M0+ flags (MSPM0G series)
set(CMAKE_C_FLAGS_INIT
    "-mcpu=cortex-m0plus -mthumb -mfloat-abi=soft \
     -ffunction-sections -fdata-sections -Wall -Wextra")
set(CMAKE_EXE_LINKER_FLAGS_INIT
    "-Wl,--gc-sections --specs=nosys.specs")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
