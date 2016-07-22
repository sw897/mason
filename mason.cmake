set(_mason_command ${CMAKE_CURRENT_LIST_DIR}/mason)
set(_mason_package_dir ${CMAKE_BINARY_DIR}/mason)
string(RANDOM LENGTH 16 _mason_invocation)

function(_mason_valid_args package version)
    if(NOT package OR NOT version)
        message(FATAL_ERROR "No package name or version given")
    endif()
endfunction()

function(_mason_install package version)
    set(_mason_failed)
    execute_process(
        COMMAND ${_mason_command} install ${package} ${version}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        RESULT_VARIABLE _mason_failed)
    if(_mason_failed)
        message(FATAL_ERROR "[Mason] Could not install Mason package")
    endif()

    set(_mason_failed)
    set(_mason_prefix)
    execute_process(
        COMMAND ${_mason_command} prefix ${package} ${version}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE _mason_prefix
        RESULT_VARIABLE _mason_failed
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(_mason_failed)
        message(FATAL_ERROR "[Mason] Could not install Mason package")
    endif()

    set(_mason_prefix ${_mason_prefix} PARENT_SCOPE)
    file(RELATIVE_PATH _mason_prefix_relative ${CMAKE_BINARY_DIR} ${_mason_prefix})
    set(_mason_prefix_relative ${_mason_prefix_relative} PARENT_SCOPE)
endfunction()

function(_mason_get_flags package version)
   set(_mason_flags)
   set(_mason_failed)
   execute_process(
        COMMAND ${_mason_command} cflags ${package} ${version}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE _mason_flags
        RESULT_VARIABLE _mason_failed
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(_mason_failed)
        message(FATAL_ERROR "[Mason] Could not get flags for package ${package} ${version}")
    endif()

    # Extract -I and -isystem to {package}_INCLUDE_DIRS
    string(REGEX MATCHALL "(^| +)-(I|isystem) *([^ ]+)" _mason_include_dirs "${_mason_flags}")
    string(REGEX REPLACE "(^| +)-(I|isystem) *" "" _mason_include_dirs "${_mason_include_dirs}")
    string(STRIP "${_mason_include_dirs}" _mason_include_dirs)
    list(REMOVE_DUPLICATES _mason_include_dirs)
    set(_mason_include_dirs "${_mason_include_dirs}" PARENT_SCOPE)

    # Extract -D definitions to {package}_DEFINITIONS
    string(REGEX MATCHALL "(^| +)-D *([^ ]+)" _mason_definitions "${_mason_flags}")
    string(REGEX REPLACE "(^| +)-D *" "\\1" _mason_definitions "${_mason_definitions}")
    string(STRIP "${_mason_definitions}" _mason_definitions)
    set(_mason_definitions "${_mason_definitions}" PARENT_SCOPE)

    # Store all other flags in {package}_OPTIONS
    string(REGEX REPLACE "(^| +)-(D|I|isystem) *([^ ]+)" "" _mason_options "${_mason_flags}")
    string(STRIP "${_mason_options}" _mason_options)
    set(_mason_options "${_mason_options}" PARENT_SCOPE)
endfunction()

function(_mason_get_libs package version)
    set(_mason_failed)
    set(_mason_static_libs)
    execute_process(
        COMMAND ${_mason_command} static_libs ${package} ${version}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE _mason_static_libs
        RESULT_VARIABLE _mason_failed
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(_mason_failed)
        message(FATAL_ERROR "[Mason] Could not get static libraries for package ${package} ${version}")
    endif()

    set(_mason_failed)
    set(_mason_ldflags)
    execute_process(
        COMMAND ${_mason_command} ldflags ${package} ${version}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE _mason_ldflags
        RESULT_VARIABLE _mason_failed
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(_mason_failed)
        message(FATAL_ERROR "[Mason] Could not get linker flags for package ${package} ${version}")
    endif()

    set(_mason_static_libs ${_mason_static_libs} PARENT_SCOPE)
    set(_mason_ldflags ${_mason_ldflags} PARENT_SCOPE)
endfunction()

function(mason_use_package)
    if(ARGC LESS 2)
        message(FATAL_ERROR "No package name or version given")
    elseif(ARGC LESS 3)
        set(alias "${ARGV0}")
        set(package "${ARGV0}")
        set(version "${ARGV1}")
    else()
        set(alias "${ARGV0}")
        set(package "${ARGV1}")
        set(version "${ARGV2}")
    endif()

    _mason_valid_args("${package}" "${version}")

    set(_mason_find_file_path "${_mason_package_dir}/${alias}/${version}")
    set(_mason_find_file "${_mason_find_file_path}/Find${alias}.cmake")

    # Debug
    file(REMOVE "${_mason_find_file}")

    if(_mason_${package}_invocation STREQUAL ${_mason_invocation})
        # Check that the previous invocation of mason_use didn't select another version of this package
        if(NOT MASON_${package}_VERSION STREQUAL ${version})
            message(FATAL_ERROR "[Mason] Already using ${package} ${MASON_${package}_VERSION}. Cannot select version ${version}.")
        endif()
    elseif(NOT EXISTS "${_mason_find_file}")
        _mason_install("${package}" "${version}")
        _mason_get_flags("${package}" "${version}")
        _mason_get_libs("${package}" "${version}")

        set(_mason_${package}_invocation "${_mason_invocation}" CACHE INTERNAL "${package} invocation ID" FORCE)

        file(WRITE "${_mason_find_file}" "# THIS FILE IS GENERATED. Do not edit.\n\n")
        file(APPEND "${_mason_find_file}" "if(NOT ${alias}_FOUND)\n     message(STATUS \"Using ${alias}: ${_mason_prefix_relative}\")\nendif()\n\n")
        file(APPEND "${_mason_find_file}" "set(${alias}_FOUND 1 CACHE BOOL \"${package} found\" FORCE)\n")
        file(APPEND "${_mason_find_file}" "set(${alias}_VERSION \"${version}\" CACHE STRING \"${package} version\" FORCE)\n")
        file(APPEND "${_mason_find_file}" "set(${alias}_INCLUDE_DIRS \"${_mason_include_dirs}\" CACHE STRING \"${package} include directories\" FORCE)\n")
        file(APPEND "${_mason_find_file}" "set(${alias}_LIBRARIES \"${_mason_static_libs}\" CACHE STRING \"${package} static libraries\" FORCE)\n")
        file(APPEND "${_mason_find_file}" "set(${alias}_LDFLAGS \"${_mason_ldflags}\" CACHE STRING \"${package} linker flags\" FORCE)\n")
        file(APPEND "${_mason_find_file}" "set(${alias}_DEFINITIONS \"${_mason_definitions}\" CACHE STRING \"${package} definitions\" FORCE)\n")
        file(APPEND "${_mason_find_file}" "set(${alias}_OPTIONS \"${_mason_options}\" CACHE STRING \"${package} options\" FORCE)\n")
        file(APPEND "${_mason_find_file}" "\nmark_as_advanced(${alias}_VERSION ${alias}_INCLUDE_DIRS ${alias}_LIBRARIES ${alias}_DEFINITIONS ${alias}_OPTIONS)\n")
        file(APPEND "${_mason_find_file}" "\n_mason_export_library(${alias})\n")
    endif()

    set(CMAKE_MODULE_PATH "${_mason_find_file_path};${CMAKE_MODULE_PATH}" PARENT_SCOPE)
endfunction()

function(_mason_export_library package)
    add_library(${package} INTERFACE IMPORTED GLOBAL)
    set_target_properties(${package} PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${${package}_INCLUDE_DIRS}")
    set_target_properties(${package} PROPERTIES INTERFACE_LINK_LIBRARIES "${${package}_LIBRARIES};${${package}_LDFLAGS}")
    set_target_properties(${package} PROPERTIES INTERFACE_COMPILE_DEFINITIONS "${${package}_DEFINITIONS}")
    set_target_properties(${package} PROPERTIES INTERFACE_COMPILE_OPTIONS "${${package}_OPTIONS}")
endfunction()
