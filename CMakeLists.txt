# [EXAMPLE CMD EXECUTED WHEN RUNNING `python3 setup.py build`]
# mkdir -p build ; cd build
# /nix/store/xabbpxi8d4jwmasnc4jq0vjdh9mgfya1-python3-3.12.9-env/bin/cmake \
#   -DPython_INCLUDE_DIR=/nix/store/f2krmq3iv5nibcvn4rw7nrnrciqprdkh-python3-3.12.9/include/python3.12 \
#   -DPython_EXECUTABLE=/nix/store/xabbpxi8d4jwmasnc4jq0vjdh9mgfya1-python3-3.12.9-env/bin/python3.12 \
#   -DBUILD_ONNX_PYTHON=ON \
#   -DONNX_USE_LITE_PROTO=ON \
#   -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
#   -DONNX_NAMESPACE=onnx \
#   -DPY_EXT_SUFFIX=.cpython-312-x86_64-linux-gnu.so \
#   -DONNX_OPT_USE_SYSTEM_PROTOBUF=OFF \
#   -DCMAKE_BUILD_TYPE=Release \
#   -DONNX_ML=1 \
#   /home/simp/GIT/optimizer

# [SUMMARY]
# cmake_minimum_required(VERSION ...)
# project({PROJECT NAME} C CXX)
# set(CMAKE_CXX_STANDARD 17)
# set(CMAKE_POSITION_INDEPENDENT_CODE ON)  # gcc -fPIC
# include(cmake/utils.cmake)
#
# [ADD libprotobuf (third party)]
# add_subdirectory(${PROJECT_SOURCE_DIR}/third_party/protobuf/cmake libprotobuf)
#
# [ADD onnx (third party)]
# set(ONNX_TARGET_NAME onnx)
# set(ONNX_ROOT ${PROJECT_SOURCE_DIR}/third_party/onnx)
# add_subdirectory(${ONNX_ROOT} ${ONNX_TARGET_NAME})  # add onnx
#
# [ADD+LINK(onnx--onnx_optimizer)+INCLUDE onnx_optimizer]
# file(GLOB onnx_opt_srcs "onnxoptimizer/*.cc" "onnxoptimizer/*.h" "onnxoptimizer/passes/*.cc" "onnxoptimizer/passes/*.h")
# list(REMOVE_ITEM onnx_opt_srcs "${PROJECT_SOURCE_DIR}/onnxoptimizer/cpp2py_export.cc")
# add_library(onnx_optimizer ${onnx_opt_srcs})
# target_link_libraries(onnx_optimizer PUBLIC onnx)
# target_include_directories(onnx_optimizer PUBLIC {include dir})  # TODO: macro
#
# [ADD_EXEC+LINK(onnx_optimizer--onnx_optimizer_exec) onnx_optimizer_exec]
# add_executable(onnx_optimizer_exec examples/onnx_optimizer_exec.cpp)
# target_link_libraries(onnx_optimizer_exec onnx_optimizer)
#
# [ADD+LINK(onnx--onnx_optimizer_c_api)+INCLUDE onnx_opt_c_api]
# file(GLOB onnx_opt_c_api_srcs "onnxoptimizer/c_api/*.cc" "onnxoptimizer/c_api/*.h")
# add_library(onnx_optimizer_c_api ${onnx_opt_c_api_srcs})
# target_link_libraries(onnx_optimizer_c_api PRIVATE onnx)
# target_include_directories(onnx_optimizer_c_api PUBLIC {include dir})
#
# [ADD+INCLUDE onnx_opt_cpp2py_export - requires pybind,onnx,onnxoptimizer]
# add_library(onnx_opt_cpp2py_export MODULE "onnxoptimizer/cpp2py_export.cc")
#   MODULE to be dynamically loaded during runtime (e.g. dlopen)
#   e.g. import onnxoptimizer.onnx_opt_cpp2py_export as C
# set_target_properties(onnx_opt_cpp2py_export PROPERTIES PREFIX "")
# set_target_properties(onnx_opt_cpp2py_export PROPERTIES COMPILE_FLAGS "-fvisibility=hidden")
# set_target_properties(onnx_opt_cpp2py_export PROPERTIES SUFFIX ".cpython-312-x86_64-linux-gnu.so")
# set_target_properties(onnx_opt_cpp2py_export PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
# target_include_directories(onnx_opt_cpp2py_export PRIVATE $<BUILD_INTERFACE:${ONNX_ROOT}> $<INSTALL_INTERFACE:include> ${Python_INCLUDE_DIR})
#
# [PYTHON & PYBIND]
# find_package(Python COMPONENTS Interpreter REQUIRED)
# find_package(pybind11 2.2)
# target_include_directories(onnx_opt_cpp2py_export PUBLIC ${pybind11_INCLUDE_DIRS})
#
# target_link_libraries(onnx_opt_cpp2py_export PRIVATE "-Wl,--whole-archive" $<TARGET_FILE:onnx_optimizer> "-Wl,--no-whole-archive")
# set_target_properties(onnx_opt_cpp2py_export PROPERTIES LINK_FLAGS "-Wl,--exclude-libs,ALL")
# target_link_libraries(onnx_opt_cpp2py_export PRIVATE onnx_optimizer)

