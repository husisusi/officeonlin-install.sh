#!/bin/bash
# shellcheck disable=SC2154
# install script
#####################
#### coolwsd Installation ###
make install
mkdir -p "${cool_localstatedir}/cache/coolwsd" && chown -R cool:cool "${cool_localstatedir}/cache/coolwsd"

### clean unwanted configuration files and add wopi host
if [ -f "${cool_dir}/coolwsd.xml" ]; then
  if [ ! -f ${cool_sysconfdir:-cool_prefix/etc}/coolwsd/coolwsd.xml ]; then
    mv "${cool_dir}/coolwsd.xml" "${cool_sysconfdir:-cool_prefix/etc}/coolwsd/coolwsd.xml"
  else
    rm "${cool_dir}/coolwsd.xml"
  fi
fi
[ -n "$allowed_domains" ] && addwopihost "${cool_sysconfdir:-cool_prefix/etc}/coolwsd/coolwsd.xml" "$allowed_domains"

# create log file for cool user
if [ -n "${cool_logfile}" ]; then
  [ ! -f ${cool_logfile} ] && touch ${cool_logfile}
  chown cool:cool ${cool_logfile}
fi
## create the hello-world file for test & demo
# sudo -Hu cool cp ${cool_dir}/test/data/hello.odt ${cool_dir}/test/data/hello-world.odt

if [ ! -f /lib/systemd/system/$coolwsd_service_name.service ]; then
  [ -z "$admin_pwd" ] && admin_pwd=$(randpass 10 0)
  cat <<EOT > /lib/systemd/system/$coolwsd_service_name.service
[Unit]
Description=LibreOffice OnLine WebSocket Daemon
After=network.target

[Service]
EnvironmentFile=-/etc/sysconfig/coolwsd
ExecStartPre=/bin/mkdir -p /usr/local/var/cache/coolwsd
ExecStartPre=/bin/chown cool: /usr/local/var/cache/coolwsd
PermissionsStartOnly=true
ExecStart=${cool_dir}/coolwsd --o:sys_template_path=${cool_dir}/systemplate --o:lo_template_path=${lo_dir}/instdir  --o:child_root_path=${cool_dir}/jails --o:admin_console.username=admin --o:admin_console.password="$admin_pwd"
User=cool
KillMode=control-group
# Restart=always

[Install]
WantedBy=multi-user.target
EOT
fi

if [ ! -f /etc/coolwsd/ca-chain.cert.pem ]; then
  mkdir /etc/coolwsd
  openssl genrsa -out /etc/coolwsd/key.pem 4096
  openssl req -out /etc/coolwsd/cert.csr -key /etc/coolwsd/key.pem -new -sha256 -nodes -subj "/C=DE/OU=onlineoffice-install.com/CN=onlineoffice-install.com/emailAddress=nomail@nodo.com"
  openssl x509 -req -days 1825 -in /etc/coolwsd/cert.csr -signkey /etc/coolwsd/key.pem -out /etc/coolwsd/cert.pem
  openssl x509 -req -days 1825 -in /etc/coolwsd/cert.csr -signkey /etc/coolwsd/key.pem -out /etc/coolwsd/ca-chain.cert.pem
  chown cool:cool /etc/coolwsd/key.pem
  chmod 600 /etc/coolwsd/key.pem
fi
if [ ! -e /etc/systemd/system/$coolwsd_service_name.service ]; then
  ln /lib/systemd/system/$coolwsd_service_name.service /etc/systemd/system/$coolwsd_service_name.service
fi
