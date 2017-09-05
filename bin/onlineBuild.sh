#!/bin/bash
# shellcheck disable=SC2154,SC2034
# this script contains:
## configure script
## build script
#####################
#####################
#### loolwsd & loleaflet Build ##
 # Idempotence : do not recompile loolwsd, install & test if already done
if [ -f ${lool_dir}/loolwsd ] && ! ${lool_forcebuild}; then
  if [ ! -f /lib/systemd/system/$loolwsd_service_name.service ]; then
    admin_pwd=$(awk -F'password=' '{printf $2}' /lib/systemd/system/$loolwsd_service_name.service )
    rm /lib/systemd/system/$loolwsd_service_name.service
  fi
  # leave if loowsd is already compiled and lool_forcebuild is not true.
  echo -e "Loolwsd is already in the expected state and I'm not forced to rebuild.\nLeaving here..."
  exit 1
fi

### add temporary lool user to sudoers for loolwsd build ###
# first check if lool group is in sudoers
# or in the includedir directory if it's used
if [ -f /etc/sudoers ] && ! grep -q 'lool' /etc/sudoers; then
  if ! grep -q '#includedir' /etc/sudoers; then
    #dirty modification
    echo "%lool ALL=NOPASSWD:ALL" >> /etc/sudoers
  else
    includedir=$(grep '#includedir' /etc/sudoers | awk '{print $NF}')
    grep -qri '%lool' ${includedir} || echo "%lool ALL=NOPASSWD:ALL" >> ${includedir}/99_lool
  fi
fi
chown lool:lool ${lool_dir} -R
cd ${lool_dir} || exit
${lool_forcebuild} && [ -f ${lool_dir}/configure ] && make clean uninstall
sudo -Hu lool ./autogen.sh
[ -n "${lool_logfile}" ] && lool_configure_opts="${lool_configure_opts} --with-logfile=${lool_logfile}"
sudo -Hu lool bash -c "./configure --enable-silent-rules --with-lokit-path=${lool_dir}/bundled/include --with-lo-path=${lo_dir}/instdir --with-max-connections=$lool_maxcon --with-max-documents=$lool_maxdoc --with-poco-includes=/usr/local/include --with-poco-libs=/usr/local/lib ${lool_configure_opts}" || exit 4
# loolwsd+loleaflet take around 8.5/${cpu} minutes to compile on fast cpu
sudo -Hu lool make -j$cpu --directory=${lool_dir}
_loolwsd_make_rc=${?} # get the make return code
### remove lool group from sudoers
if [ -f /etc/sudoers ]; then
  sed -i '/^\%lool /d' /etc/sudoers
  rm "$(grep -rl '%lool' ${includedir})"
fi
##leave if make loowsd has failed
[ ${_loolwsd_make_rc} -ne 0 ] && exit 4
