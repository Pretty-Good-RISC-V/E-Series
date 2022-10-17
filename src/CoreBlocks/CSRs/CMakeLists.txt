add_library(CSRs INTERFACE)
add_library(CSRs::CSRs ALIAS CSRs)

target_include_directories(CSRs INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(CSRs INTERFACE
    PGRVCommon::PGRVCommon
)
