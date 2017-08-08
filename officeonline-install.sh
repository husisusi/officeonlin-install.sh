#!/bin/bash
#VERSION 2.3.3
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
help_menu() {
  echo "Usage:

  ${0##*/} [-h][-l VERSION][-o COMMIT][-p VERSION]

Options:

  -h, --help
    display this help and exit

  -l, --libreoffice_commit)=VERSION
    Libreoffice COMMIT - short/full hash

  -o, --libreoffice_online_commit)=COMMIT
    Libreoffice Online COMMIT - short/full hash

  -p, --poco_version)=VERSION
    Poco Version
  "
}

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -h|--help)
      help_menu
      exit
     ;;
    -l|--libreoffice_commit)
    LOCOMMIT="$2"
    shift # past argument
    ;;
    -o|--libreoffice_online_commit)
    LOOLCOMMIT="$2"
    shift # past argument
    ;;
    -p|--poco_version)
    POCOVERSION="$2"
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

###############################################################################
################################# Parameters ##################################
###############################################################################
### Script parameters ###
soli="/etc/apt/sources.list"
cpu=$(nproc)
log_dir="$PWD/$(date +'%Y%m%d-%H%M')_officeonline-install"
sh_interactive=true

### Define a set of version for LibreOffice Core and Online###
###### THIS WILL OVERRIDE lo_src_branch & lool_src_branch VARIABLES ########
# set_name is used to locate branchs folders in the libreoffice project
#example : distro/collabora/
### default set is latest version of collabora
set_name='collabora'
# set_core_regex & set_online_regex are regulax expression used to find the branch name for core and online
# example:
set_core_regex='cp-'
set_online_regex='collabora-online'
# set_version can be used if both branch name contains a common version number
# if empty, latest version available for each project will be used
set_version=''

### LibreOffice parameters ###
lo_src_repo='https://github.com/LibreOffice/core.git'
lo_src_branch='master' # a existing branch name.
lo_src_commit=${LOCOMMIT:-''} # the full id of a git commit
lo_src_tag='' # a tag in the repo git
lo_dir="/opt/libreoffice"
lo_forcebuild=false # force compilation
lo_req_vol=11000 # minimum space required for LibreOffice compilation, in MB
lo_configure_opts='--without-help --without-myspell-dicts --without-java --without-doxygen'
lo_non_free_ttf=false # add Microsoft fonts to Ubuntu

