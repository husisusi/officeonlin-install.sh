#!/bin/bash
# shellcheck disable=SC2154,SC2034
# this script contains:
## configure script
## build script
#####################
#####################
#### coolwsd & loleaflet Build ##
 # Idempotence : do not recompile coolwsd, install & test if already done
if [ -f ${cool_dir}/coolwsd ] && ! ${cool_forcebuild}; then
  if [ ! -f /lib/systemd/system/$coolwsd_service_name.service ]; then
    admin_pwd=$(awk -F'password=' '{printf $2}' /lib/systemd/system/$coolwsd_service_name.service )
    rm /lib/systemd/system/$coolwsd_service_name.service
  fi
  # leave if loowsd is already compiled and cool_forcebuild is not true.
  echo -e "coolwsd is already in the expected state and I'm not forced to rebuild.\nLeaving here..."
  exit 1
fi

### add temporary cool user to sudoers for coolwsd build ###
# first check if cool group is in sudoers
# or in the includedir directory if it's used
if [ -f /etc/sudoers ] && ! grep -q 'cool' /etc/sudoers; then
  if ! grep -q '#includedir' /etc/sudoers; then
    #dirty modification
    echo "%cool ALL=NOPASSWD:ALL" >> /etc/sudoers
  else
    includedir=$(grep '#includedir' /etc/sudoers | awk '{print $NF}')
    grep -qri '%cool' ${includedir} || echo "%cool ALL=NOPASSWD:ALL" >> ${includedir}/99_cool
  fi
fi
chown cool:cool ${cool_dir} -R
cd ${cool_dir} || exit
${cool_forcebuild} && [ -f ${cool_dir}/configure ] && make clean uninstall
sudo -Hu cool ./autogen.sh
[ -n "${cool_logfile}" ] && cool_configure_opts="${cool_configure_opts} --with-logfile=${cool_logfile}"
[ -n "${cool_prefix}" ] && cool_configure_opts="${cool_configure_opts} --prefix=${cool_prefix}"
[ -n "${cool_sysconfdir}" ] && cool_configure_opts="${cool_configure_opts} --sysconfdir=${cool_sysconfdir}"
[ -n "${cool_localstatedir}" ] && cool_configure_opts="${cool_configure_opts} --localstatedir=${cool_localstatedir}"

echo ""
echo ""
echo "debug cool configure call: ./configure --enable-silent-rules --with-lokit-path=${cool_dir}/bundled/include --with-lo-path=${lo_dir}/instdir --with-max-connections=$cool_maxcon --with-max-documents=$cool_maxdoc --with-poco-includes=/usr/local/include --with-poco-libs=/usr/local/lib ${cool_configure_opts}"
echo ""
echo ""

sudo -Hu cool bash -c "./configure --enable-silent-rules --with-lokit-path=${cool_dir}/bundled/include --with-lo-path=${lo_dir}/instdir --with-max-connections=$cool_maxcon --with-max-documents=$cool_maxdoc --with-poco-includes=/usr/local/include --with-poco-libs=/usr/local/lib ${cool_configure_opts}" || exit 4
# coolwsd+loleaflet take around 8.5/${cpu} minutes to compile on fast cpu
sudo -Hu cool make -j$cpu --directory=${cool_dir}
cd /opt/cool/browser
npm shrinkwrap --dev
npm install --save
cd ${cool_dir}
sudo -Hu cool make -j$cpu --directory=${cool_dir}
_coolwsd_make_rc=${?} # get the make return code
### remove cool group from sudoers
if [ -f /etc/sudoers ]; then
  sed -i '/^\%cool /d' /etc/sudoers
  rm "$(grep -rl '%cool' ${includedir})"
fi
##leave if make loowsd has failed
[ ${_coolwsd_make_rc} -ne 0 ] && exit 4
