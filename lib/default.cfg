#!/bin/bash
soli="/etc/apt/sources.list"
cpu=$(nproc)
log_dir="$PWD/$(date +'%Y%m%d-%H%M')_officeonline-install"
sh_interactive=true
set_name='collabora'
set_core_regex='cp-'
set_online_regex='collabora-online-'
set_version=''
lo_src_repo='https://github.com/LibreOffice/core.git'
lo_src_branch='master'
lo_src_commit=''
lo_src_tag=''
lo_dir="/opt/libreoffice"
lo_forcebuild=false
lo_req_vol=11000
lo_configure_opts=''
lo_mini=true
declare -r lo_mini_opts='--without-help --without-myspell-dicts --without-java --without-doxygen
--disable-cups --disable-dconf --disable-odk --without-junit --disable-dbus --disable-firebird-sdbc
--disable-postgresql-sdbc --disable-gltf --disable-extensions --disable-pdfimport --disable-neon
--disable-lpsolve --disable-coinmp --disable-systray --disable-randr --disable-gstreamer-1-0
--without-helppack-integration --disable-report-builder --disable-coinmp --disable-collada'
lo_non_free_ttf=false
poco_version_latest=$(curl -s https://pocoproject.org/ | awk -F'The latest stable release is ' '{printf $2}' | grep -Eo '^[^ ]+.\w')
poco_version=$poco_version_latest
poco_dir="/opt/poco-${poco_version}-all"
poco_forcebuild=false
poco_version_folder=$(curl -s https://pocoproject.org/ | grep -oiE 'The latest stable release is [0-9+]\.[0-9\.]{1,}[0-9]{1,}' | awk '{print $NF}')
poco_req_vol=550
lool_src_repo="https://github.com/LibreOffice/online.git"
lool_src_branch='master'
lool_src_commit=''
lool_src_tag=''
lool_dir="/opt/online"
lool_configure_opts=''
lool_logfile='/var/log/loolwsd.log'
lool_forcebuild=false
lool_maxcon=200
lool_maxdoc=100
lool_req_vol=650
loolwsd_service_name='loolwsd'