### POCO parameters ###
poco_version_latest=$(curl -s https://pocoproject.org/ | awk -F'The latest stable release is ' '{printf $2}' | grep -Eo '^[^ ]+.\w')
poco_version=${POCOVERSION:-$poco_version_latest}
poco_dir="/opt/poco-${poco_version}-all"
poco_forcebuild=false
poco_version_folder=$(curl -s https://pocoproject.org/ | grep -oiE 'The latest stable release is [0-9+]\.[0-9\.]{1,}[0-9]{1,}' | awk '{print $NF}')
poco_req_vol=550 # minimum space required for Poco compilation, in MB

### LibreOffice Online parameters ###
lool_src_repo="https://github.com/LibreOffice/online.git"
# variable precedence: commit > tag > branch
lool_src_branch='master' # a existing branch name.
lool_src_commit=${LOOLCOMMIT:-''} # the full id of a git commit
lool_src_tag='' # a tag in the repo git
lool_dir="/opt/online"
lool_configure_opts='' # --enable-debug
lool_logfile='/var/log/loolwsd.log'
lool_forcebuild=false
lool_maxcon=200
lool_maxdoc=100
lool_req_vol=650 # minimum space required for LibreOffice Online compilation, in MB

if [[ $(id -u) -ne 0 ]] ; then echo 'Please run me as root or "sudo ./officeonline-install.sh"' ; exit 1 ; fi

randpass() {
  [ "$2" == "0" ] && CHAR="[:alnum:]" || CHAR="[:graph:]"
  head -10 /dev/urandom 2>/dev/null | tr -cd "$CHAR" 2>/dev/null | head -c ${1:-32}
}
getFilesystem() {
  # function return the filesystem of a folder
  # arg 1 is an existing folder
  [ ! -d $1 ] &&  echo "error: $1 do not exists or is not a valid directory." >&2 && return 1
  df --output=source $1 | tail -1
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
  # Check if not in OpenVZ, /dev/simfs is a virtual device
  if [ "${CompFs}" != "/dev/simfs" ]; then
    [ ! -b ${CompFs} ] && echo "Error: ${CompFs} is not a valid filesystem" >&2 && return 2
  fi
  availableMB=$(df -m --output=avail ${CompFs}|tail -1)
  if [ ${availableMB} -lt ${CompRequirement} ]; then
    echo "${CompFs}: FAILED"
    echo "Not Enough space available on ${CompFs} (${CompRequirement} MiB required)" >&2
    echo "(only ${availableMB} MiB available)" >&2
    echo "Exiting." >&2
    return 1
  else
    echo "${availableMB}"
  fi
  return 0
}
SearchGitCommit() {
  # return all the commands required to set the repo to the desired state
  # (change branch and head to a commit found by search on the repo tree)
  # return also a trigger value "repChanged" that's true if the repo must be updated
  # Usage = FundGitCommit [--branch|-t [branch name], --commit|-t [commit], --tag|-t [tag]]
  ##CONSTRAINT : if commit|tag is used it must exist in the current/new branch
  # options precedence: branch + commit > tag > default
  # accept long options with '=' (--branch="master"|--branch master)
  # accept long and short commit hash
  local rcode=false myBranch myCommit myTag myTagCommit HeadBranch HeadCommit latestTagCommit latestCommit
  if [ ! -d .git ]; then
    # /!\ Current directory must be inside the git repository
    echo "Error: current directory is not a git repository !" >&2
    return 2
  fi
  while [ $# -ne 0 ]; do
    case $1 in
      "--branch*"|'-b')
        if [[ $1 =~ "=" ]]; then
          myBranch=$(echo $1 |cut -d '=' -f2)
          shift 1
        else
          local myBranch=$2
          shift 2
        fi
        ;;
      "--commit*"|'-c')
        if [[ $1 =~ "=" ]]; then
          myCommit=$(echo $1 |cut -d '=' -f2)
          shift 1
        else
          local myCommit=$2
          shift 2
        fi
        ;;
      "--tag*"|'-t')
        if [[ $1 =~ "=" ]]; then
          myTag=$(echo $1 |cut -d '=' -f2)
          shift 1
        else
          local myTag=$2
          shift 2
        fi
        ;;
      *) shift 1 ;;
    esac
  done
  # getting local info on the repository.
  HeadBranch=$(git branch|grep -e '^\*' |awk '{print $NF}')
  HeadCommit=$(git rev-parse HEAD)
  git fetch
  # checking if args are valid inside the repository
  if [ -n "$myBranch" ]; then
    if ! git branch -a| grep -q $myBranch; then
      # check if branch doesn't exist localy or remotely, then quit.
      echo "Error: $myBranch is not a valid branch." >&2
      return 1
    fi
    #change the remote branch if needed and reset to latestCommit
    latestCommit=$(git log -1 origin/${myBranch}| grep ^commit | awk '{print $NF}')
    [ "${myBranch}" != "${HeadBranch}" ] && echo "git checkout ${myBranch};" && rcode=true
    HeadBranch="$myBranch"
    # return 0
  fi
  if [ -n "$myCommit" ]; then
    if ! git cat-file commit $myCommit >/dev/null; then
      # check if the commit doesn't exist
      echo "Error: $myCommit is not a valid commit." >&2
      return 1
    elif ! git log --simplify-by-decoration --decorate --pretty=oneline "origin/$HeadBranch" | grep -q "$myCommit"; then
      echo "Error: $myCommit is not in branch $HeadBranch." >&2
      return 1
    fi
    #find the commit's long hash from the short hash
    myCommit=$(git log --simplify-by-decoration --decorate --pretty=oneline "origin/$HeadBranch" | grep "$myCommit"|awk '{print $1}')
    [ "${myCommit}" != "${HeadCommit}" ] && echo "git reset --hard ${myCommit};" && rcode=true
    echo "repChanged=$rcode"
    return 0
  fi
  if [ -n "$myTag" ]; then
     if ! git ls-remote -t | grep -q tags/${myTag}^; then
       # check if the Tag doesn't exist
       echo "Error: $myTag is not a valid Tag." >&2
       return 1
     elif ! git log --simplify-by-decoration --decorate --pretty=oneline "origin/$HeadBranch" | grep -Eq "tag:.*$myCommit"; then
       echo "Error: $myTag is not in branch $HeadBranch." >&2
       return 1
     fi
    myTagCommit=$(git log --simplify-by-decoration --decorate --pretty=oneline "origin/$HeadBranch" | grep -Em 1 "tag:.*$myCommit"|awk '{print $1}')
    [ "${myTagCommit}" != "${HeadCommit}" ] && echo "git reset --hard ${myTagCommit};" && rcode=true
    echo "repChanged=$rcode"
    return 0
  else
    # if no argument has been given, just get the latest tag of the branch.
    latestTag=$(git log --simplify-by-decoration --decorate --pretty=oneline "origin/$HeadBranch" | grep -Em 1 "tag: ")
    latestTagCommit=$(echo "$latestTag"|awk '{print $1}')
    echo "echo \"Selected Tag: $(echo ${latestTag} | sed 's/.*tag: \(.*\)[)] .*/\1/') ${latestTag:0:7}\""
    [ "${latestTagCommit}" != "${HeadCommit}" ] && echo "git reset --hard ${latestTagCommit};" && rcode=true
    echo "repChanged=$rcode"
    return 0
  fi
  # this block is for completion as this function is never going to be called without args here.
  if [ -z "${myBranch}${myCommit}${myTag}" ]; then
    latestCommit=$(git log -1 origin/${HeadBranch}| grep ^commit | awk '{print $NF}')
    [ ${latestCommit} != ${HeadCommit} ] && echo "git reset --hard ${latestCommit};" && rcode=true
    echo "repChanged=$rcode"
    return 0
  fi
}

