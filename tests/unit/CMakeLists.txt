include(FetchContent)

FetchContent_Declare(
    unity
    GIT_REPOSITORY https://github.com/ThrowTheSwitch/Unity.git
    GIT_TAG        v2.5.2
    GIT_SHALLOW    TRUE
)
FetchContent_MakeAvailable(unity)

add_executable(test_led_blink
    test_led_blink.c
    ${PROJECT_SOURCE_DIR}/src/led_blink.c
)

target_include_directories(test_led_blink PRIVATE
    ${PROJECT_SOURCE_DIR}/src
    ${PROJECT_SOURCE_DIR}/tests/mock
    ${unity_SOURCE_DIR}/src
)

target_link_libraries(test_led_blink PRIVATE unity)

add_test(NAME "LedBlink::UnitTests" COMMAND test_led_blink)

add_executable(test_app_mode
    test_app_mode.c
    ${PROJECT_SOURCE_DIR}/src/app_mode.c
)

target_include_directories(test_app_mode PRIVATE
    ${PROJECT_SOURCE_DIR}/src
    ${PROJECT_SOURCE_DIR}/tests/mock
    ${unity_SOURCE_DIR}/src
)

target_link_libraries(test_app_mode PRIVATE unity mock_dio_state)

add_test(NAME "AppMode::UnitTests" COMMAND test_app_mode)
