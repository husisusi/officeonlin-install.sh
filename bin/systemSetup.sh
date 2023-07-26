#!/bin/bash
# shellcheck disable=SC2154,SC2155
###############################################################################
############################# System preparation ##############################
ssl_fix_dirty(){
  local apt_file="/etc/apt/sources.list"
  local deb_="deb http://ftp.be.debian.org/debian/ jessie-backports main"
  local deb_src="deb-src http://ftp.be.debian.org/debian/ jessie-backports main"
  local check_deb=`grep "$deb_" $apt_file | wc -l`
  local check_deb_src=`grep "$deb_src" $apt_file | wc -l`

  if [ "$check_deb" == "0" ];then
    echo $deb_ >> $apt_file
  fi
  if [ "$check_deb_src" == "0" ];then
    echo $deb_src >> $apt_file
  fi

  (
    echo "Package: openssl libssl1.0.0 libssl-dev libssl-doc"
    echo "Pin: release a=jessie-backports"
    echo "Pin-Priority: 1001"
  ) | tee /etc/apt/preferences.d/00_ssl
  apt-get update
  if ! apt-get install openssl libssl-dev -y --allow-downgrades; then
    exit 1
  fi
}

if [ -n "${set_name:?}" ]; then
  echo "Searching for a set named $set_name..."
  my_set=$(FindOnlineSet "$set_name" "$lo_src_repo" "$set_core_regex" "$cool_src_repo" "$set_online_regex" "$set_version")
  if [ -n "$my_set" ]; then
    lo_src_branch=$(echo $my_set | awk '{print $1}') && echo "Core branch: $lo_src_branch"
    cool_src_branch=$(echo $my_set | awk '{print $2}') && echo "Online branch: $cool_src_branch"
  fi
fi
# run apt update && upgrade if last update is older than 1 day
find /var/lib/apt/lists/ -mtime -1 |grep -q partial || apt-get update && apt-get upgrade -y

${sh_interactive} && apt-get install dialog -y

grep -q '# deb-src' ${soli} && sed -i 's/# deb-src/deb-src/g' ${soli} && apt-get update

# Need to checkout Distrib/Release
apt-get install lsb-release -y

DIST=$(lsb_release -si)
# RELEASE=`lsb_release -sr`

CODENAME=$(lsb_release -c)
CODENAME=`echo ${CODENAME##*:}`

DIST_PKGS=""
if [ "${DIST}" = "Ubuntu" ]; then
  DIST_PKGS="${DIST_PKGS} openjdk-19-jdk"
fi
if [ "${DIST}" = "Debian" ]; then
  if [ "${CODENAME}" = "stretch" ];then
    # ssl_fix_dirty no longer necessary
    DIST_PKGS="${DIST_PKGS} openjdk-8-jdk"
    DIST_PKGS="${DIST_PKGS} libpng16.16"
    DIST_PKGS="${DIST_PKGS} libpng-dev"
elif [ "${CODENAME}" = "buster" ] || [ "${CODENAME}" = "bullseye" ] || [ "${CODENAME}" = "bookworm" ];then
    DIST_PKGS="${DIST_PKGS} openjdk-17-jdk"
    DIST_PKGS="${DIST_PKGS} libpng16.16"
    DIST_PKGS="${DIST_PKGS} libpng-dev"
  else
    DIST_PKGS="${DIST_PKGS} openjdk-7-jdk"
    DIST_PKGS="${DIST_PKGS} libpng12-0"
    DIST_PKGS="${DIST_PKGS} libpng12-dev"
  fi
fi

if ! apt-get install ant sudo systemd wget zip make procps automake bison ccache \
flex g++ git gperf graphviz junit4 libcap-dev libcppunit-dev build-essential libcairo2-dev libjpeg-dev \
libcppunit-doc libcunit1 libcunit1-dev libegl1-mesa-dev libfontconfig1-dev libgl1-mesa-dev libgif-dev \
libgtk-3-dev libgtk2.0-dev libkrb5-dev libpcap0.8 libpcap0.8-dev libtool libpam0g-dev libpango1.0-dev \
libxml2-utils libxrandr-dev libxrender-dev libxslt1-dev libxt-dev m4 nasm openssl libssl-dev librsvg2-dev \
pkg-config python3-polib python3-dev uuid-runtime xsltproc libcap2-bin python3-lxml libcups2-dev libzstd-dev\
${DIST_PKGS} -y; then
    exit 1
fi
if ! ${lo_mini}; then
  apt-get install doxygen libcups2-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev -y
fi
apt-get build-dep libreoffice -y

if [ "${DIST}" = "Debian" ]; then
    if [ "${CODENAME}" = "buster" ] || [ "${CODENAME}" = "bullseye" ];then
	curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
	apt-get install nodejs -y
	export npm_install="9.7.1"
	curl https://www.npmjs.com/install.sh | sh
	apt install python3-polib -y
	npm install -g browserify
    else
	if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
	    curl -sL https://deb.nodesource.com/setup_6.x | bash -
	    apt-get install nodejs -y
	fi
    fi
fi
if ${lo_non_free_ttf}; then
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
apt-get install ttf-mscorefonts-installer -y
fi

getent passwd cool || (useradd cool -G sudo; mkdir /home/cool)
chown cool:cool /home/cool -R
