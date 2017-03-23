#!/bin/bash
#VERSION 2.1.0
#Written by: Subhi H. & Marc C.
#Github Contributors: Aalaesar, Kassiematis, morph027
#This script is free software: you can redistribute it and/or modify it under
#the terms of the GNU General Public License as published by the Free Software
#Foundation, either version 3 of the License, or (at your option) any later version.

#This script is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
#or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#You should have received a copy of the GNU General Public License along with
#this program. If not, see http://www.gnu.org/licenses/.

if [[ `id -u` -ne 0 ]] ; then echo 'Please run me as root or "sudo ./officeonline-install.sh"' ; exit 1 ; fi

randpass() {
  [ "$2" == "0" ] && CHAR="[:alnum:]" || CHAR="[:graph:]"
  cat /dev/urandom 2>/dev/null | tr -cd "$CHAR" 2>/dev/null | head -c ${1:-32}
}
getFilesystem() {
  # function return the filesystem of a folder
  # arg 1 is an existing folder
  [ ! -d $1 ] &&  echo "error: $1 do not exists or is not a valid directory." >&2 && return 1
  echo $(df --output=source $1 | tail -1)
  return 0
}
checkAvailableSpace() {
  # function check if the required space is available and create an error if the requirement is not satisfied
  # take 2 args :
    # arg1 : a file system/block file like /dev/sda1
    # arg2 : required space in MB
  # return:
    # stdout: available disk space in MB
    # stderr: error message.
    # rc1 if not enought space is available
    # rc2 bad parameters
  [ $# -ne 2 ] && return 2
  local CompFs=$1
  local CompRequirement=$2
  # check the arguments:
  [ ! -b ${CompFs} ] && echo "Error: ${CompFs} is not a valid filesystem" >&2 && return 2
  availableMB=$(df -m --output=avail ${CompFs}|tail -1)
  if [ ${availableMB} -lt ${CompRequirement} ]; then
    echo "${CompFs}: FAILED"
    echo "Not Enough space available on ${CompName} (${CompRequirement} MiB required)" >&2
    echo "(only ${availableMB} MiB available)" >&2
    echo "Exiting." >&2
    return 1
  else
    echo "${availableMB}"
  fi
  return 0
}
clear
###############################################################################
################################# Parameters ##################################
###############################################################################
### Script parameters ###
soli="/etc/apt/sources.list"
cpu=$(nproc)
log_file="/tmp/$(date +'%Y%m%d-%H%M')_officeonline.log"
sh_interactive=true

### LibreOffice parameters ###
lo_src_repo='http://download.documentfoundation.org/libreoffice/src'
lo_version='' #5.3.1.2
lo_dir="/opt/libreoffice"
lo_forcebuild=false # force compilation
lo_req_vol=12000 # minimum space required for LibreOffice compilation, in MB

### POCO parameters ###
poco_version=$(curl -s https://pocoproject.org/ | grep -oiE 'The latest stable release is [0-9+]\.[0-9\.]{1,}[0-9]{1,}' | awk '{print $NF}')
poco_dir="/opt/poco-${poco_version}-all"
poco_forcebuild=false
poco_req_vol=510 # minimum space required for Poco compilation, in MB

### LibreOffice Online parameters ###
lool_dir="/opt/online"
lool_configure_opts='--enable-debug'
lool_logfile='/var/log/loolwsd.log'
lool_forcebuild=false
lool_maxcon=200
lool_maxdoc=100
lool_req_vol=600 # minimum space required for LibreOffice Online compilation, in MB

###############################################################################
################################# OPERATIONS ##################################
###############################################################################
#clear the logs in case of super multi fast script run.
[ -f ${log_file} ] && rm ${log_file}
{
###############################################################################
############################ System Requirements ##############################
echo "Verifying System Requirements:"
### Test RAM size (4GB min) ###
mem_available=$(grep MemTotal /proc/meminfo| grep -o '[0-9]\+')
if [ ${mem_available} -lt 4000000 ]; then
  echo "Error: The system do not meet the minimum requirements." >&2
  echo "Error: 4GB RAM required!" >&2
  exit 1
else
  echo "Memory: OK ($((mem_available/1024)) MiB)"
fi
### Calculate required disk space per file system ###
# find the target filesystem for each sw and add the required space for this FS
# on an array BUT only if no build have been done yet.
lo_fs=$(getFilesystem $(dirname $lo_dir)) || exit 1
poco_fs=$(getFilesystem /opt) || exit 1
lool_fs=$(getFilesystem $(dirname $lool_dir)) || exit 1
#here we use an array to store a relative number of FS and their respective required volume
#if, like in the default, LO, poco & LOOL are all stored on the same FS, the value add-up
declare -A mountPointArray # declare associative array
if [ ! -d ${lo_dir}/instdir ]; then
  mountPointArray["$lo_fs"]=$((mountPointArray["$lo_fs"]+$lo_req_vol))
fi
if [ $(du -s ${poco_dir} | awk '{print $1}') -lt 100000 ]; then
  mountPointArray["$poco_fs"]=$((mountPointArray["$poco_fs"]+$poco_req_vol))
fi
if [ ! -f ${lool_dir}/loolwsd ]; then
  mountPointArray["$lool_fs"]=$((mountPointArray["$poco_fs"]+$lool_req_vol))
fi
# test if each file system used have the required space.
# if there's nothing to (force-)build (so 0 FS to verify), the script leave here.
if [ ${#mountPointArray[@]} -ne 0 ]; then
  for fs_item in "${!mountPointArray[@]}"; do
    fs_item_avail=$(checkAvailableSpace $fs_item ${mountPointArray["$fs_item"]}) || exit 1
    echo "${fs_item}: PASSED (${mountPointArray["$fs_item"]} MiB Req., ${fs_item_avail} MiB avail.)"
  done
elif ! $lo_forcebuild && ! $lool_forcebuild && ! $poco_forcebuild; then
  echo "Nothing to build here..."
  exit 0
fi

###############################################################################
############################# System preparation ##############################
###### Checking system requirement
# run apt update && upgrade if last update is older than 1 day
find /var/lib/apt/lists/ -mtime -1 |grep -q partial || apt-get update && apt-get upgrade -y

${sh_interactive} && apt-get install dialog -y

grep -q '# deb-src' ${soli} && sed -i 's/# deb-src/deb-src/g' ${soli} && apt-get update

apt-get install sudo curl libegl1-mesa-dev libkrb5-dev systemd python-polib git libkrb5-dev make openssl g++ libtool ccache libpng12-0 libpng12-dev libpcap0.8 libpcap0.8-dev libcunit1 libcunit1-dev libpng12-dev libcap-dev libtool m4 automake libcppunit-dev libcppunit-doc pkg-config wget libfontconfig1-dev -y
[ $? -ne 0 ] && exit 1
apt-get build-dep libreoffice -y

if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
  curl -sL https://deb.nodesource.com/setup_6.x | bash -
  apt-get install nodejs -y
fi

getent passwd lool || (useradd lool -G sudo; mkdir /home/lool)
chown lool:lool /home/lool -R
} > >(tee -a ${log_file}) 2> >(tee -a ${log_file} >&2)

###############################################################################
######################## libreoffice compilation ##############################
{
#verify what version need to be downloaded if no version has been defined in config
if [ -z "${lo_version}" ];then
  lo_major_v=$(curl -s ${lo_src_repo}/ | grep -oiE '^.*href="([0-9+]\.)+[0-9]/"'| tail -1 | sed 's/.*href="\(.*\)\/"$/\1/')
  lo_version=$(curl -s ${lo_src_repo}/${lo_major_v}/ | grep -oiE 'libreoffice-5.[0-9+]\.[0-9+]\.[0-9]' | awk 'NR == 1')
else
  lo_major_v=$(echo ${lo_version} | cut -d '.' -f1-3)
fi
# check is libreoffice sources are already present and in the correct version
if [ -d ${lo_dir} ]; then
  lo_local_version="libreoffice-$(grep 'PACKAGE_VERSION=' ${lo_dir}/configure | cut -d \' -f 2)"
  # rename the folder if not in the expected verion
  [ ${lo_local_version} != ${lo_version} ] && mv ${lo_dir} ${lo_local_version}
fi
# download and extract libreoffice source only if not here
if [ ! -f ${lo_dir}/autogen.sh ]; then
  [ ! -f $lo_version.tar.xz ] && wget -c ${lo_src_repo}/${lo_major_v}/$lo_version.tar.xz -P /opt/
  [ ! -d $lo_version ] && tar xf /opt/$lo_version.tar.xz -C  /opt/
  mv /opt/$lo_version ${lo_dir}
  chown lool:lool ${lo_dir} -R
fi
} > >(tee -a ${log_file}) 2> >(tee -a ${log_file} >&2)

# build LibreOffice if it has'nt been built already or lo_forcebuild is true
if [ ! -d ${lo_dir}/instdir ] || ${lo_forcebuild}; then
  if ${sh_interactive}; then
    dialog --backtitle "Information" \
    --title "${lo_version} is going to be built." \
    --msgbox "THE COMPILATION WILL TAKE REALLY A VERY LONG TIME,\nAROUND $((16/${cpu})) HOURS (Depending on your CPU's speed),\n"\
"SO BE PATIENT PLEASE! ! You may see errors during the installation, just ignore them and let it do the work." 10 78
    clear
  fi
  {
  cd ${lo_dir}
  sudo -Hu lool ./autogen.sh --without-help --without-myspell-dicts
  [ $? -ne 0 ] && exit 2
  # libreoffice take around 8/${cpu} hours to compile on fast cpu.
  ${lo_forcebuild} && sudo -Hu lool make clean
  sudo -Hu lool make
  [ $? -ne 0 ] && exit 2
  } > >(tee -a ${log_file}) 2> >(tee -a ${log_file} >&2)
fi

###############################################################################
############################# Poco Installation ###############################
{
if [ ! -d $poco_dir ]; then
  [ ! -f /opt/poco-${poco_version}-all.tar.gz ] &&\
  wget -c https://pocoproject.org/releases/poco-${poco_version}/poco-${poco_version}-all.tar.gz -P /opt/
  tar xf /opt/poco-${poco_version}-all.tar.gz -C  /opt/
  chown lool:lool $poco_dir -R
fi
} > >(tee -a ${log_file}) 2> >(tee -a ${log_file} >&2)

######## Poco Build ########
{
## test if the poco library has already been compiled
# (the dir size should be around 450000ko vs 65000ko when just extracted)
# so let say arbitrary : do compilation when folder size is less than 100Mo
if [ $(du -s ${poco_dir} | awk '{print $1}') -lt 100000 ] || ${poco_forcebuild}; then
  cd "$poco_dir"
  sudo -Hu lool ./configure
  [ $? -ne 0 ] && exit 3
  $poco_forcebuild && sudo -Hu lool make clean
  sudo -Hu lool make -j${cpu}
  [ $? -ne 0 ] && exit 3
  # poco take around 22/${cpu} minutes to compile on fast cpu
  make install
  [ $? -ne 0 ] && exit 3
fi
} > >(tee -a ${log_file}) 2> >(tee -a ${log_file} >&2)
###############################################################################
########################### loolwsd Installation ##############################
{
#### Download dependencies ####
if [ ! -d ${lool_dir} ]; then
  git clone https://github.com/husisusi/online ${lool_dir}
  chown lool:lool ${lool_dir} -R
fi

if ! npm -g list jake >/dev/null; then
  npm install -g npm
  npm install -g jake
fi
#####################
#####################
#### loolwsd & loleaflet Build ##
 # Idempotence : do not recompile loolwsd, install & test if already done
if [ -f ${lool_dir}/loolwsd ] && ! ${lool_forcebuild}; then
  # leave if loowsd is already compiled and lool_forcebuild is not true.
  echo -e "Loolwsd is already compiled and I'm not forced to recompile.\nLeaving here..."
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
cd ${lool_dir}
[ -f ${lool_dir}/loolwsd ] && sudo -Hu lool make clean
sudo -Hu lool ./autogen.sh
[ -n "${lool_logfile}" ] && lool_configure_opts="${lool_configure_opts} --with-logfile=${lool_logfile}"
sudo -Hu lool bash -c "./configure --enable-silent-rules --with-lokit-path=${lool_dir}/bundled/include --with-lo-path=${lo_dir}/instdir --with-max-connections=$lool_maxcon --with-max-documents=$lool_maxdoc --with-poco-includes=/usr/local/include --with-poco-libs=/usr/local/lib ${lool_configure_opts}"
[ $? -ne 0 ] && exit 4
# loolwsd+loleaflet take around 8.5/${cpu} minutes to compile on fast cpu
sudo -Hu lool make -j$cpu --directory=${lool_dir}
_loolwsd_make_rc=${?} # get the make return code
### remove lool group from sudoers
if [ -f /etc/sudoers ]; then
  sed -i '/^\%lool /d' /etc/sudoers
  rm $(grep -l '%lool' ${includedir})
fi
##leave if make loowsd has failed
[ ${_loolwsd_make_rc} -ne 0 ] && exit 4
#####################
#### loolwsd Installation ###
make install
mkdir -p /usr/local/var/cache/loolwsd && chown -R lool:lool /usr/local/var/cache/loolwsd

# create log file for lool user
[ -n "${lool_logfile}" ] && [ ! -f ${lool_logfile} ] && touch ${lool_logfile}
chown lool:lool ${lool_logfile}
# create the hello-world file for test & demo
sudo -Hu lool cp ${lool_dir}/test/data/hello.odt ${lool_dir}/test/data/hello-world.odt

if [ ! -f /lib/systemd/system/loolwsd.service ]; then
  PASSWORD=$(randpass 10 0)
  cat <<EOT > /lib/systemd/system/loolwsd.service
[Unit]
Description=LibreOffice OnLine WebSocket Daemon
After=network.target

[Service]
EnvironmentFile=-/etc/sysconfig/loolwsd
ExecStartPre=/bin/mkdir -p /usr/local/var/cache/loolwsd
ExecStartPre=/bin/chown lool: /usr/local/var/cache/loolwsd
PermissionsStartOnly=true
ExecStart=${lool_dir}/loolwsd --o:sys_template_path=${lool_dir}/systemplate --o:lo_template_path=${lo_dir}/instdir  --o:child_root_path=${lool_dir}/jails --o:storage.filesystem[@allow]=true --o:admin_console.username=admin --o:admin_console.password=$PASSWORD
User=lool
KillMode=control-group
# Restart=always

[Install]
WantedBy=multi-user.target
EOT
fi

if [ ! -f /etc/loolwsd/ca-chain.cert.pem ]; then
  mkdir /etc/loolwsd
  openssl genrsa -out /etc/loolwsd/key.pem 4096
  openssl req -out /etc/loolwsd/cert.csr -key /etc/loolwsd/key.pem -new -sha256 -nodes -subj "/C=DE/OU=onlineoffice-install.com/CN=onlineoffice-install.com/emailAddress=nomail@nodo.com"
  openssl x509 -req -days 365 -in /etc/loolwsd/cert.csr -signkey /etc/loolwsd/key.pem -out /etc/loolwsd/cert.pem
  openssl x509 -req -days 365 -in /etc/loolwsd/cert.csr -signkey /etc/loolwsd/key.pem -out /etc/loolwsd/ca-chain.cert.pem
fi
if [! -e /etc/systemd/system/loolwsd.service ]; then
  ln /lib/systemd/system/loolwsd.service /etc/systemd/system/loolwsd.service
fi
} > >(tee -a ${log_file}) 2> >(tee -a ${log_file} >&2)
### Testing loolwsd ###
if ${sh_interactive}; then
  PASSWORD=$(awk -F'password=' '{printf $2}' /lib/systemd/system/loolwsd.service )
  dialog --backtitle "Information" \
  --title "Note" \
  --msgbox "The installation log file is in ${log_file}. After reboot you can use loolwsd.service using: systemctl (start,stop or status) loolwsd.service.\n"\
"Your user is admin and password is $PASSWORD. Please change your user and/or password in (/lib/systemd/system/loolwsd.service),\n"\
"after that run (systemctl daemon-reload && systemctl restart loolwsd.service).\nPlease press OK and wait 15 sec. I will start the service." 10 145
  clear
fi
{
sudo -Hu lool bash -c "${lool_dir}/loolwsd --o:sys_template_path=${lool_dir}/systemplate --o:lo_template_path=${lo_dir}/instdir  --o:child_root_path=${lool_dir}/jails --o:storage.filesystem[@allow]=true --o:admin_console.username=admin --o:admin_console.password=admin &"
rm -rf ${lo_dir}/workdir
sleep 18
ps -u lool | grep loolwsd
if [ $?  -eq "0" ]; then
  echo -e "\033[33;7m### loolwsd is running. Enjoy!!! ###\033[0m"
  lsof -i :9980
  ps -u lool -o pid,cmd | grep loolwsd |awk '{print $1}' | xargs kill
  systemctl enable loolwsd.service
else
  echo -e "\033[33;5m### loolwsd is not running. Something went wrong :| Please look in ${log_file} or try to restart your system ###\033[0m"
fi
} > >(tee -a ${log_file}) 2> >(tee -a ${log_file} >&2)
exit 0
