find_package(PGRVCommon)

add_subdirectory(CSRs)

add_library(CPU INTERFACE)
add_library(CPU::CPU ALIAS CPU)

target_include_directories(CPU INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(CPU INTERFACE
    PGRVCommon::PGRVCommon
    CSRs::CSRs
)

#
# Tests
#
file(GLOB TEST_FILES "${CMAKE_CURRENT_SOURCE_DIR}/*_tb.bsv")
foreach(TEST_FILE ${TEST_FILES})
    get_filename_component(TEST_TARGET ${TEST_FILE} NAME_WE)
    add_executable(${TEST_TARGET} ${TEST_FILE})
    set_target_properties(${TEST_TARGET} PROPERTIES LINKER_LANGUAGE BSV)
    target_compile_definitions(${TEST_TARGET} PUBLIC
        ${BASE_ISA}
    )
    target_link_libraries(${TEST_TARGET}
        PGRVCommon::PGRVCommon
        CSRs::CSRs
    )
    add_test(
        NAME ${TEST_TARGET}
        COMMAND "${CMAKE_SOURCE_DIR}/cmake/BSV-cmake/Wrappers/bsvtest" "${CMAKE_CURRENT_BINARY_DIR}/${TEST_TARGET}" 
    )
endforeach()
