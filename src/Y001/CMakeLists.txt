find_package(PGRVCommon)

set(CORE_NAME "Y001")

add_library(${CORE_NAME} INTERFACE)
add_library(${CORE_NAME}::${CORE_NAME} ALIAS ${CORE_NAME})

target_include_directories(${CORE_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(${CORE_NAME} INTERFACE
    PGRVCommon::PGRVCommon
    CoreBlocks::CoreBlocks
)

#
# Test benches
#
file(GLOB TEST_FILES "${CMAKE_CURRENT_SOURCE_DIR}/*_tb.bsv")
foreach(TEST_FILE ${TEST_FILES})
    get_filename_component(TEST_TARGET ${TEST_FILE} NAME_WE)
    add_executable(${TEST_TARGET} ${TEST_FILE})
    set_target_properties(${TEST_TARGET} PROPERTIES LINKER_LANGUAGE BSV)
    target_compile_definitions(${TEST_TARGET} PUBLIC
        ${BASE_ISA}
        ${EXT_C}
    )
    target_link_libraries(${TEST_TARGET}
        PGRVCommon::PGRVCommon
        CoreBlocks::CoreBlocks
        InstructionLogger::InstructionLogger
    )
    add_test(
        NAME ${TEST_TARGET}
        COMMAND "${CMAKE_SOURCE_DIR}/cmake/BSV-cmake/Wrappers/bsvtest" "${CMAKE_CURRENT_BINARY_DIR}/${TEST_TARGET}" 
    )
endforeach()

#
# Test host
#
set(TESTHOST_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/TestHost.bsv")
get_filename_component(TEST_HOST ${TESTHOST_SOURCE} NAME_WE)
set(TESTHOST_TARGET "${CORE_NAME}-${TEST_HOST}")

add_executable(${TESTHOST_TARGET} ${TESTHOST_SOURCE})
set_target_properties(${TESTHOST_TARGET} PROPERTIES LINKER_LANGUAGE BSV)
target_compile_definitions(${TESTHOST_TARGET} PUBLIC
    ${BASE_ISA}
)
target_link_libraries(${TESTHOST_TARGET}
    PGRVCommon::PGRVCommon
    CoreBlocks::CoreBlocks
    InstructionLogger::InstructionLogger
)

#
# ISA tests
#
find_package(RISCV_ISA_Tests)

if ("${BASE_ISA}" STREQUAL "RV32")
    set(ISA_TEST_BINARIES
        # "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-breakpoint" # Breakpoint Tests
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-csr"        # CSR tests
        # "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-illegal"    # Illegal instructino traps
        # "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-ma_addr"    # Misaligned LD/ST handling
        # "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-ma_fetch"   # Misaligned Fetch handling
        # "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-mcsr"       # Machine Mode CSR tests
        # "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-sbreak"     # EBREAK (formerly SBREAK) tests
        # "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-scall"      # ECALL (formerly SCALL) tests
        # "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv32mi-p-shamt"      # Illegal shamt tests
    )
endif()

if ("${BASE_ISA}" STREQUAL "RV64")
    set(ISA_TEST_BINARIES
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv64mi-p-access"     # Access Exception Tests
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv64mi-p-breakpoint" # Breakpoint Tests
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv64mi-p-csr"        # CSR tests
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv64mi-p-illegal"    # Illegal instructino traps
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv64mi-p-ma_addr"    # Misaligned LD/ST handling
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv64mi-p-ma_fetch"   # Misaligned Fetch handling
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv64mi-p-mcsr"       # Machine Mode CSR tests
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv64mi-p-sbreak"     # EBREAK (formerly SBREAK) tests
        "${RISCV_ISA_TEST_BUILD_DIR}/src/riscv_isa_tests-build/isa/rv64mi-p-scall"      # ECALL (formerly SCALL) tests
    )
endif()

foreach(ISA_TEST_BINARY ${ISA_TEST_BINARIES})
    message("Creating ISA test: ${ISA_TEST_BINARY}")
    get_filename_component(TEST_NAME "${ISA_TEST_BINARY}" NAME_WLE)
    message("Test Commandline: ${CMAKE_SOURCE_DIR}/simlauncher --vcd ${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.vcd --spike --log ${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.trace.txt ${ISA_TEST_BINARY}")
    set(TEST_INVOCATION 
        "${CMAKE_SOURCE_DIR}/tools/simlauncher.sh" 
        --sim-host ${CMAKE_CURRENT_BINARY_DIR}/${CORE_NAME}-${TEST_HOST}
        --vcd "${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.vcd" 
        --isa "${BASE_ISA}" 
        --spike 
        --check 
        --max-cycles 80000 
        --log "${CMAKE_CURRENT_BINARY_DIR}/riscv_isa_tests/isa_${TEST_NAME}" 
        "${ISA_TEST_BINARY}"
    )

    list(JOIN TEST_INVOCATION " " TEST_INVOCATION_STRING)
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.sh" "${TEST_INVOCATION_STRING}")

    add_test(
        NAME "${CORE_NAME}_ISA_TEST_${TEST_NAME}"
        COMMAND ${TEST_INVOCATION}
        WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
    )
endforeach()
