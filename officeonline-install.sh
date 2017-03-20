#!/bin/bash
#VERSION 1.5.1
#Written by: Subhi H.
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
clear
###############################################################################
################################# Parameters ##################################
### Script parameters ###
soli="/etc/apt/sources.list"
cpu=$(nproc)
log_file="/tmp/officeonline.log"

### LibreOffice parameters ###
lo_src_repo='http://download.documentfoundation.org/libreoffice/src'
lo_major_v='' #5.3.1
lo_version='' #5.3.1.2
lo_dir="/opt/libreoffice"
lo_forcebuild=false

### LibreOffice Online parameters ###
lool_dir="/opt/online"
lool_forcebuild=false
lool_maxcon=200
lool_maxdoc=100

###############################################################################
############################# System preparation ##############################
# run apt update && upgrade if last update is older than 1 day
find /var/lib/apt/lists/ -mtime -1 |grep -q partial || apt-get update && apt-get upgrade -y

apt-get install dialog -y
dialog --backtitle "Information" \
--title "Note" \
--msgbox 'THE INSTALLATION WILL TAKE REALLY VERY LONG TIME, 2-8 HOURS (It depends on the speed of your server), SO BE PATIENT PLEASE!!! You may see errors during the installation, just ignore them and let it do the work.' 10 78
clear

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

###############################################################################
######################## libreoffice compilation ##############################
#verify what version need to be downloaded if no version has been defined in config
if [ -z "${lo_version}" ];then
  [ -z "${lo_major_v}" ] && lo_major_v=$(curl -s ${lo_src_repo}/ | grep -oiE '^.*href="([0-9+]\.)+[0-9]/"'| tail -1 | sed 's/.*href="\(.*\)\/"$/\1/')
  lo_version=$(curl -s ${lo_src_repo}/${lo_major_v}/ | grep -oiE 'libreoffice-5.[0-9+]\.[0-9+]\.[0-9]' | awk 'NR == 1')
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

# build LibreOffice if it has'nt been built already or lo_forcebuild is true
if [ ! -d ${lo_dir}/instdir ] || ${lo_forcebuild}; then
sudo -u lool bash -c "cd ${lo_dir} && ./autogen.sh --without-help --without-myspell-dicts" | tee -a $log_file
sudo -u lool bash -c "cd ${lo_dir} && make" | tee -a $log_file
fi

###############################################################################
############################# Poco Installation ###############################

poco_version=$(curl -s https://pocoproject.org/ | grep -oiE 'The latest stable release is [0-9+]\.[0-9\.]{1,}[0-9]{1,}' | awk '{print $NF}')
poco="/opt/poco-${poco_version}-all"
if [ ! -d $poco ]; then
  [ ! -f /opt/poco-${poco_version}-all.tar.gz ] &&\
  wget -c https://pocoproject.org/releases/poco-${poco_version}/poco-${poco_version}-all.tar.gz -P /opt/
  tar xf /opt/poco-${poco_version}-all.tar.gz -C  /opt/
  chown lool:lool $poco -R
fi

######## Poco Build ########
## test if the poco poco has already been compiled
# (the dir size should be around 450000ko vs 65000ko when no compilation)
# so lets say arbitrary : do compilation when folder size is less than 100Mo
if [ $(du -s ${poco} | awk '{print $1}') -lt 100000 ]; then
  cd "$poco"
  sudo -u lool ./configure | tee -a $log_file
  sudo -u lool make -j${cpu} | tee -a $log_file
  make install | tee -a $log_file
fi
###############################################################################
########################### loolwsd Installation ##############################
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
#####################
#### loolwsd Build ##
cd ${lool_dir}
[ -f ${lool_dir}/loolwsd ] || ${lool_forcebuild} && make clean
sudo -u lool ./autogen.sh
sudo -u lool bash -c "./configure --enable-silent-rules --with-lokit-path=${lool_dir}/bundled/include --with-lo-path=${lo_dir}/instdir --with-max-connections=$lool_maxcon --with-max-documents=$lool_maxdoc --with-poco-includes=/usr/local/include --with-poco-libs=/usr/local/lib --enable-debug" | tee -a $log_file
sudo -u lool bash -c "make -j$cpu --directory=${lool_dir}" | tee -a $log_file

### remove lool group from sudoers
if [ -f /etc/sudoers ]; then
  sed -i '/^\%lool /d' /etc/sudoers
  rm $(grep -l '%lool' ${includedir})
fi
#####################
#### loolwsd Installation ###
make install | tee -a $log_file
mkdir -p /usr/local/var/cache/loolwsd && chown -R lool:lool /usr/local/var/cache/loolwsd

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
### Testing loolwsd ###
dialog --backtitle "Information" \
--title "Note" \
--msgbox 'The installation log file is in '"${log_file}"'. After reboot you can use loolwsd.service using: systemctl (start,stop or status) loolwsd.service.
Your user is admin and password is '"$PASSWORD"'. Please change your user and/or password in (/lib/systemd/system/loolwsd.service),
after that run (systemctl daemon-reload && systemctl restart loolwsd.service). Please press OK and wait 15 sec. I will start the service.' 10 145

clear

sudo -u lool bash -c "${lool_dir}/loolwsd --o:sys_template_path=${lool_dir}/systemplate --o:lo_template_path=${lo_dir}/instdir  --o:child_root_path=${lool_dir}/jails --o:storage.filesystem[@allow]=true --o:admin_console.username=admin --o:admin_console.password=admin &"
rm -rf ${lo_dir}/workdir
sleep 10
ps -u lool | grep loolwsd
if [ $?  -eq "0" ]; then
  echo -e "\033[33;7m### loolwsd is running. Enjoy!!! ###\033[0m"
  ps -u lool -o pid,cmd | grep loolwsd |awk '{print $1}' | xargs kill
  systemctl start loolwsd
  systemctl enable loolwsd.service
else
  echo -e "\033[33;5m### loolwsd is not running. Something went wrong :| Please look in ${log_file} ###\033[0m"
fi
lsof -i :9980
exit
