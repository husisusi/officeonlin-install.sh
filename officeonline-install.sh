
#!/bin/bash

#VERSION 1.5
#Written by: Subhi H.
#This script is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

#This script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

if [[ `id -u` -ne 0 ]] ; then echo 'Please run me as root or "sudo ./officeonline-install.sh"' ; exit 1 ; fi

randpass() {
  [ "$2" == "0" ] && CHAR="[:alnum:]" || CHAR="[:graph:]"
  cat /dev/urandom 2>/dev/null | tr -cd "$CHAR" 2>/dev/null | head -c ${1:-32}
}

clear

soli="/etc/apt/sources.list"
log_file="/tmp/officeonline.log"
ooo="/opt/libreoffice"
oo="/opt/online"
cpu=$(nproc)
maxcon=200
maxdoc=100

apt-get update && apt-get -y install dialog

dialog --backtitle "Information" \
--title "Note" \
--msgbox 'THE INSTALLATION WILL TAKE REALLY VERY LONG TIME, 2-8 HOURS (It depends on the speed of your server), SO BE PATIENT PLEASE!!! You may see errors during the installation, just ignore them and let it do the work.' 10 78

clear

sed -i 's/# deb-src/deb-src/g' $soli


apt-get update && apt-get upgrade -y

apt-get install sudo curl libegl1-mesa-dev libkrb5-dev systemd python-polib git libkrb5-dev make openssl g++ libtool ccache libpng12-0 libpng12-dev libpcap0.8 libpcap0.8-dev libcunit1 libcunit1-dev libpng12-dev libcap-dev libtool m4 automake libcppunit-dev libcppunit-doc pkg-config wget libfontconfig1-dev  -y && sudo apt-get build-dep libreoffice -y

curl -sL https://deb.nodesource.com/setup_6.x | bash -
apt-get install nodejs

getent passwd lool || (useradd lool -G sudo; mkdir /home/lool)
chown lool:lool /home/lool -R

lo_version=$(curl -s http://download.documentfoundation.org/libreoffice/src/5.3.0/ | grep -oiE 'libreoffice-5.[0-9+]\.[0-9+]\.[0-9]' | awk 'NR == 1')
wget -c http://download.documentfoundation.org/libreoffice/src/5.3.0/$lo_version.tar.xz -P /opt/
tar xf /opt/$lo_version.tar.xz -C  /opt/
mv /opt/$lo_version $ooo

chown lool:lool $ooo -R

sudo -H -u lool bash -c "for dir in ./ ; do (cd "$ooo" && $ooo/autogen.sh --without-help --without-myspell-dicts); done" | tee -a $log_file
sudo -H -u lool bash -c "for dir in ./ ; do (cd "$ooo" && make); done" | tee -a $log_file

poco_version=$(curl -s https://pocoproject.org/ | grep -oiE 'The latest stable release is [0-9+]\.[0-9\.]{1,}[0-9]{1,}' | awk '{print $NF}')
poco="/opt/poco-${poco_version}-all"
wget -c https://pocoproject.org/releases/poco-${poco_version}/poco-${poco_version}-all.tar.gz -P /opt/
tar xf /opt/poco-${poco_version}-all.tar.gz -C  /opt/
chown lool:lool $poco -R

sudo -H -u lool bash -c "for dir in ./ ; do (cd "$poco" && ./configure); done" | tee -a $log_file
sudo -H -u lool bash -c  "for dir in ./ ; do (cd "$poco" && make -j$cpu); done" | tee -a $log_file
for dir in ./ ; do (cd "$poco" && make install); done | tee -a $log_file

###############################################################################

git clone https://github.com/husisusi/online $oo

chown lool:lool $oo -R
sudo -H -u lool bash -c "for dir in ./ ; do (cd "$oo" && libtoolize && aclocal && autoheader && automake --add-missing && autoreconf); done"

for dir in ./ ; do (cd "$oo" && npm install -g npm); done
for dir in ./ ; do (cd "$oo" && npm install -g jake); done

for dir in ./ ; do ( cd "$oo" && ./configure --enable-silent-rules --with-lokit-path=/opt/online/bundled/include --with-lo-path=/opt/libreoffice/instdir --with-max-connections=$maxcon --with-max-documents=$maxdoc --with-poco-includes=/usr/local/include --with-poco-libs=/usr/local/lib --enable-debug && make -j$cpu --directory=$oo); done | tee -a $log_file
for dir in ./ ; do ( cd "$oo" && make install); done | tee -a $log_file

echo "%lool ALL=NOPASSWD:ALL" >> /etc/sudoers

chown -R lool:lool {$ooo,$poco,$oo}

mkdir -p /usr/local/var/cache/loolwsd
chown -R lool:lool /usr/local/var/cache/loolwsd

PASSWORD=$(randpass 10 0)

cat <<EOT > /lib/systemd/system/loolwsd.service

[Unit]
Description=LibreOffice On-Line WebSocket Daemon
After=network.target

[Service]
EnvironmentFile=-/etc/sysconfig/loolwsd
ExecStart=/opt/online/loolwsd --o:sys_template_path=/opt/online/systemplate --o:lo_template_path=/opt/libreoffice/instdir  --o:child_root_path=/opt/online/jails --o:storage.filesystem[@allow]=true --o:admin_console.username=admin --o:admin_console.password="$PASSWORD"
User=lool
KillMode=control-group
Restart=always

[Install]
WantedBy=multi-user.target
EOT

mkdir /etc/loolwsd
openssl genrsa -out /etc/loolwsd/key.pem 4096
openssl req -out /etc/loolwsd/cert.csr -key /etc/loolwsd/key.pem -new -sha256 -nodes -subj "/C=DE/OU=onlineoffice-install.com/CN=onlineoffice-install.com/emailAddress=nomail@nodo.com"
openssl x509 -req -days 365 -in /etc/loolwsd/cert.csr -signkey /etc/loolwsd/key.pem -out /etc/loolwsd/cert.pem
openssl x509 -req -days 365 -in /etc/loolwsd/cert.csr -signkey /etc/loolwsd/key.pem -out /etc/loolwsd/ca-chain.cert.pem

ln /lib/systemd/system/loolwsd.service /etc/systemd/system/loolwsd.service
systemctl enable loolwsd.service

dialog --backtitle "Information" \
--title "Note" \
--msgbox 'The installation log file is in /tmp/officeonline.log. After reboot you can use loolwsd.service using: systemctl (start,stop or status) loolwsd.service.
Your user is admin and password is "$PASSWORD". Please change your user and/or password in (/lib/systemd/system/loolwsd.service),
after that run (systemctl daemon-reload && systemctl restart loolwsd.service). Please press OK and wait 15 sec. I will start the service.' 10 145

clear

sudo -H -u lool bash -c "for dir in ./ ; do ( cd "$oo" && make run & ); done"
rm -rf /opt/libreoffice/workdir
sleep 10

sed -i '$d' /etc/sudoers
ps -ef | grep loolwsd | grep -v grep
[ $?  -eq "0" ] && echo -e "\033[33;7m### loolwsd is running. Enjoy!!! ###\033[0m" || echo -e "\033[33;5m### loolwsd is not running. Something went wrong :| Please look in /tmp/officeonline.log ###\033[0m"
lsof -i :9980
exit