cmake_minimum_required(VERSION 3.22)

# For std::filesystem
# Must be a cache variable and be set before project()
# Reference: https://cmake.org/cmake/help/latest/variable/CMAKE_OSX_DEPLOYMENT_TARGET.html
# Maybe it can be a normal variable if policy CMP0126 is set to NEW?
set(CMAKE_OSX_DEPLOYMENT_TARGET 10.15 CACHE STRING "Minimum OS X deployment version")

project(onnx_optimizer C CXX)

# NOTE: set({var name} {value} CACHE {dtype} {doctsring}) is for cmake-gui
#   it should behave exactly same as normal set
set(CMAKE_CXX_STANDARD 17)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)

include(cmake/utils.cmake)

# For integration with onnxruntime_webassembly etc.
if (NOT DEFINED ONNX_TARGET_NAME)
  set(ONNX_TARGET_NAME onnx)
endif()

# NOTE: argparse cli flags (e.g. option({flag name} {help} {DEFAULT}))
option(ONNX_OPT_USE_SYSTEM_PROTOBUF "" OFF)
if(NOT ONNX_OPT_USE_SYSTEM_PROTOBUF) # use third party protobuf
  option(protobuf_BUILD_TESTS "" OFF)
  option(protobuf_MSVC_STATIC_RUNTIME "" ${ONNX_USE_MSVC_STATIC_RUNTIME})
  message(STATUS "[DEBUG] protobuf_MSVC_STATIC_RUNTIME = ${protobuf_MSVC_STATIC_RUNTIME}")
  # NOTE: add_subdirectory({protobuf cmake dir}) if (NOT TARGET libprotobuf)
  add_subdirectory_if_no_target(${PROJECT_SOURCE_DIR}/third_party/protobuf/cmake libprotobuf)
endif()


# NOTE: add_subdirectory({onnx cmake dir}) if (NOT TARGET onnx)
set(ONNX_ROOT ${PROJECT_SOURCE_DIR}/third_party/onnx)
add_subdirectory_if_no_target(${ONNX_ROOT} ${ONNX_TARGET_NAME})

# NOTE: read VERSION_NUMBER file and strip string (no space)
file(READ "${PROJECT_SOURCE_DIR}/VERSION_NUMBER" ONNX_OPTIMIZER_VERSION)
string(STRIP "${ONNX_OPTIMIZER_VERSION}" ONNX_OPTIMIZER_VERSION)
message(STATUS "[DEBUG] ONNX_OPTIMIZER_VERSION = ${ONNX_OPTIMIZER_VERSION}")

file(GLOB onnx_opt_srcs "onnxoptimizer/*.cc"
    "onnxoptimizer/*.h"
    "onnxoptimizer/passes/*.cc"
    "onnxoptimizer/passes/*.h"
    )
list(REMOVE_ITEM onnx_opt_srcs "${PROJECT_SOURCE_DIR}/onnxoptimizer/cpp2py_export.cc")

