#!/bin/bash
getFilesystem() {
  # function return the filesystem of a folder
  # arg 1 is an existing folder
  [ ! -d $1 ] || [ -L $1 ] &&  echo "error: $1 do not exists or is not a valid directory." >&2 && return 1
  # test the used files system is not a temporary FS or else exit
  if ! df --output=fstype $1 | tail -1 | grep -qv tmpfs; then
    echo "Error: $1 is not a valid filesystem" >&2
    return 1
  fi
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
