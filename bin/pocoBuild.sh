#!/bin/bash
# shellcheck disable=SC2154
# this script contains:
## configure script
## build script
## test if the poco library has already been compiled
# (the dir size should be around 450000ko vs 65000ko when just extracted)
# so let say arbitrary : do compilation when folder size is less than 100Mo
if [ "$(du -s ${poco_dir} | awk '{print $1}')" -lt 100000 ] || ${poco_forcebuild}; then
  cd "$poco_dir" || exit
  sudo -Hu cool ./configure || exit 3
  $poco_forcebuild && sudo -Hu cool make clean
  sudo -Hu cool make -j${cpu}
  # poco take around 22/${cpu} minutes to compile on fast cpu
  make install
fi
