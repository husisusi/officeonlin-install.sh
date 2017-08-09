#!/bin/bash
getFilesystem() {
  # function return the filesystem of a folder
  # arg 1 is an existing folder
  [ ! -d $1 ] || [ -L $1 ] &&  echo "error: $1 do not exists or is not a valid directory." >&2 && return 1
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
