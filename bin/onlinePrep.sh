#!/bin/bash
# shellcheck disable=SC2154,SC2034
# this script contains:
## idempotent functions to define if LibreOffice Online has to be compiled
## Installation of requirements for Libreoffice Online build only
## Download & install LibreOffice Online Sources
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

sed  '16a\
#include <list>
' < /opt/online/wsd/AdminModel.hpp > /opt/online/wsd/AdminModeltmp.hpp 
cat /opt/online/wsd/AdminModeltmp.hpp > /opt/online/wsd/AdminModel.hpp
