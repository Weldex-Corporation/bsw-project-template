######################################
# Host Toolchain (Unit Test / SIL)
# Windows  : MinGW-w64 GCC  (via MSYS2 or standalone)
# macOS    : Apple Clang / Homebrew GCC
# Linux    : System GCC
######################################

set(CMAKE_SYSTEM_NAME ${CMAKE_HOST_SYSTEM_NAME})

# Skip bare-metal settings
set(CMAKE_TRY_COMPILE_TARGET_TYPE EXECUTABLE)

if(WIN32)
    # MinGW-w64: prefer UCRT runtime (MSYS2 ucrt64 environment)
    set(_MINGW_PATHS
        "C:/msys64/ucrt64/bin"
        "C:/msys64/mingw64/bin"
        "C:/mingw64/bin"
        "$ENV{USERPROFILE}/mingw64/bin"
    )
    foreach(_p ${_MINGW_PATHS})
        if(EXISTS "${_p}/gcc.exe")
            set(CMAKE_C_COMPILER   "${_p}/gcc.exe")
            set(CMAKE_CXX_COMPILER "${_p}/g++.exe")
            message(STATUS "Host toolchain: MinGW-w64 at ${_p}")
            break()
        endif()
    endforeach()
    if(NOT CMAKE_C_COMPILER)
        # Fallback: let CMake find gcc in PATH
        find_program(CMAKE_C_COMPILER   gcc)
        find_program(CMAKE_CXX_COMPILER g++)
    endif()
else()
    # Linux / macOS: use system compiler
    find_program(CMAKE_C_COMPILER   gcc cc)
    find_program(CMAKE_CXX_COMPILER g++ c++)
endif()

set(CMAKE_C_STANDARD   11)
set(CMAKE_CXX_STANDARD 17)
