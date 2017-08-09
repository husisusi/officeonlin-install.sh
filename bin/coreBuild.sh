#!/bin/bash
# shellcheck disable=SC2154
# this script contains:
## configure script
## build script
# build LibreOffice if it has'nt been built already or lo_forcebuild is true
if [ ! -d ${lo_dir}/instdir ] || ${lo_forcebuild}; then
  if ${sh_interactive}; then
    dialog --backtitle "Information" \
    --title "${lo_src_branch} is going to be built." \
    --msgbox "THE COMPILATION WILL TAKE REALLY A VERY LONG TIME,\nAROUND $((16/cpu)) HOURS (Depending on your CPU's speed),\n
SO BE PATIENT PLEASE! ! You may see errors during the installation, just ignore them and let it do the work." 10 78
    clear
  fi
  {
  cd ${lo_dir} || exit
  ${lo_mini} && lo_configure_opts="${lo_configure_opts} ${lo_mini_opts}"
  ${lo_forcebuild} && [ -f ${lo_dir}/configure ] && make clean uninstall
  if ! sudo -Hu lool ./autogen.sh ${lo_configure_opts}; then exit 2; fi

  # libreoffice take around 8/${cpu} hours to compile on fast cpu.
  # ${lo_forcebuild} && sudo -Hu lool make clean
  if ! sudo -Hu lool make; then exit 2; fi
  } > >(tee -a ${log_dir}/LO-compilation.log) 2> >(tee -a ${log_dir}/LO-compilation.log >&2)
fi
unset repChanged
