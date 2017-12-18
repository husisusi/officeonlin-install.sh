#!/bin/bash
# shellcheck disable=SC2154
# this script contains:
## idempotent functions to define if Poco library has to be compiled
## Installation of requirements for Poco build only
## Download & install Poco Sources
[ -z "$poco_version" ] && poco_version=$poco_version_latest
[ -z "$poco_dir" ] && poco_dir="/opt/poco-${poco_version}-all"
poco_version_folder=$(grep -oiE '[0-9+]\.[0-9\.]{1,}[0-9]{1,}' <<<"${poco_version}")
if [ ! -d $poco_dir ]; then
  wget -c https://pocoproject.org/releases/poco-${poco_version_folder}/poco-${poco_version}-all.tar.gz -P "$(dirname $poco_dir)"/ || exit 3
  tar xf "$(dirname $poco_dir)"/poco-${poco_version}-all.tar.gz -C  "$(dirname $poco_dir)"/
  chown lool:lool $poco_dir -R
fi
