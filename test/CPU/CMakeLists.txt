set(TEST_FILE "${CMAKE_CURRENT_SOURCE_DIR}/TestHost.bsv")

get_filename_component(TEST_TARGET ${TEST_FILE} NAME_WE)
add_executable(${TEST_TARGET} ${TEST_FILE})
set_target_properties(${TEST_TARGET} PROPERTIES LINKER_LANGUAGE BSV)
target_compile_definitions(${TEST_TARGET} PUBLIC
    ${BASE_ISA}
)
target_link_libraries(${TEST_TARGET}
    PGRVCommon::PGRVCommon
    CPU::CPU
)
add_test(
    NAME ${TEST_TARGET}
    COMMAND "${CMAKE_SOURCE_DIR}/cmake/BSV-cmake/Wrappers/bsvtest" "${CMAKE_CURRENT_BINARY_DIR}/${TEST_TARGET}" 
)