FindOnlineSet() {
  # Search Libreoffice "core" and "online" repositories for a supposed compatible set of branches
  # for a better LibreOffice Online experience :)
  # return 1 branch name for each core and online that match a set
  # Take 5 arguments:
  # $1 the set name
  # $2 the "core" repository url
  # $3 a expected regex defining the branch name in the core repository
  # $4 the "online" repository url
  # $5 a expected regex defining the branch name in the online repository
  # 1 optional arg:
  # $6 a desired common version for the set. (latest possible if let unused)
  local set_name="$1" core_repo="$2" core_regex="$3" online_repo="$4" online_regex="$5" set_ver core_avail online_avail
  [ -n "$6" ] && set_ver=$(echo "$6"| tr '-' '.')
  core_avail=$(git ls-remote --heads $core_repo "*$set_name*"|awk '{print $2}'|sed 's/refs\/heads\///g'|grep -E "$core_regex")
  online_avail=$(git ls-remote --heads $online_repo "*$set_name*"|awk '{print $2}'|sed 's/refs\/heads\///g'|grep -E "$online_regex")
  [[ (-z "$core_avail") || (-z "$online_avail") ]] && echo "No set found for $set_name">&2 && return 1
  if [[ ($(echo "$core_avail"| wc -w) -eq 1) && ($(echo "$online_avail"| wc -w) -eq 1) ]]; then
    echo "$core_avail $online_avail"
    return 0
  fi
  if [ -n "$set_ver" ]; then
    FindSetVersion() {
      # nested function for searching a common version number
      # $@ is a list for branch name
      local interview
      local ver_branch_set
      for candidate in "$@"; do
        interview=$(echo $candidate | tr '-' '.' | grep $set_ver)
        [ -n "$interview" ] && ver_branch_set="$ver_branch_set $candidate"
          # if more than one match (sub version), rely on git sorting the version to get the latest available
          echo $ver_branch_set|awk '{print $NF}'
      done
    }
    core_avail=$(FindSetVersion $core_avail)
    online_avail=$(FindSetVersion $online_avail)
    if [[ ( -z "$core_avail" ) || ( -z "$online_avail" ) ]]; then
      echo "Unable to find a proper set for $set_name at version $set_ver." >&2
      return 2
    fi
  fi
    # if more than one match, rely on git sorting the version to get the latest available
    # /!\ limited results when to much branches
    echo $core_avail|awk '{print $NF}'
    echo $online_avail|awk '{print $NF}'
    return 0
}
clear

