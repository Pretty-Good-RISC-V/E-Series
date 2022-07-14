cmake_minimum_required(VERSION 3.22)
cmake_policy(SET CMP0077 NEW)

#
# Check for offline mode
#
if(MSVC)
    execute_process(
        COMMAND ping www.google.com -n 2
        ERROR_QUIET
        RESULT_VARIABLE NO_CONNECTION
    )
else()
    execute_process(
        COMMAND ping www.google.com -c 2
        ERROR_QUIET
        RESULT_VARIABLE NO_CONNECTION
    )
endif()

if(NOT NO_CONNECTION EQUAL 0)
    set(FETCHCONTENT_FULLY_DISCONNECTED ON)
    message(WARNING "Fetch offline mode: requires already populated _deps")
else()
    set(FETCHCONTENT_FULLY_DISCONNECTED OFF)
endif()

#
# CMAKE_MODULE_PATH
#
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/BSV-cmake")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/pgrv-cmake")

project(E100 BSV CXX)

enable_testing()

add_subdirectory(src)
add_subdirectory(test)