# NOTE: add_library(onnx_optimizer {onnxoptimizer/*.cc|h})
#       target_link_libraries(onnx_optimizer PUBLIC onnx)
#       target_include_directories(onnx_optimizer PUBLIC {include dir})
onnxopt_add_library(onnx_optimizer ${onnx_opt_srcs})
target_link_libraries(onnx_optimizer PUBLIC ${ONNX_TARGET_NAME})
target_include_directories(onnx_optimizer PUBLIC
    $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include>
    )

# NOTE: add_executable(onnx_optimizer_exec {cpp file})
#       target_link_libraries(onnx_optimizer_exec onnx_optimizer)
onnxopt_add_executable(onnx_optimizer_exec examples/onnx_optimizer_exec.cpp)
target_link_libraries(onnx_optimizer_exec onnx_optimizer)


file(GLOB onnx_opt_c_api_srcs "onnxoptimizer/c_api/*.cc"
  "onnxoptimizer/c_api/*.h"
    )

# NOTE: add_library(onnx_optimizer_c_api {onnxoptimizer/c_api/*.cc|h})
#       target_link_libraries(onnx_optimizer_c_api PRIVATE onnx)
#       target_include_directories(onnx_optimizer_c_api PUBLIC {include dir})
onnxopt_add_library(onnx_optimizer_c_api ${onnx_opt_c_api_srcs})
target_link_libraries(onnx_optimizer_c_api PRIVATE onnx_optimizer)
target_include_directories(onnx_optimizer_c_api PUBLIC
    $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include>
    )

