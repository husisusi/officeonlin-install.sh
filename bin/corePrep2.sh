#!/bin/bash
# shellcheck disable=SC2154,SC2034
# this script contains:
## Download & install LibreOffice Assets
set -e
rm -rf ${lo_dir}
echo
echo "Downloading Libre Office core assets (this might take a while) ..."
mkdir ${lo_dir}
cd ${lo_dir}
wget https://github.com/CollaboraOnline/online/releases/download/for-code-assets/core-co-22.05-assets.tar.gz -q --show-progress
chown -R cool:cool ${lo_dir}
echo
echo "Unpacking ..."
tar xvf core-co-22.05-assets.tar.gz
rm core-co-22.05-assets.tar.gz
set +e
