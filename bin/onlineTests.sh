#!/bin/bash
# shellcheck disable=SC2154
# tests script
sudo -Hu lool bash -c "${lool_dir}/loolwsd --o:sys_template_path=${lool_dir}/systemplate --o:lo_template_path=${lo_dir}/instdir --o:child_root_path=${lool_dir}/jails --o:admin_console.username=admin --o:admin_console.password=admin &"
rm -rf ${lo_dir}/workdir
sleep 18
if pgrep -u lool loolwsd; then
  echo -e "\033[33;7m### loolwsd is running. Enjoy!!! Service will be stopped after this ###\033[0m"
  lsof -i :9980
  pkill -u lool loolwsd
  systemctl enable $loolwsd_service_name.service
  systemctl daemon-reload
else
  echo -e "\033[33;5m### loolwsd is not running. Something went wrong :| Please look in ${log_dir} or try to restart your system ###\033[0m"
fi
