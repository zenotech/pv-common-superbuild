set(package_name matplotlib)
set(version 1.1.1)
include(python.bundle.common)

set(modules matplotlib)
include(python.package.bundle)

install(
  DIRECTORY   "${superbuild_install_location}/bin/Lib/site-packages/matplotlib/mpl-data/"
  DESTINATION "bin/Lib/site-packages/matplotlib/mpl-data"
  COMPONENT   superbuild)
