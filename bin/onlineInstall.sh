#!/bin/bash
# shellcheck disable=SC2154
# install script
#####################
#### loolwsd Installation ###
make install
mkdir -p /usr/local/var/cache/loolwsd && chown -R lool:lool /usr/local/var/cache/loolwsd

# create log file for lool user
[ -n "${lool_logfile}" ] && [ ! -f ${lool_logfile} ] && touch ${lool_logfile}
chown lool:lool ${lool_logfile}
## create the hello-world file for test & demo
# sudo -Hu lool cp ${lool_dir}/test/data/hello.odt ${lool_dir}/test/data/hello-world.odt

if [ ! -f /lib/systemd/system/$loolwsd_service_name.service ]; then
  [ -z "$admin_pwd" ] && admin_pwd=$(randpass 10 0)
  cat <<EOT > /lib/systemd/system/$loolwsd_service_name.service
[Unit]
Description=LibreOffice OnLine WebSocket Daemon
After=network.target

[Service]
EnvironmentFile=-/etc/sysconfig/loolwsd
ExecStartPre=/bin/mkdir -p /usr/local/var/cache/loolwsd
ExecStartPre=/bin/chown lool: /usr/local/var/cache/loolwsd
PermissionsStartOnly=true
ExecStart=${lool_dir}/loolwsd --o:sys_template_path=${lool_dir}/systemplate --o:lo_template_path=${lo_dir}/instdir  --o:child_root_path=${lool_dir}/jails --o:admin_console.username=admin --o:admin_console.password="$admin_pwd"
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
  openssl x509 -req -days 1825 -in /etc/loolwsd/cert.csr -signkey /etc/loolwsd/key.pem -out /etc/loolwsd/cert.pem
  openssl x509 -req -days 1825 -in /etc/loolwsd/cert.csr -signkey /etc/loolwsd/key.pem -out /etc/loolwsd/ca-chain.cert.pem
  chown lool:lool /etc/loolwsd/key.pem
  chmod 600 /etc/loolwsd/key.pem
fi
if [ ! -e /etc/systemd/system/$loolwsd_service_name.service ]; then
  ln /lib/systemd/system/$loolwsd_service_name.service /etc/systemd/system/$loolwsd_service_name.service
fi
