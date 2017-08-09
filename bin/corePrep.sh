#!/bin/bash
# shellcheck disable=SC2154,SC2034
# this script contains:
## idempotent functions to define if LibreOffice has to be compiled
## Installation of requirements for Libreoffice build only
## Download & install LibreOffice Sources
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
