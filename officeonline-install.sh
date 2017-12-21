#!/bin/bash
#VERSION 2.5.1
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
# shellcheck disable=SC2034,SC2154

whendiditstopped() {
  echo "Ended at $(date +'%Y-%m-%d %H:%M:%S')" >> ${log_dir}/timewatch.log
}

if [[ $(id -u) -ne 0 ]] ; then echo 'Please run me as root or "sudo ./officeonline-install.sh"' ; exit 1 ; fi
ScriptFullPath="$(dirname "$(realpath $0)")"
# shellcheck source=/project/lib/checksys.sh
# shellcheck source=/project/lib/helpmenu.sh
# shellcheck source=/project/lib/SearchInGit.sh
# shellcheck source=/project/lib/security.sh
for mylibrary in $ScriptFullPath/lib/*.sh; do
source "$mylibrary"
done
# fix for system coming without curl pre-installed
if [ -z "$(for subpath in $(echo $PATH|tr ':' ' '); do ls $subpath/curl 2>/dev/null; done)" ]; then
  apt-get install curl -y
fi

while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -c|--config)
      if [[ -f $2 ]]; then
        # shellcheck source=/project/officeonline-install.cfg
        opt_config_file="$2"
      elif [[ "$2" =~ .*'='.* ]]; then
        # override ONE variable at a time
        # can be repeated
        # test if it is a variable with an = in it.
        opt_config_vars="$opt_config_vars $2"
      fi
    # else skip the parameter
      shift ;;
    -f|--force)
    # quick option to force build from command line
    # this option can be repeated
      case $2 in
        oo|lo|core|libreoffice|libre-office) opt_config_vars="$opt_config_vars lo_forcebuild=true" ;;
        lool|online|loolwd|collabora) opt_config_vars="$opt_config_vars lool_forcebuild=true" ;;
        poco) opt_config_vars="$opt_config_vars poco_forcebuild=true" ;;
      esac
    ;;
    -h|--help)
      help_menu
      exit
     ;;
    -l|--libreoffice_commit)
    opt_lo_src_commit="$2"
    shift # past argument
    ;;
    -o|--libreoffice_online_commit)
    opt_lool_src_commit="$2"
    shift # past argument
    ;;
    -p|--poco_version)
    opt_poco_version="$2"
    shift # past argument
    ;;
    #--default)
    #DEFAULT=YES
    #;;
    *)
            # unknown option
    ;;
esac
shift # past argument or value
done

# shellcheck source=/project/lib/default.cfg
source "$ScriptFullPath/lib/default.cfg"
if [ -n "$opt_config_file" ]; then
  # shellcheck source=/project/officeonline-install.cfg
  source "$opt_config_file"
elif [ "$ScriptFullPath" != "$PWD" ] && [ -s "$PWD/officeonline-install.cfg" ]; then
  # shellcheck source=/project/officeonline-install.cfg
  source "$PWD/officeonline-install.cfg"
elif [ -s "$HOME/officeonline-install.cfg" ]; then
  # shellcheck source=/project/officeonline-install.cfg
  source "$HOME/officeonline-install.cfg"
elif [ -s "/etc/loolwsd/officeonline-install.cfg" ]; then
  # shellcheck source=/project/officeonline-install.cfg
  source "/etc/loolwsd/officeonline-install.cfg"
elif [ -s "$ScriptFullPath/officeonline-install.cfg" ]; then
  # shellcheck source=/project/officeonline-install.cfg
  source "$ScriptFullPath/officeonline-install.cfg"
fi

# backward compatibility block :
[ -n "$opt_lo_src_commit" ] && lo_src_commit="$opt_lo_src_commit"
[ -n "$opt_lool_src_commit" ] && lool_src_commit="$opt_lool_src_commit"
[ -n "$opt_poco_version" ] && poco_version="$opt_poco_version"
# override using all variables given using the -c option
if [ -n "$opt_config_vars" ]; then
  for my_var in $opt_config_vars; do
    eval "$my_var"
  done
fi

if ${sh_interactive:?}; then clear; fi
###############################################################################
################################# OPERATIONS ##################################
###############################################################################
#clear the logs in case of super multi fast script run.
[ "${log_dir:?}" = '/' ] && exit 100 # just to be safe
[ -f ${log_dir} ] && rm -rf ${log_dir}
mkdir -p ${log_dir}
touch ${log_dir}/preparation.log
touch ${log_dir}/LO-compilation.log
touch ${log_dir}/POCO-compilation.log
touch ${log_dir}/Lool-compilation.log
###Added timewatch log file just to now when the script start and stop.
echo "Started at $(date +'%Y-%m-%d %H:%M:%S')" > ${log_dir}/timewatch.log
trap whendiditstopped EXIT

{
# shellcheck source=/project/bin/systemChecks.sh
source "$ScriptFullPath/bin/systemChecks.sh"
# shellcheck source=/project/bin/systemSetup.sh
source "$ScriptFullPath/bin/systemSetup.sh"
} > >(tee -a ${log_dir}/preparation.log) 2> >(tee -a ${log_dir}/preparation.log >&2)

###############################################################################
######################## libreoffice compilation ##############################
{
# shellcheck source=/project/bin/corePrep.sh
source "$ScriptFullPath/bin/corePrep.sh"
} > >(tee -a ${log_dir}/LO-compilation.log) 2> >(tee -a ${log_dir}/LO-compilation.log >&2)
# shellcheck source=/project/bin/coreBuild.sh
source "$ScriptFullPath/bin/coreBuild.sh"
###############################################################################
############################# Poco Installation ###############################
{
  # shellcheck source=/project/bin/pocoPrep.sh
  source "$ScriptFullPath/bin/pocoPrep.sh"
  # shellcheck source=/project/bin/pocoBuild.sh
  source "$ScriptFullPath/bin/pocoBuild.sh"
} > >(tee -a ${log_dir}/POCO-compilation.log) 2> >(tee -a ${log_dir}/POCO-compilation.log >&2)

###############################################################################
########################### loolwsd Installation ##############################
{
  # shellcheck source=/project/bin/onlinePrep.sh
  source "$ScriptFullPath/bin/onlinePrep.sh"
  # shellcheck source=/project/bin/onlineBuild.sh
  source "$ScriptFullPath/bin/onlineBuild.sh"
  # shellcheck source=/project/bin/onlineInstall.sh
  source "$ScriptFullPath/bin/onlineInstall.sh"
} > >(tee -a ${log_dir}/Lool-compilation.log) 2> >(tee -a ${log_dir}/Lool-compilation.log >&2)
### Testing loolwsd ###
if ${sh_interactive}; then
  admin_pwd=$(awk -F'password=' '{printf $2}' /lib/systemd/system/${loolwsd_service_name}.service )
  dialog --backtitle "Information" \
  --title "Note" \
  --msgbox "The installation logs are in ${log_dir}. After reboot you can use $loolwsd_service_name.service using: systemctl (start,stop or status) $loolwsd_service_name.service.\\n
Your user is admin and password is $admin_pwd. Please change your user and/or password in (/lib/systemd/system/$loolwsd_service_name.service),\\n
after that run (systemctl daemon-reload && systemctl restart $loolwsd_service_name.service).\\nPlease press OK and wait 15 sec. I will start the service." 10 145
  clear
fi
{
  # shellcheck source=/project/bin/onlineTests.sh
  source "$ScriptFullPath/bin/onlineTests.sh"
} > >(tee -a ${log_dir}/Lool-compilation.log) 2> >(tee -a ${log_dir}/Lool-compilation.log >&2)
exit 0
