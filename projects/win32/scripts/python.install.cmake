foreach (dir bin include lib share)
  file(GLOB files "${dir}/*")
  file(INSTALL ${files}
       DESTINATION "${install_location}/${dir}")
endforeach ()
