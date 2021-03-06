superbuild_add_project(matplotlib
  CAN_USE_SYSTEM
  DEPENDS python numpy png freetype zlib pythonsetuptools
  DEPENDS_OPTIONAL cxx11
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND
    "${CMAKE_COMMAND}"
      "-Dpatches_location:PATH=${CMAKE_CURRENT_LIST_DIR}/patches"
      "-Dsource_location:PATH=<SOURCE_DIR>"
      "-Dinstall_location:PATH=<INSTALL_DIR>"
      -P "${CMAKE_CURRENT_LIST_DIR}/scripts/matplotlib.patch.cmake"
  BUILD_COMMAND
    "${CMAKE_COMMAND}"
      "-DPYTHON_EXECUTABLE:PATH=${superbuild_python_executable}"
      "-Dsource_location:PATH=<SOURCE_DIR>"
      "-Dinstall_location:PATH=<INSTALL_DIR>"
      -P "${CMAKE_CURRENT_LIST_DIR}/scripts/matplotlib.build.cmake"
  INSTALL_COMMAND "")
