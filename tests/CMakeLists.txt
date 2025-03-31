# mock Dio state storage (shared across test executables)
add_library(mock_mcal INTERFACE)
target_include_directories(mock_mcal INTERFACE
    ${CMAKE_CURRENT_SOURCE_DIR}/mock
)

# Dio mock state (needs a .c for the extern array)
add_library(mock_dio_state STATIC mock/mock_dio_state.c)
target_include_directories(mock_dio_state PUBLIC mock)

add_subdirectory(unit)
