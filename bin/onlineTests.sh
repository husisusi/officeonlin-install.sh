#!/bin/bash
# shellcheck disable=SC2154
# tests script
sudo -Hu cool bash -c "coolwsd --o:sys_template_path=${cool_dir}/systemplate --o:lo_template_path=${lo_dir}/instdir --o:child_root_path=${cool_dir}/jails --o:admin_console.username=admin --o:admin_console.password=admin &"
rm -rf ${lo_dir}/workdir
sleep 18
if pgrep -u cool coolwsd; then
  echo -e "\033[33;7m### coolwsd is running. Enjoy!!! Service will be stopped after this ###\033[0m"
  lsof -i :9980
  pkill -u cool coolwsd
  systemctl enable $coolwsd_service_name.service
  systemctl daemon-reload
else
  echo -e "\033[33;5m### coolwsd is not running. Something went wrong :| Please look in ${log_dir} or try to restart your system ###\033[0m"
fi
