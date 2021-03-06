if (BUILD_SHARED_LIBS)
  set(ffmpeg_shared_args --enable-shared --disable-static)
else ()
  set(ffmpeg_shared_args --disable-shared --enable-static)
endif ()

superbuild_add_project(ffmpeg
  DEPENDS zlib
  CONFIGURE_COMMAND
    <SOURCE_DIR>/configure
      --prefix=<INSTALL_DIR>
      --disable-avdevice
      --disable-bzlib
      --disable-decoders
      --disable-doc
      --disable-ffplay
      --disable-ffprobe
      --disable-ffserver
      --disable-network
      --disable-yasm
      ${ffmpeg_shared_args}
      --cc=${CMAKE_C_COMPILER}
      "--extra-cflags=${superbuild_c_flags}"
      "--extra-ldflags=${superbuild_ld_flags}"
      ${extra_commands}
  BUILD_COMMAND
    $(MAKE)
  INSTALL_COMMAND
    make install
  BUILD_IN_SOURCE 1)
