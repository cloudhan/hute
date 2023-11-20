cmake_minimum_required(VERSION 3.27)

project(hute CXX)

option(ROCM_ROOT "" "/opt/rocm")

set(cutlass_SOURCE_DIR ${CMAKE_CURRENT_LIST_DIR}/..)
cmake_path(NATIVE_PATH cutlass_SOURCE_DIR NORMALIZE cutlass_SOURCE_DIR)

set(CMAKE_MODULE_PATH "${cutlass_SOURCE_DIR}/cmake" "${CMAKE_MODULE_PATH}")
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Python3 REQUIRED)
find_package(Perl REQUIRED)

include(hip)

# add_compile_options(-ftemplate-backtrace-limit=0)


file(GLOB_RECURSE cute_headers CONFIGURE_DEPENDS
     "${cutlass_SOURCE_DIR}/include/cute/*.hpp"
     "${cutlass_SOURCE_DIR}/include/cute/**/*.hpp")

# do exclusion
file(
  GLOB_RECURSE cute_excluded_headers
  CONFIGURE_DEPENDS
    # "${cutlass_SOURCE_DIR}/include/cute/**/*sm61*"
    # "${cutlass_SOURCE_DIR}/include/cute/**/*sm70*"
    # "${cutlass_SOURCE_DIR}/include/cute/**/*sm75*"
    # "${cutlass_SOURCE_DIR}/include/cute/**/*sm80*"
    "${cutlass_SOURCE_DIR}/include/cute/**/*sm90*"
)
foreach(f ${cute_excluded_headers})
  message(STATUS "Excluded from hipify: ${f}")
endforeach()
list(REMOVE_ITEM cute_headers ${cute_excluded_headers})

hipify(
  ${cute_headers}
  GENERATE hute_files
  STRIP_PREFIX ${cutlass_SOURCE_DIR}/include/cute
  ADD_PREFIX ${CMAKE_CURRENT_BINARY_DIR}/cute_hipified/cute
  VERBOSE OFF
)

hipify(
  "${cutlass_SOURCE_DIR}/include/cutlass/bfloat16.h"
  "${cutlass_SOURCE_DIR}/include/cutlass/complex.h"
  "${cutlass_SOURCE_DIR}/include/cutlass/cutlass.h"
  "${cutlass_SOURCE_DIR}/include/cutlass/float8.h"
  "${cutlass_SOURCE_DIR}/include/cutlass/half.h"
  "${cutlass_SOURCE_DIR}/include/cutlass/integer_subbyte.h"
  "${cutlass_SOURCE_DIR}/include/cutlass/numeric_size.h"
  "${cutlass_SOURCE_DIR}/include/cutlass/numeric_types.h"
  "${cutlass_SOURCE_DIR}/include/cutlass/tfloat32.h"
  "${cutlass_SOURCE_DIR}/include/cutlass/real.h"
  "${cutlass_SOURCE_DIR}/include/cutlass/fast_math.h"
  "${cutlass_SOURCE_DIR}/include/cutlass/detail/helper_macros.hpp"
  "${cutlass_SOURCE_DIR}/include/cutlass/platform/platform.h"

  "${cutlass_SOURCE_DIR}/include/cutlass/functional.h"
  "${cutlass_SOURCE_DIR}/include/cutlass/array.h"
  "${cutlass_SOURCE_DIR}/include/cutlass/array_subbyte.h"
  "${cutlass_SOURCE_DIR}/include/cutlass/uint128.h"
  "${cutlass_SOURCE_DIR}/include/cutlass/coord.h"
  APPEND hute_files
  STRIP_PREFIX ${cutlass_SOURCE_DIR}/include/cutlass
  ADD_PREFIX ${CMAKE_CURRENT_BINARY_DIR}/cute_hipified/cutlass
  VERBOSE OFF
)

add_custom_target(gen_hute_files DEPENDS ${hute_files})

add_library(hute INTERFACE)
target_sources(hute INTERFACE ${hute_files})
target_compile_options(hute INTERFACE "-O3")
target_include_directories(hute INTERFACE ${CMAKE_CURRENT_BINARY_DIR}/cute_hipified)
add_dependencies(hute gen_hute_files)

unset(cutlass_SOURCE_DIR)
