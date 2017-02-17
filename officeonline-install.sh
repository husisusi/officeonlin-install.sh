
#!/bin/bash

#VERSION 1.2
#Written by: Subhi H.
#This script is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

#This script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

clear
echo ""
echo ""
echo ""
echo "The installation will start in 15 sec.I hope you started it as root or with sudo ;)"
echo "THE INSTALLATION WILL TAKE REALLY VERY LONG TIME SO BE PATIENT PLEASE!!! You may eventually see errors during the installation, just ignore them."
sleep 15

soli="/etc/apt/sources.list"
ooo="/opt/libreoffice"
poco="/opt/poco-1.7.7-all"
getpoko=poco-1.7.7-all.tar.gz
oo="/opt/online"
cpu=`nproc`
maxcon=200
maxdoc=100


if [[ `id -u` -ne 0 ]] ; then echo "Please run me as root or sudo ./officeonline-install.sh" ; exit 1 ; fi

sed -i 's/# deb-src/deb-src/g' $soli

apt-get update && apt-get upgrade -y

apt-get install sudo libegl1-mesa-dev libkrb5-dev python-polib git libkrb5-dev make openssl apache2 g++ libtool ccache libpng12-0 libpng12-dev libpcap0.8 libpcap0.8-dev libcunit1 libcunit1-dev libpng12-dev libcap-dev libtool m4 automake libcppunit-dev libcppunit-doc pkg-config npm wget nodejs-legacy libfontconfig1-dev  -y && sudo apt-get build-dep libreoffice -y

useradd lool -G sudo
mkdir /home/lool
chown lool:lool /home/lool -R


git clone https://github.com/LibreOffice/core $ooo
chown lool:lool $ooo -R



sudo -H -u lool bash -c "for dir in ./ ; do (cd "$ooo" && $ooo/autogen.sh --without-help --without-myspell-dicts); done"
sudo -H -u lool bash -c "for dir in ./ ; do (cd "$ooo" && make); done"
sudo -H -u lool bash -c "for dir in ./ ; do (cd "$ooo" && make check); done"


######TODO###### We need autocheck last version of pocp and link it to $getpoko   
wget https://pocoproject.org/releases/poco-1.7.7/$getpoko -P /opt/
tar xf /opt/$getpoko -C  /opt/
chown lool:lool $poco -R

sudo -H -u lool bash -c "for dir in ./ ; do (cd "$poco" && ./configure); done"
sudo -H -u lool bash -c  "for dir in ./ ; do (cd "$poco" && make -j$cpu); done"
for dir in ./ ; do (cd "$poco" && make install); done

###############################################################################


git clone https://github.com/LibreOffice/online $oo

chown lool:lool $oo -R
sudo -H -u lool bash -c "for dir in ./ ; do (cd "$oo" && libtoolize && aclocal && autoheader && automake --add-missing && autoreconf); done"

for dir in ./ ; do (cd "$oo" && npm install -g npm); done
for dir in ./ ; do (cd "$oo" && npm install -g jake); done

for dir in ./ ; do ( cd "$oo" && ./configure --enable-silent-rules --with-lokit-path=/opt/online/bundled/include --with-lo-path=/opt/libreoffice/instdir --with-max-connections=$maxcon --with-max-documents=$maxdoc --with-poco-includes=/usr/local/include --with-poco-libs=/usr/local/lib --enable-debug && make -j$cpu --directory=$oo); done
for dir in ./ ; do ( cd "$oo" && make install); done


echo "%lool ALL=NOPASSWD:ALL" >> /etc/sudoers


#chown lool:lool /opt/* -R

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
#systemctl start loolwsd.service
chown lool:lool $oo -R
clear

echo ""
echo "You can now check loolwsd.service status using: systemctl status loolwsd.service"
echo "Your user is admin and password is office1234. You can change your user and/or password in (/lib/systemd/system/loolwsd.service)"
echo "then run (systemctl daemon-reload && systemctl restart loolwsd.service). Please wait 10 sec. I will start the service."

sleep 10


sudo -H -u lool bash -c "for dir in ./ ; do ( cd "$oo" && make run & ); done"

sleep 5
sed -i '$d' /etc/sudoers
echo ""
echo "DONE! Enjoy!!!"
echo ""
exit

