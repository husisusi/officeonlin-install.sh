#!/bin/bash
# shellcheck disable=SC2154,SC2034
# create & manage the distribution file used for building LibreOffice Core && Online
DistribFile(){
  while [ $# -ne 1 ]; do
    case $1 in
      -n|--distribName) local DistribName=$2; shift 2;;
      -f|--folder) local DistribFolder=$2; shift 2;;
      -F|--file) local DistribFile=$1 ; shift 2;;
      *) break ;;
    esac
  done
  if [ -z "$DistribFile" ]; then
    local DistribFile="${DistribFolder:-"$lo_dir/distro-configs"}/${DistribName:-$distrib_name}.conf"
  fi
  if [ ! -f $DistribFile ]; then
    DistribFile.Create $DistribFile
  fi
  action=$1; shift
  while [ $# -ne 0 ]; do
    if [ -z "$buildOpts" ]; then
        local buildOpts="$1"; shift
      else
        local buildOpts="$buildOpts,$1"; shift
    fi
  done
  case $action in
    create) DistribFile.Create $DistribFile;;
    delete) DistribFile.Delete $DistribFile;;
    append) IFS=","; for parameter in $buildOpts; do
        DistribFile.Append $DistribFile $parameter
      done; IFS=" ";;
    remove) IFS=","; for parameter in $buildOpts; do
        DistribFile.Remove $DistribFile $parameter
      done; IFS=" ";;
    clear) DistribFile.Clear $DistribFile;;
  esac
  buildOpts="$*"
}


DistribFile.Append() {
  if ! egrep -q ${2}$ $1; then
    echo "--$2" | awk '{print $1}' >> $1
  fi
}

DistribFile.Remove() {
    sed -i "/^--$2$/d" $1
}

DistribFile.Create() {
  # create the distribution file only if the distrib folder exists
  if [ ! -d "$(dirname $1)" ]; then
    echo "ERROR: $(dirname $1) folder do not exist (yet?)" >&2
    return 1
  elif [ ! -f $1 ]; then
    touch $1
    return $?
  fi
}

DistribFile.Clear() {
  if [ ! -f $1 ]; then
    echo "" > $1
    return $?
  fi
}
DistribFile.Delete() {
  if [ ! -f $1 ]; then
    rm $1
    return $?
  fi
}
