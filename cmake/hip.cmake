if(NOT CMAKE_HIP_COMPILER)
  if(NOT ROCM_ROOT)
    message(STATUS "ROCM_ROOT is not set, try /opt/rocm")
    set(ROCM_ROOT /opt/rocm)
  endif()
  set(CMAKE_HIP_COMPILER ${ROCM_ROOT}/llvm/bin/clang++)
endif()

if(NOT HIP_CLANG_PATH)
  get_filename_component(HIP_CLANG_PATH ${CMAKE_HIP_COMPILER} DIRECTORY)
endif()

if(NOT CMAKE_HIP_ARCHITECTURES)
  set(CMAKE_HIP_ARCHITECTURES "gfx906;gfx908;gfx90a;gfx1030;gfx1100;gfx1101")
endif()

file(GLOB rocm_cmake_components ${ROCM_ROOT}/lib/cmake/*)
list(APPEND CMAKE_PREFIX_PATH ${rocm_cmake_components})
# Force cmake to accept the configured HIP compiler. Because the configured
# CMAKE_PREFIX_PATH does not work during enable_language(HIP)
set(CMAKE_HIP_COMPILER_FORCED ON)

if(NOT HUTE_HIPIFY_PERL)
  find_path(
    HIPIFY_PERL_PATH
    NAMES hipify-perl
    HINTS ${ROCM_ROOT}/bin ${ROCM_ROOT}/hip/bin)
  if(HIPIFY_PERL_PATH-NOTFOUND)
    message(FATAL_ERROR "hipify-perl not found")
  endif()
  set(HUTE_HIPIFY_PERL ${HIPIFY_PERL_PATH}/hipify-perl)
endif()

enable_language(HIP)

if(NOT DEFINED _CMAKE_HIP_DEVICE_RUNTIME_TARGET)
  message(FATAL_ERROR "HIP Language is not properly configured.")
endif()
add_compile_options(
  "$<$<COMPILE_LANGUAGE:HIP>:SHELL:-xhip -D__HIP_PLATFORM_AMD__=1 -D__HIP_PLATFORM_HCC__=1>"
)

function(set_cu_files_hip_language)
  foreach(f ${ARGN})
    if(f MATCHES ".*\\.cuh?$")
      set_source_files_properties(${f} PROPERTIES LANGUAGE HIP)
    endif()
  endforeach()
endfunction()

set(hipify_tool ${CMAKE_CURRENT_LIST_DIR}/hipify.py)

function(hipify)
  set(options "")
  set(one_value_keywords "GENERATE" "PREPEND" "APPEND" "STRIP_PREFIX"
                         "ADD_PREFIX" "VERBOSE")
  set(multi_value_keywords "")
  cmake_parse_arguments(hipify "${options}" "${one_value_keywords}"
                        "${multi_value_keywords}" ${ARGN})

  set(hipify_SRCS ${hipify_UNPARSED_ARGUMENTS})

  if(NOT hipify_STRIP_PREFIX)
    set(hipify_STRIP_PREFIX ${CMAKE_CURRENT_SOURCE_DIR})
  endif()

  if(NOT hipify_ADD_PREFIX)
    set(hipify_ADD_PREFIX ${CMAKE_CURRENT_BINARY_DIR}/hipified)
  endif()

  if(hipify_VERBOSE)
    message("SRCS: ${hipify_SRCS}")
    message("GENERATE: ${hipify_GENERATE}")
    message("PREPEND: ${hipify_PREPEND}")
    message("APPEND: ${hipify_APPEND}")
    message("STRIP_PREFIX: ${hipify_STRIP_PREFIX}")
    message("ADD_PREFIX: ${hipify_ADD_PREFIX}")
  endif()

  if(NOT Python3_FOUND)
    message(FATAL_ERROR "hipify requires python3")
  endif()

  if(NOT PERL_FOUND)
    message(FATAL_ERROR "hipify requires perl")
  endif()

  foreach(f ${hipify_SRCS})
    if(IS_ABSOLUTE ${f})
      file(RELATIVE_PATH cuda_f_rel ${hipify_STRIP_PREFIX} ${f})
    else()
      if(NOT EXISTS ${hipify_STRIP_PREFIX}/${f})
        message(FATAL_ERROR "${hipify_STRIP_PREFIX}/${f} does not exist")
      endif()
      set(cuda_f_rel ${f})
      set(f ${hipify_STRIP_PREFIX}/${f})
    endif()
    # file(RELATIVE_PATH cuda_f_rel "${hipify_STRIP_PREFIX}" ${f})
    string(REPLACE "cuda" "rocm" rocm_f_rel ${cuda_f_rel})
    set(f_out ${hipify_ADD_PREFIX}/${rocm_f_rel})
    add_custom_command(
      OUTPUT ${f_out}
      COMMAND Python3::Interpreter ${hipify_tool} --perl ${PERL_EXECUTABLE}
              --hipify_perl ${HUTE_HIPIFY_PERL} ${f} -o ${f_out}
      DEPENDS ${hipify_tool} ${f}
      COMMENT "Hipify ${f} -> ${f_out}")
    list(APPEND generated_files ${f_out})
  endforeach()

  set_source_files_properties(${generated_files} PROPERTIES GENERATED TRUE)
  set_cu_files_hip_language(${generated_files})

  if(hipify_GENERATE)
    set(${hipify_GENERATE}
        ${generated_files}
        PARENT_SCOPE)
  endif()

  if(hipify_PREPEND)
    set(tmp ${generated_files} ${${hipify_PREPEND}})
    set(${hipify_PREPEND}
        ${tmp}
        PARENT_SCOPE)
  endif()

  if(hipify_APPEND)
    set(tmp ${generated_files} ${${hipify_APPEND}})
    set(${hipify_APPEND}
        ${tmp}
        PARENT_SCOPE)
  endif()

endfunction()
