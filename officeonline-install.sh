
#!/bin/bash

#VERSION 1.3
#Written by: Subhi H.
#This script is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

#This script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

if [[ `id -u` -ne 0 ]] ; then echo 'Please run me as root or "sudo ./officeonline-install.sh"' ; exit 1 ; fi

echo "Checking for the best mirror available"
apt install python-pip
pip install --upgrade pip apt-select
apt-select
cp /etc/apt/sources.list /etc/apt/sources.list.backup
mv sources.list /etc/apt/
apt update -qq

clear

soli="/etc/apt/sources.list"
log_file="/tmp/officeonline.log"
ood=libreoffice-5.3.0.3
ooo="/opt/libreoffice"
poco="/opt/poco-1.7.7-all"
getpoko=poco-1.7.7-all.tar.gz
oo="/opt/online"
cpu=`nproc`
maxcon=200
maxdoc=100

apt-get update && apt-get install dialog


dialog --backtitle "Information" \
--title "Note" \
--msgbox 'THE INSTALLATION WILL TAKE REALLY VERY LONG TIME, 2-8 HOURS (It depends on the speed of your server), SO BE PATIENT PLEASE!!! You may see errors during the installation, just ignore them and let it do the work.' 10 78

clear

sed -i 's/# deb-src/deb-src/g' $soli

apt-get upgrade -y

apt-get install sudo libegl1-mesa-dev libkrb5-dev python-polib git libkrb5-dev make openssl libopenjp2-tools g++ libtool ccache libpng12-0 libpng12-dev libpcap0.8 libpcap0.8-dev libcunit1 libcunit1-dev libpng12-dev libcap-dev libtool m4 automake libcppunit-dev libcppunit-doc pkg-config npm wget nodejs-legacy libfontconfig1-dev  -y && sudo apt-get build-dep libreoffice -y

useradd lool -G sudo
mkdir /home/lool
chown lool:lool /home/lool -R


wget http://download.documentfoundation.org/libreoffice/src/5.3.0/${ood}.tar.xz -P /opt/
tar xf /opt/${ood}.tar.xz -C  /opt/
mv /opt/$ood $ooo

chown lool:lool $ooo -R



sudo -H -u lool bash -c "for dir in ./ ; do (cd "$ooo" && $ooo/autogen.sh --without-help --without-myspell-dicts); done" | tee -a $log_file
sudo -H -u lool bash -c "for dir in ./ ; do (cd "$ooo" && make); done" | tee -a $log_file
#sudo -H -u lool bash -c "for dir in ./ ; do (cd "$ooo" && make check); done"


######TODO###### We need autocheck last version of pocp and link it to $getpoko   
wget https://pocoproject.org/releases/poco-1.7.7/$getpoko -P /opt/
tar xf /opt/$getpoko -C  /opt/
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

cat <<EOT > /lib/systemd/system/loolwsd.service

[Unit]
Description=LibreOffice On-Line WebSocket Daemon
After=network.target

[Service]
EnvironmentFile=-/etc/sysconfig/loolwsd
ExecStart=/opt/online/loolwsd --o:sys_template_path=/opt/online/systemplate --o:lo_template_path=/opt/libreoffice/instdir  --o:child_root_path=/opt/online/jails --o:storage.filesystem[@allow]=true --o:admin_console.username=admin --o:admin_console.password=office1234
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

systemctl enable loolwsd.service



dialog --backtitle "Information" \
--title "Note" \
--msgbox 'The installation log file is in /tmp/officeonlin.log. After reboot you can use loolwsd.service using: systemctl (start,stop or status) loolwsd.service.
Your user is admin and password is office1234. Please change your user and/or password in (/lib/systemd/system/loolwsd.service),
after that run (systemctl daemon-reload && systemctl restart loolwsd.service). Please press OK and wait 15 sec. I will start the service.' 10 145


clear

sudo -H -u lool bash -c "for dir in ./ ; do ( cd "$oo" && make run & ); done"

sleep 10
sed -i '$d' /etc/sudoers
echo ""
echo "DONE! Enjoy!!!"
echo ""
lsof -i :9980
exit

