# Extends ExternalProject_Add(...) by adding a new option.
#  PROCESS_ENVIRONMENT <environment variables>
# When present the BUILD_COMMAND and CONFIGURE_COMMAND are executed as a
# sub-process (using execute_process()) so that the sepecified environment
# is passed on to the executed command (which does not happen by default).
# This will be deprecated once CMake starts supporting it.

include(ExternalProject)

if (CMAKE_GENERATOR MATCHES "Makefiles")
  # Because of the wrapped and nested way that "make" needs to get called, it's
  # not able to utilize the top level make jobserver so it's -j level must be
  # manually controlled.
  set(SUPERBUILD_PROJECT_PARALLELISM 5
    CACHE STRING "Number of jobs to use when compiling subprojects")
  mark_as_advanced(SUPERBUILD_PROJECT_PARALLELISM)

  # Parallelism isn't support for cross builds or toolchain builds.
  if (superbuild_is_cross)
    set(SUPERBUILD_PROJECT_PARALLELISM 1)
  endif ()
endif ()

#------------------------------------------------------------------------------
# Version of the function which strips PROCESS_ENVIRONMENT and CAN_USE_SYSTEM
# arguments for ExternalProject_Add.
function (_superbuild_ep_strip_extra_arguments name)
  set(arguments)
  set(accumulate FALSE)

  foreach (arg IN LISTS ARGN)
    if (arg STREQUAL "PROCESS_ENVIRONMENT" OR
        arg STREQUAL "CAN_USE_SYSTEM")
      set(skip TRUE)
    elseif (arg MATCHES "${_ep_keywords_ExternalProject_Add}")
      set(skip FALSE)
    endif ()

    if (NOT skip)
      list(APPEND arguments "${arg}")
    endif ()
  endforeach ()

  ExternalProject_Add("${name}" "${arguments}")
endfunction ()

function (_superbuild_ep_wrap_command var target command_name require)
  get_property(has_command TARGET "${target}"
    PROPERTY "_SB_${command_name}_COMMAND" SET)
  set("has_${var}"
    "${has_command}"
    PARENT_SCOPE)

  if (has_command OR command_name STREQUAL "BUILD" OR require)
    get_property(command TARGET "${target}"
      PROPERTY "_SB_${command_name}_COMMAND")

    if (NOT has_command)
      # Get the ExternalProject-generated command.
      _ep_get_build_command("${target}" "${command_name}" command)
      # Replace $(MAKE) usage.
      set(submake_regex "^\\$\\(MAKE\\)")
      if (command MATCHES "${submake_regex}")
        string(REGEX REPLACE "${submake_regex}" "${CMAKE_MAKE_PROGRAM} -j${SUPERBUILD_PROJECT_PARALLELISM}" command "${command}")
      endif ()
      set(has_command 1)
    endif ()

    if (command)
      string(TOLOWER "${command_name}" step)
      set(new_command
        "${CMAKE_COMMAND}" -P
        "${CMAKE_CURRENT_BINARY_DIR}/${target}-${step}.cmake")
    else ()
      set(has_command 0)
    endif ()

    set("original_${var}"
      "${command}"
      PARENT_SCOPE)
    set("${var}"
      "${command_name}_COMMAND" "${new_command}"
      PARENT_SCOPE)
  else ()
    set("${var}" PARENT_SCOPE)
  endif ()

  set("req_${var}"
    "${has_command}"
    PARENT_SCOPE)
endfunction ()

function (_superbuild_ExternalProject_add name)
  if (WIN32)
    # Environment variable setting unsupported here.
    # TODO: support it.
    _superbuild_ep_strip_extra_arguments("${name}" "${ARGN}")
    return ()
  endif ()

  # Add "CAN_USE_SYSTEM" and "PROCESS_ENVIRONMENT" to the list of keywords
  # recognized.
  string(REPLACE ")" "|CAN_USE_SYSTEM|PROCESS_ENVIRONMENT)"
    _ep_keywords__superbuild_ExternalProject_add "${_ep_keywords_ExternalProject_Add}")

  # Create a temporary target so we can query target properties.
  add_custom_target("sb-${name}")
  _ep_parse_arguments(_superbuild_ExternalProject_add "sb-${name}" _SB_ "${ARGN}")

  get_property(has_process_environment TARGET "sb-${name}"
    PROPERTY _SB_PROCESS_ENVIRONMENT SET)
  if (NOT has_process_environment)
    _superbuild_ep_strip_extra_arguments(${name} "${ARGN}")
    return ()
  endif ()

  set(args)
  _superbuild_ep_wrap_command(configure_command "sb-${name}" CONFIGURE  FALSE)
  _superbuild_ep_wrap_command(build_command     "sb-${name}" BUILD      FALSE)
  _superbuild_ep_wrap_command(install_command   "sb-${name}" INSTALL    TRUE)

  if (req_configure_command)
    list(APPEND args
      "${configure_command}")
  endif ()
  if (req_build_command)
    list(APPEND args
      "${build_command}")
  endif ()
  list(APPEND args
    "${install_command}")

  # now strip PROCESS_ENVIRONMENT from argments.
  set(skip FALSE)
  foreach (arg IN LISTS ARGN)
    if (arg MATCHES "${_ep_keywords__superbuild_ExternalProject_add}")
      if (arg MATCHES "^(CAN_USE_SYSTEM|PROCESS_ENVIRONMENT|BUILD_COMMAND|INSTALL_COMMAND|CONFIGURE_COMMAND)$")
        set(skip TRUE)
      else ()
        set(skip FALSE)
      endif ()
    endif ()
    if (NOT skip)
      list(APPEND args
        "${arg}")
    endif ()
  endforeach ()

  # Quote args to keep empty list elements around so that we properly parse
  # empty install, configure, build, etc.
  ExternalProject_Add("${name}" "${args}")

  # configure the scripts after the call ExternalProject_Add() since that sets
  # up the directories correctly.
  get_target_property(process_environment "sb-${name}"
    _SB_PROCESS_ENVIRONMENT)
  _ep_replace_location_tags("${name}" process_environment)

  foreach (step configure build install)
    if (req_${step}_command)
      string(TOUPPER "${step}" step_upper)

      set(step_command "${original_${step}_command}")
      _ep_replace_location_tags("${name}" step_command)

      configure_file(
        "${CMAKE_CURRENT_LIST_DIR}/cmake/superbuild_handle_environment.cmake.in"
        "${CMAKE_CURRENT_BINARY_DIR}/sb-${name}-${step}.cmake"
        @ONLY)
    endif ()
  endforeach ()
endfunction ()