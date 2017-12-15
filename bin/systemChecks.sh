#!/bin/bash
# shellcheck disable=SC2154
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
poco_fs=$(getFilesystem "$(dirname ${poco_dir:-poco_default_dir})") || exit 1
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
