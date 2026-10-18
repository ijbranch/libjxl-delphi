# Copyright (c) 2026 Ian Branch. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# One self-contained jxl.dll for Windows, built from an unmodified libjxl source tree.
#
# Build-JxlDll.ps1 injects this file into libjxl's top-level project with
#   -DCMAKE_PROJECT_LIBJXL_INCLUDE=<this file>
# so no libjxl file is edited. It runs straight after project(LIBJXL), before any
# target exists, so the work is deferred to the end of the top-level
# CMakeLists.txt, when jxl, jxl_cms and jxl_threads have been defined.
#
# Expects -DJPEGXL_STATIC=ON: the three libraries are then static, the C runtime
# is linked statically in Release (/MT), and the DLL needs nothing but Windows
# itself. The exports come from a .def file generated from the public headers
# (every JXL_EXPORT, JXL_CMS_EXPORT and JXL_THREADS_EXPORT prototype, less the
# two headers named below), because a static build compiles JXL_EXPORT to
# nothing. The list is also written to jxl-exports.txt in the build folder, and
# Build-JxlDll.ps1 checks the linked DLL against it.
#
# Optional: -DJXL_DLL_SOURCE_LABEL=<text> (the tag and commit built) for the
# version resource.

# No cmake_minimum_required here: it would reset libjxl's policy settings.
# cmake_language(DEFER) needs CMake 3.19.
set(JXL_DLL_DIR "${CMAKE_CURRENT_LIST_DIR}")

# Debug information for the Release jxl.pdb, embedded in the objects (/Z7) so
# the static libraries carry it to the DLL's link. Set before any target exists,
# so every target created later picks it up (CMP0141 is NEW under libjxl's
# cmake_minimum_required(VERSION 3.16...3.27)). Code generation is unchanged.
if(NOT DEFINED CMAKE_MSVC_DEBUG_INFORMATION_FORMAT)
  set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT Embedded)
endif()

# Control Flow Guard: every object is compiled with the checks and jxl.dll is
# linked with them (below). Measured on Win64: about 2% on decode and lossless
# encode, nothing on lossy encode; the checks are live only in a process that
# enables CFG itself.
add_compile_options(/guard:cf)

function(jxl_dll_add_target)
  if(NOT JPEGXL_STATIC)
    message(FATAL_ERROR "jxl_dll.cmake needs -DJPEGXL_STATIC=ON")
  endif()

  # Generate jxl.def from the public C API headers.
  file(GLOB _headers "${PROJECT_SOURCE_DIR}/lib/include/jxl/*.h")
  # gain_map.h and compressed_icc.h declare JXL_EXPORT functions whose code is in
  # libjxl's internal jxl_extras library, which no official libjxl DLL exports:
  # the shared jxl.dll + jxl_cms.dll + jxl_threads.dll expose exactly the rest.
  list(FILTER _headers EXCLUDE REGEX "/(gain_map|compressed_icc)\\.h$")
  set(_names "")
  foreach(_header IN LISTS _headers)
    file(READ "${_header}" _text)
    string(REGEX MATCHALL "JXL_[A-Z_]*EXPORT[^;{(]*\\(" _decls "${_text}")
    foreach(_decl IN LISTS _decls)
      string(REGEX MATCH "([A-Za-z_][A-Za-z0-9_]*)[ \t\r\n]*\\($" _ignored "${_decl}")
      list(APPEND _names "${CMAKE_MATCH_1}")
    endforeach()
  endforeach()
  list(REMOVE_DUPLICATES _names)
  list(SORT _names)
  list(LENGTH _names _count)
  if(_count EQUAL 0)
    message(FATAL_ERROR "jxl_dll.cmake: no exported functions found in lib/include/jxl")
  endif()

  string(REPLACE ";" "\n" _list "${_names}")
  file(WRITE "${CMAKE_BINARY_DIR}/jxl-exports.txt" "${_list}\n")
  string(REPLACE ";" "\n  " _exports "${_names}")
  file(WRITE "${CMAKE_BINARY_DIR}/jxl.def.tmp" "LIBRARY jxl\nEXPORTS\n  ${_exports}\n")
  # COPYONLY touches jxl.def only when its content changes, so a rerun does not relink.
  configure_file("${CMAKE_BINARY_DIR}/jxl.def.tmp" "${CMAKE_BINARY_DIR}/jxl.def" COPYONLY)
  message(STATUS "jxl.dll: ${_count} exports")

  # Version resource. libjxl sets its version numbers in lib/CMakeLists.txt,
  # whose scope this top-level deferred call cannot see, so read them from there.
  file(STRINGS "${PROJECT_SOURCE_DIR}/lib/CMakeLists.txt" _version_lines
    REGEX "^set\\(JPEGXL_(MAJOR|MINOR|PATCH)_VERSION [0-9]+\\)")
  foreach(_line IN LISTS _version_lines)
    string(REGEX MATCH "JPEGXL_([A-Z]+)_VERSION ([0-9]+)" _ignored "${_line}")
    set(JPEGXL_${CMAKE_MATCH_1}_VERSION "${CMAKE_MATCH_2}")
  endforeach()
  if(NOT DEFINED JPEGXL_MAJOR_VERSION OR NOT DEFINED JPEGXL_MINOR_VERSION OR NOT DEFINED JPEGXL_PATCH_VERSION)
    message(FATAL_ERROR "jxl_dll.cmake: version numbers not found in lib/CMakeLists.txt")
  endif()
  if(NOT DEFINED JXL_DLL_SOURCE_LABEL OR JXL_DLL_SOURCE_LABEL STREQUAL "")
    set(JXL_DLL_SOURCE_LABEL "unlabelled source")
  endif()
  set(JXL_DLL_VERSION_STRING
    "${JPEGXL_MAJOR_VERSION}.${JPEGXL_MINOR_VERSION}.${JPEGXL_PATCH_VERSION} (${JXL_DLL_SOURCE_LABEL})")
  configure_file("${JXL_DLL_DIR}/jxl_version.rc.in" "${CMAKE_BINARY_DIR}/jxl_version.rc" @ONLY)
  message(STATUS "jxl.dll: version ${JXL_DLL_VERSION_STRING}")

  add_library(jxl_dll SHARED "${CMAKE_BINARY_DIR}/jxl.def" "${CMAKE_BINARY_DIR}/jxl_version.rc")
  set_target_properties(jxl_dll PROPERTIES
    OUTPUT_NAME jxl
    ARCHIVE_OUTPUT_NAME jxl_dll
    LINKER_LANGUAGE CXX)
  target_link_libraries(jxl_dll PRIVATE jxl jxl_cms jxl_threads)
  # A full jxl.pdb for the Release DLL. /DEBUG would switch the linker's defaults
  # to /OPT:NOREF,NOICF, so both are restated: the code is the same as without it.
  target_link_options(jxl_dll PRIVATE /DEBUG:FULL /OPT:REF /OPT:ICF /guard:cf)
  # CET shadow-stack compatible (x64 only). Lower case on purpose: CMake's Visual
  # Studio generator turns /CETCOMPAT into the <CETCompat> project property,
  # which the ClangCL toolset's lld-link never receives.
  if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    target_link_options(jxl_dll PRIVATE /cetcompat)
  endif()
endfunction()

cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" CALL jxl_dll_add_target)
