cmake_minimum_required(VERSION 3.22)
cmake_policy(SET CMP0077 NEW)

#
# CMAKE_MODULE_PATH
#
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/BSV-cmake")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/pgrv-cmake")

project(E100 BSV CXX)

enable_testing()

add_subdirectory(src)
add_subdirectory(test)
