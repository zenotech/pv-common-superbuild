function (superbuild_qt_sanity_check)
  if (qt4_enabled AND qt5_enabled)
    message(FATAL_ERROR "qt4 and qt5 cannot be enabled at the same time.")
  endif ()
endfunction ()