if(BUILD_ONNX_PYTHON)
  if("${PY_EXT_SUFFIX}" STREQUAL "")
    if(MSVC)
      set(PY_EXT_SUFFIX ".pyd")
    else()
      set(PY_EXT_SUFFIX ".so")
    endif()
  endif()
  # NOTE: -DPY_EXT_SUFFIX=".cpython-312-x86_64-linux-gnu.so"
  find_package(Python COMPONENTS Interpreter REQUIRED)

  # NOTE: add_library(onnx_opt_cpp2py_export MODULE {file excluded from target onnxoptimizer})
  #         MODULE to be dynamically loaded during runtime (e.g. dlopen)
  #         e.g. import onnxoptimizer.onnx_opt_cpp2py_export as C
  #       set_target_properties(...) TODO
  #       target_include_directories(onnx_opt_cpp2py_export {include dir})
  onnxopt_add_library(onnx_opt_cpp2py_export MODULE "onnxoptimizer/cpp2py_export.cc")
  set_target_properties(onnx_opt_cpp2py_export PROPERTIES PREFIX "")
  set_target_properties(onnx_opt_cpp2py_export
                        PROPERTIES COMPILE_FLAGS "-fvisibility=hidden")
  set_target_properties(onnx_opt_cpp2py_export PROPERTIES SUFFIX ${PY_EXT_SUFFIX})
  set_target_properties(onnx_opt_cpp2py_export
                        PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
  target_include_directories(onnx_opt_cpp2py_export PRIVATE
                             $<BUILD_INTERFACE:${ONNX_ROOT}>
                             $<INSTALL_INTERFACE:include>
                             ${Python_INCLUDE_DIR})
  # pybind11 is a header only lib
  # NOTE: find_package(pybind11 {version})
  find_package(pybind11 2.2)
  if(pybind11_FOUND)
    # NOTE: target_include_directories(onnx_opt_cpp2py_export PUBLIC {include dir})
    target_include_directories(onnx_opt_cpp2py_export PUBLIC
      ${pybind11_INCLUDE_DIRS})
  else()
    if(EXISTS ${ONNX_ROOT}/third_party/pybind11/include/pybind11/pybind11.h)
      target_include_directories(onnx_opt_cpp2py_export PUBLIC
        ${ONNX_ROOT}/third_party/pybind11/include)
    else()
      message(FATAL_ERROR "cannot find pybind")
    endif()
  endif()

  if(APPLE)
    set_target_properties(onnx_opt_cpp2py_export
                          PROPERTIES LINK_FLAGS "-undefined dynamic_lookup")
    target_link_libraries(onnx_opt_cpp2py_export
                          PRIVATE -Wl,-force_load,$<TARGET_FILE:onnx_optimizer>)
  elseif(MSVC)
    # In MSVC, we will add whole archive in default
    target_link_libraries(onnx_opt_cpp2py_export
                          PRIVATE -WHOLEARCHIVE:$<TARGET_FILE:onnx_optimizer>)
  elseif(CMAKE_SYSTEM_NAME STREQUAL "AIX")
    # whole-archive linker option not available on AIX
    target_sources(onnx_opt_cpp2py_export
                          PRIVATE $<TARGET_OBJECTS:onnx_optimizer>)
  else()
    # Assume everything else is like gcc
    # NOTE: target_link_libraries(onnx_opt_cpp2py_export PRIVATE TODO)
    #       set_target_properties(onnx_opt_cpp2py_export PROPERTIES TODO)
    target_link_libraries(onnx_opt_cpp2py_export
                          PRIVATE "-Wl,--whole-archive" $<TARGET_FILE:onnx_optimizer>
                                  "-Wl,--no-whole-archive")
    set_target_properties(onnx_opt_cpp2py_export
                          PROPERTIES LINK_FLAGS "-Wl,--exclude-libs,ALL")
  endif()

  target_link_libraries(onnx_opt_cpp2py_export PRIVATE onnx_optimizer)

  if(MSVC)
    find_package(Python COMPONENTS Interpreter Development REQUIRED)
    target_link_libraries(onnx_opt_cpp2py_export PRIVATE ${Python_LIBRARIES})
    target_compile_options(onnx_opt_cpp2py_export
                           PRIVATE /MP
                                   /WX
                                   /wd4800 # disable warning type' : forcing
                                           # value to bool 'true' or 'false'
                                           # (performance warning)
                                   /wd4503 # identifier' : decorated name length
                                           # exceeded, name was truncated
                                   /wd4146 # unary minus operator applied to
                                           # unsigned type, result still
                                           # unsigned from include\google\protob
                                           # uf\wire_format_lite.h
                                 /wd4244 # 'argument': conversion from 'google::
                                         # protobuf::uint64' to 'int', possible
                                         # loss of data
                                 /wd4267 # Conversion from 'size_t' to 'int',
                                         # possible loss of data
                                 /wd4996 # The second parameter is ignored.
                                   ${EXTRA_FLAGS})
    if(ONNX_USE_PROTOBUF_SHARED_LIBS)
      target_compile_options(onnx_opt_cpp2py_export
                             PRIVATE /wd4251 # 'identifier' : class 'type1' needs to
                                             # have dll-interface to be used by
                                             # clients of class 'type2'
                            )
    endif()
  endif()
endif()

include(GNUInstallDirs)

install(DIRECTORY ${PROJECT_SOURCE_DIR}/onnxoptimizer
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
        FILES_MATCHING
        PATTERN "*.h")

configure_file(
  ${PROJECT_SOURCE_DIR}/cmake/ONNXOptimizerConfigVersion.cmake.in
  ${PROJECT_BINARY_DIR}/ONNXOptimizerConfigVersion.cmake
  @ONLY)
configure_file(
  ${PROJECT_SOURCE_DIR}/cmake/ONNXOptimizerConfig.cmake.in
  ${PROJECT_BINARY_DIR}/ONNXOptimizerConfig.cmake
  @ONLY)
install(FILES
  ${PROJECT_BINARY_DIR}/ONNXOptimizerConfigVersion.cmake
  ${PROJECT_BINARY_DIR}/ONNXOptimizerConfig.cmake
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/ONNXOptimizer
  COMPONENT dev)
install(EXPORT ONNXOptimizerTargets DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/ONNXOptimizer")
install(TARGETS
  onnx_optimizer onnx_optimizer_c_api
  EXPORT ONNXOptimizerTargets DESTINATION ${CMAKE_INSTALL_LIBDIR})

