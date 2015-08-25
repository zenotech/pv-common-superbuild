include(PVExternalProject)
include(CMakeParseArguments)

#------------------------------------------------------------------------------
function(add_external_dummy_project_internal name)
  set(arg_DEPENDS)
  get_project_depends(${name} arg)
  ExternalProject_Add(${name}
  DEPENDS ${arg_DEPENDS}
  DOWNLOAD_COMMAND ""
  SOURCE_DIR ""
  UPDATE_COMMAND ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
  )
endfunction()

#------------------------------------------------------------------------------
function(add_external_project_internal name)
  set (cmake_params)
  foreach (flag CMAKE_BUILD_TYPE
                CMAKE_C_FLAGS_DEBUG
                CMAKE_C_FLAGS_MINSIZEREL
                CMAKE_C_FLAGS_RELEASE
                CMAKE_C_FLAGS_RELWITHDEBINFO
                CMAKE_CXX_FLAGS_DEBUG
                CMAKE_CXX_FLAGS_MINSIZEREL
                CMAKE_CXX_FLAGS_RELEASE
                CMAKE_CXX_FLAGS_RELWITHDEBINFO)
    if (flag)
      list (APPEND cmake_params -D${flag}:STRING=${${flag}})
    endif()
  endforeach()

  if (APPLE)
    list (APPEND cmake_params
      -DCMAKE_OSX_ARCHITECTURES:STRING=${CMAKE_OSX_ARCHITECTURES}
      -DCMAKE_OSX_DEPLOYMENT_TARGET:STRING=${CMAKE_OSX_DEPLOYMENT_TARGET}
      -DCMAKE_OSX_SYSROOT:PATH=${CMAKE_OSX_SYSROOT})
  endif()

  #get extra-cmake args from every dependent project, if any.
  set(arg_DEPENDS)
  get_project_depends(${name} arg)
  foreach(dependency IN LISTS arg_DEPENDS)
    get_property(args GLOBAL PROPERTY ${dependency}_CMAKE_ARGS)
    list(APPEND cmake_params ${args})
  endforeach()

  # get extra flags added using append_flags(), if any.
  set (extra_c_flags)
  set (extra_cxx_flags)
  set (extra_ld_flags)

  # scan project flags.
  set (_tmp)
  get_property(_tmp GLOBAL PROPERTY ${name}_APPEND_PROJECT_ONLY_FLAGS_CMAKE_C_FLAGS)
  set (extra_c_flags ${extra_c_flags} ${_tmp})
  get_property(_tmp GLOBAL PROPERTY ${name}_APPEND_PROJECT_ONLY_FLAGS_CMAKE_CXX_FLAGS)
  set (extra_cxx_flags ${extra_cxx_flags} ${_tmp})
  get_property(_tmp GLOBAL PROPERTY ${name}_APPEND_PROJECT_ONLY_FLAGS_LDFLAGS)
  set (extra_ld_flags ${extra_ld_flags} ${_tmp})
  unset(_tmp)

  # scan dependecy flags.
  foreach(dependency IN LISTS arg_DEPENDS)
    get_property(_tmp GLOBAL PROPERTY ${dependency}_APPEND_FLAGS_CMAKE_C_FLAGS)
    set (extra_c_flags ${extra_c_flags} ${_tmp})
    get_property(_tmp GLOBAL PROPERTY ${dependency}_APPEND_FLAGS_CMAKE_CXX_FLAGS)
    set (extra_cxx_flags ${extra_cxx_flags} ${_tmp})
    get_property(_tmp GLOBAL PROPERTY ${dependency}_APPEND_FLAGS_LDFLAGS)
    set (extra_ld_flags ${extra_ld_flags} ${_tmp})
  endforeach()

  set (project_c_flags "${cflags}")
  if (extra_c_flags)
    set (project_c_flags "${cflags} ${extra_c_flags}")
  endif()
  set (project_cxx_flags "${cxxflags}")
  if (extra_cxx_flags)
    set (project_cxx_flags "${cxxflags} ${extra_cxx_flags}")
  endif()
  set (project_ld_flags "${ldflags}")
  if (extra_ld_flags)
    set (project_ld_flags "${ldflags} ${extra_ld_flags}")
  endif()

  #message("ARGS ${name} ${ARGN}")

  # refer to documentation for PASS_LD_LIBRARY_PATH_FOR_BUILDS in
  # in root CMakeLists.txt.
  set (ld_library_path_argument)
  if (PASS_LD_LIBRARY_PATH_FOR_BUILDS)
    set (ld_library_path_argument
      LD_LIBRARY_PATH "${ld_library_path}")
  endif ()


  #args needs to be quoted so that empty list items aren't removed
  #if that happens options like INSTALL_COMMAND "" won't work
  set(args "${ARGN}")
  PVExternalProject_Add(${name} "${args}"
    PREFIX ${name}
    DOWNLOAD_DIR ${download_location}
    INSTALL_DIR ${install_location}

    # add url/mdf/git-repo etc. specified in versions.cmake
    ${${name}_revision}

    PROCESS_ENVIRONMENT
      LDFLAGS "${project_ld_flags}"
      CPPFLAGS "${cppflags}"
      CXXFLAGS "${project_cxx_flags}"
      CFLAGS "${project_c_flags}"
# disabling this since it fails when building numpy.
#      MACOSX_DEPLOYMENT_TARGET "${CMAKE_OSX_DEPLOYMENT_TARGET}"
      ${ld_library_path_argument}
      CMAKE_PREFIX_PATH "${prefix_path}"
    CMAKE_ARGS
      -DCMAKE_INSTALL_PREFIX:PATH=${prefix_path}
      -DCMAKE_PREFIX_PATH:PATH=${prefix_path}
      -DCMAKE_C_FLAGS:STRING=${project_c_flags}
      -DCMAKE_CXX_FLAGS:STRING=${project_cxx_flags}
      -DCMAKE_SHARED_LINKER_FLAGS:STRING=${project_ld_flags}
      ${cmake_params}

    LIST_SEPARATOR "${ep_list_separator}"
    )

  get_property(additional_steps GLOBAL PROPERTY ${name}_STEPS)
  if (additional_steps)
     foreach (step ${additional_steps})
       get_property(step_contents GLOBAL PROPERTY ${name}-STEP-${step})
       ExternalProject_Add_Step(${name} ${step} ${step_contents})
     endforeach()
  endif()
endfunction()

#------------------------------------------------------------------------------
# When passing string with ";" to add_external_project() macros, we need to
# ensure that the -+- is replaced with the LIST_SEPARATOR.
macro(sanitize_lists_in_string out_var_prefix var)
  string(REPLACE ";" "${ep_list_separator}" command "${${var}}")
  set (${out_var_prefix}${var} "${command}")
endmacro()
