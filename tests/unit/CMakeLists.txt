include(FetchContent)

FetchContent_Declare(
    unity
    GIT_REPOSITORY https://github.com/ThrowTheSwitch/Unity.git
    GIT_TAG        v2.5.2
    GIT_SHALLOW    TRUE
)
FetchContent_MakeAvailable(unity)

# Common bag of sources: SWC + static RTE backend.
# Both test execs link them; the static Rte_Impl.c hosts the shared Mode port.
set(_app_under_test
    ${PROJECT_SOURCE_DIR}/src/swc/Swc_LedBlink.c
    ${PROJECT_SOURCE_DIR}/src/swc/Swc_ModeSelector.c
    ${PROJECT_SOURCE_DIR}/src/rte/static/Rte_Impl.c
)

set(_app_includes
    ${PROJECT_SOURCE_DIR}/src/swc
    ${PROJECT_SOURCE_DIR}/src/rte
    ${PROJECT_SOURCE_DIR}/src/cfg
    ${PROJECT_SOURCE_DIR}/tests/mock
    ${unity_SOURCE_DIR}/src
)

add_executable(test_Swc_LedBlink
    test_Swc_LedBlink.c
    ${_app_under_test}
)
target_include_directories(test_Swc_LedBlink PRIVATE ${_app_includes})
target_link_libraries(test_Swc_LedBlink PRIVATE unity mock_dio_state)
add_test(NAME "Swc_LedBlink::UnitTests" COMMAND test_Swc_LedBlink)

add_executable(test_Swc_ModeSelector
    test_Swc_ModeSelector.c
    ${_app_under_test}
)
target_include_directories(test_Swc_ModeSelector PRIVATE ${_app_includes})
target_link_libraries(test_Swc_ModeSelector PRIVATE unity mock_dio_state)
add_test(NAME "Swc_ModeSelector::UnitTests" COMMAND test_Swc_ModeSelector)
