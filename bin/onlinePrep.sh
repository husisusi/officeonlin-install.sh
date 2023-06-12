#!/bin/bash
# shellcheck disable=SC2154,SC2034
# this script contains:
## idempotent functions to define if LibreOffice Online has to be compiled
## Installation of requirements for Libreoffice Online build only
## Download & install LibreOffice Online Sources
cp /usr/local/lib/libPocoCrypto.so.* /usr/lib/
cp /usr/local/lib/libPocoXML.so.* /usr/lib/
set -e
SearchGitOpts=''
[ -n "${cool_src_branch}" ] && SearchGitOpts="${SearchGitOpts} -b ${cool_src_branch}"
[ -n "${cool_src_commit}" ] && SearchGitOpts="${SearchGitOpts} -c ${cool_src_commit}"
[ -n "${cool_src_tag}" ] && SearchGitOpts="${SearchGitOpts} -b ${cool_src_tag}"
#### Download dependencies ####
if [ -d ${cool_dir} ]; then
  cd ${cool_dir}
else
  git clone ${SearchGitOpts} --single-branch ${cool_src_repo} ${cool_dir}
fi
#declare repChanged
#eval "$(SearchGitCommit $SearchGitOpts)"
#if [ -f ${cool_dir}/coolwsd ] && $repChanged ; then
#  cool_forcebuild=true
#fi
if [ "${DIST}" = "Debian" ]; then
  if [ "${CODENAME}" = "bullseye" ] || [ "${CODENAME}" = "bookworm" ]; then
    apt-get install  libssl-dev libpococrypto70 -y
  elif [ "${CODENAME}" = "buster" ]; then
    apt-get install  libssl-dev libpococrypto60 -y
  else 
    apt-get install nodejs-dev node-gyp libssl1.0-dev npm libpococrypto80 -y
  fi
else
  apt-get install nodejs node-gyp libssl-dev npm libpococrypto62 -y
fi

set +e
if ! npm -g list jake >/dev/null; then
#  npm install -g npm
  npm install -g jake
fi

sed  '16a\
#include <list>
' < ${cool_dir}/wsd/AdminModel.hpp > ${cool_dir}/wsd/AdminModeltmp.hpp 
cat ${cool_dir}/wsd/AdminModeltmp.hpp > ${cool_dir}/wsd/AdminModel.hpp