###############################################################################
################################# OPERATIONS ##################################
###############################################################################
#clear the logs in case of super multi fast script run.
[ "${log_dir}" = '/' ] && exit 100 # just to be safe
[ -f ${log_dir} ] && rm -rf ${log_dir}
mkdir -p ${log_dir}
touch ${log_dir}/preparation.log
touch ${log_dir}/LO-compilation.log
touch ${log_dir}/POCO-compilation.log
touch ${log_dir}/Lool-compilation.log
{
if [ -n "$set_name" ]; then
  echo "Searching for a set named $set_name..."
  my_set=$(FindOnlineSet "$set_name" "$lo_src_repo" "$set_core_regex" "$lool_src_repo" "$set_online_regex" "$set_version")
  if [ -n "$my_set" ]; then
    lo_src_branch=$(echo $my_set | awk '{print $1}') && echo "Core branch: $lo_src_branch"
    lool_src_branch=$(echo $my_set | awk '{print $2}') && echo "Online branch: $lool_src_branch"
  fi
fi
###############################################################################
############################ System Requirements ##############################
echo "Verifying System Requirements:"
### Test RAM size (4GB min) ###
mem_available=$(grep MemTotal /proc/meminfo| grep -o '[0-9]\+')
if [ ${mem_available} -lt 3700000 ]; then
  echo "Error: The system do not meet the minimum requirements." >&2
  echo "Error: 4GB RAM required!" >&2
  exit 1
else
  echo "Memory: OK ($((mem_available/1024)) MiB)"
fi
### Calculate required disk space per file system ###
# find the target filesystem for each sw and add the required space for this FS
# on an array BUT only if no build have been done yet.
lo_fs=$(getFilesystem "$(dirname $lo_dir)") || exit 1
poco_fs=$(getFilesystem "$(dirname $poco_dir)") || exit 1
lool_fs=$(getFilesystem "$(dirname $lool_dir)") || exit 1
#here we use an array to store a relative number of FS and their respective required volume
#if, like in the default, LO, poco & LOOL are all stored on the same FS, the value add-up
declare -A mountPointArray # declare associative array
if [ ! -d ${lo_dir}/instdir ] ; then
  mountPointArray["$lo_fs"]=$((mountPointArray["$lo_fs"]+lo_req_vol))
fi
if [ ! -d ${poco_dir} ] || [ "$(du -s ${poco_dir} | awk '{print $1}' 2>/dev/null)" -lt 100000 ]; then
  mountPointArray["$poco_fs"]=$((mountPointArray["$poco_fs"]+poco_req_vol))
fi
if [ ! -f ${lool_dir}/loolwsd ]; then
  mountPointArray["$lool_fs"]=$((mountPointArray["$poco_fs"]+lool_req_vol))
fi
# test if each file system used have the required space.
# if there's nothing to (force-)build (so 0 FS to verify), the script leave here.
if [ ${#mountPointArray[@]} -ne 0 ]; then
  for fs_item in "${!mountPointArray[@]}"; do
    fs_item_avail=$(checkAvailableSpace $fs_item ${mountPointArray["$fs_item"]}) || exit 1
    echo "${fs_item}: PASSED (${mountPointArray["$fs_item"]} MiB Req., ${fs_item_avail} MiB avail.)"
  done
fi


###############################################################################
############################# System preparation ##############################
###### Checking system requirement
# run apt update && upgrade if last update is older than 1 day
find /var/lib/apt/lists/ -mtime -1 |grep -q partial || apt-get update && apt-get upgrade -y

${sh_interactive} && apt-get install dialog -y

grep -q '# deb-src' ${soli} && sed -i 's/# deb-src/deb-src/g' ${soli} && apt-get update

# Need to checkout Distrib/Release
apt-get install lsb-release -y

DIST=$(lsb_release -si)
# RELEASE=`lsb_release -sr`

DIST_PKGS=""
if [ "${DIST}" = "Ubuntu" ]; then
  DIST_PKGS="${DIST_PKGS} openjdk-8-jdk"
fi
if [ "${DIST}" = "Debian" ]; then
  DIST_PKGS="${DIST_PKGS} openjdk-7-jdk"
fi

if ! apt-get install sudo curl procps libegl1-mesa-dev libkrb5-dev systemd python-polib git libkrb5-dev make openssl g++ libtool ccache libpng12-0 libpng12-dev libpcap0.8 libpcap0.8-dev \
 libcunit1 libcunit1-dev libpng12-dev libcap-dev libtool m4 automake libcppunit-dev libcppunit-doc pkg-config wget libfontconfig1-dev graphviz \
 libcups2-dev gperf doxygen libxslt1-dev xsltproc libxml2-utils python-dev python3-dev libxt-dev libxrender-dev libxrandr-dev \
 uuid-runtime bison flex zip libgtk-3-dev libgtk2.0-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgl1-mesa-dev ant junit4 nasm \
 ${DIST_PKGS} -y; then
   exit 1
 fi
apt-get build-dep libreoffice -y

if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
  curl -sL https://deb.nodesource.com/setup_6.x | bash -
  apt-get install nodejs -y
fi

if ${lo_non_free_ttf}; then
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
apt-get install ttf-mscorefonts-installer -y
echo "If Loolwsd is already compiled a recompile may be necessary before fonts can be used."
fi

getent passwd lool || (useradd lool -G sudo; mkdir /home/lool)
chown lool:lool /home/lool -R
} > >(tee -a ${log_dir}/preparation.log) 2> >(tee -a ${log_dir}/preparation.log >&2)

###############################################################################
######################## libreoffice compilation ##############################
{
set -e
SearchGitOpts=''
[ -n "${lo_src_branch}" ] && SearchGitOpts="${SearchGitOpts} -b ${lo_src_branch}"
[ -n "${lo_src_commit}" ] && SearchGitOpts="${SearchGitOpts} -c ${lo_src_commit}"
[ -n "${lo_src_tag}" ] && SearchGitOpts="${SearchGitOpts} -t ${lo_src_tag}"
#### Download dependencies ####
if [ -d ${lo_dir} ]; then
  cd ${lo_dir}
else
  echo "Cloning Libre Office core (this might take a while) ..."
  git clone ${lo_src_repo} ${lo_dir}
  cd ${lo_dir}
fi
declare repChanged
eval "$(SearchGitCommit $SearchGitOpts)"
if [ -d ${lo_dir}/instdir ] && $repChanged ; then
  lo_forcebuild=true
fi
chown -R lool:lool ${lo_dir}
set +e
} > >(tee -a ${log_dir}/LO-compilation.log) 2> >(tee -a ${log_dir}/LO-compilation.log >&2)

# build LibreOffice if it has'nt been built already or lo_forcebuild is true
if [ ! -d ${lo_dir}/instdir ] || ${lo_forcebuild}; then
  if ${sh_interactive}; then
    dialog --backtitle "Information" \
    --title "${lo_src_branch} is going to be built." \
    --msgbox "THE COMPILATION WILL TAKE REALLY A VERY LONG TIME,\nAROUND $((16/cpu)) HOURS (Depending on your CPU's speed),\n
SO BE PATIENT PLEASE! ! You may see errors during the installation, just ignore them and let it do the work." 10 78
    clear
  fi
  {
  cd ${lo_dir}
  ${lo_forcebuild} && [ -f ${lo_dir}/configure ] && make clean uninstall
  if ! sudo -Hu lool ./autogen.sh ${lo_configure_opts}; then exit 2; fi

  # libreoffice take around 8/${cpu} hours to compile on fast cpu.
  # ${lo_forcebuild} && sudo -Hu lool make clean
  if ! sudo -Hu lool make; then exit 2; fi
  } > >(tee -a ${log_dir}/LO-compilation.log) 2> >(tee -a ${log_dir}/LO-compilation.log >&2)
fi
unset repChanged
###############################################################################
############################# Poco Installation ###############################
{
if [ ! -d $poco_dir ]; then
  #Fix for poco_version being unset after Lo compilation? TODO: Check the case
  [ -z "${poco_version}" ] && poco_version=$(curl -s https://pocoproject.org/ | awk -F'The latest stable release is ' '{printf $2}' | grep -Eo '^[^ ]+.\w')
  wget -c https://pocoproject.org/releases/poco-${poco_version_folder}/poco-${poco_version}-all.tar.gz -P "$(dirname $poco_dir)"/ || exit 3
  tar xf "$(dirname $poco_dir)"/poco-${poco_version}-all.tar.gz -C  "$(dirname $poco_dir)"/
  chown lool:lool $poco_dir -R
fi
} > >(tee -a ${log_dir}/POCO-compilation.log) 2> >(tee -a ${log_dir}/POCO-compilation.log >&2)

######## Poco Build ########
{
## test if the poco library has already been compiled
# (the dir size should be around 450000ko vs 65000ko when just extracted)
# so let say arbitrary : do compilation when folder size is less than 100Mo
if [ "$(du -s ${poco_dir} | awk '{print $1}')" -lt 100000 ] || ${poco_forcebuild}; then
  cd "$poco_dir"
  sudo -Hu lool ./configure || exit 3
  $poco_forcebuild && sudo -Hu lool make clean
  sudo -Hu lool make -j${cpu} || exit 3
  # poco take around 22/${cpu} minutes to compile on fast cpu
  make install || exit 3
fi
} > >(tee -a ${log_dir}/POCO-compilation.log) 2> >(tee -a ${log_dir}/POCO-compilation.log >&2)
###############################################################################
########################### loolwsd Installation ##############################
{
set -e
SearchGitOpts=''
[ -n "${lool_src_branch}" ] && SearchGitOpts="${SearchGitOpts} -b ${lool_src_branch}"
[ -n "${lool_src_commit}" ] && SearchGitOpts="${SearchGitOpts} -c ${lool_src_commit}"
[ -n "${lool_src_tag}" ] && SearchGitOpts="${SearchGitOpts} -t ${lool_src_tag}"
#### Download dependencies ####
if [ -d ${lool_dir} ]; then
  cd ${lool_dir}
else
  git clone ${lool_src_repo} ${lool_dir}
  cd ${lool_dir}
fi
declare repChanged
eval "$(SearchGitCommit $SearchGitOpts)"
if [ -f ${lool_dir}/loolwsd ] && $repChanged ; then
  lool_forcebuild=true
fi
set +e
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
  echo -e "Loolwsd is already in the expected state and I'm not forced to rebuild.\nLeaving here..."
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
chown lool:lool ${lool_dir} -R
cd ${lool_dir}
${lool_forcebuild} && [ -f ${lool_dir}/configure ] && make clean uninstall
sudo -Hu lool ./autogen.sh
[ -n "${lool_logfile}" ] && lool_configure_opts="${lool_configure_opts} --with-logfile=${lool_logfile}"
sudo -Hu lool bash -c "./configure --enable-silent-rules --with-lokit-path=${lool_dir}/bundled/include --with-lo-path=${lo_dir}/instdir --with-max-connections=$lool_maxcon --with-max-documents=$lool_maxdoc --with-poco-includes=/usr/local/include --with-poco-libs=/usr/local/lib ${lool_configure_opts}" || exit 4
# loolwsd+loleaflet take around 8.5/${cpu} minutes to compile on fast cpu
sudo -Hu lool make -j$cpu --directory=${lool_dir}
_loolwsd_make_rc=${?} # get the make return code
### remove lool group from sudoers
if [ -f /etc/sudoers ]; then
  sed -i '/^\%lool /d' /etc/sudoers
  rm "$(grep -l '%lool' ${includedir})"
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
ExecStart=${lool_dir}/loolwsd --o:sys_template_path=${lool_dir}/systemplate --o:lo_template_path=${lo_dir}/instdir  --o:child_root_path=${lool_dir}/jails --o:admin_console.username=admin --o:admin_console.password=$PASSWORD
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
if [ ! -e /etc/systemd/system/loolwsd.service ]; then
  ln /lib/systemd/system/loolwsd.service /etc/systemd/system/loolwsd.service
fi
} > >(tee -a ${log_dir}/Lool-compilation.log) 2> >(tee -a ${log_dir}/Lool-compilation.log >&2)
### Testing loolwsd ###
if ${sh_interactive}; then
  PASSWORD=$(awk -F'password=' '{printf $2}' /lib/systemd/system/loolwsd.service )
  dialog --backtitle "Information" \
  --title "Note" \
  --msgbox "The installation logs are in ${log_dir}. After reboot you can use loolwsd.service using: systemctl (start,stop or status) loolwsd.service.\n
Your user is admin and password is $PASSWORD. Please change your user and/or password in (/lib/systemd/system/loolwsd.service),\n
after that run (systemctl daemon-reload && systemctl restart loolwsd.service).\nPlease press OK and wait 15 sec. I will start the service." 10 145
  clear
fi
{
sudo -Hu lool bash -c "${lool_dir}/loolwsd --o:sys_template_path=${lool_dir}/systemplate --o:lo_template_path=${lo_dir}/instdir  --o:child_root_path=${lool_dir}/jails --o:admin_console.username=admin --o:admin_console.password=admin &"
rm -rf ${lo_dir}/workdir
sleep 18
if pgrep -u lool loolwsd; then
  echo -e "\033[33;7m### loolwsd is running. Enjoy!!! Service will be stopped after this ###\033[0m"
  lsof -i :9980
  pkill -u lool loolwsd
  systemctl enable loolwsd.service
  systemctl daemon-reload
else
  echo -e "\033[33;5m### loolwsd is not running. Something went wrong :| Please look in ${log_dir} or try to restart your system ###\033[0m"
fi
} > >(tee -a ${log_dir}/Lool-compilation.log) 2> >(tee -a ${log_dir}/Lool-compilation.log >&2)
exit 0
