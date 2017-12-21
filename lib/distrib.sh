#!/bin/bash
# shellcheck disable=SC2154,SC2034,SC2068
# create & manage the distribution file used for building LibreOffice Core && Online
DistribFile(){
  # usage:
  # DistribFile [-n distribname][-f folder][-F file] action build_options...
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
  local action=$1; shift
  while [ $# -ne 0 ]; do
    IFS=','
    myargs=($1)
    IFS=" "
    for myarg in ${myargs[@]}; do
      # remove optionnal '--' in front of option name
      if [ "--" = "${1:0:2}" ]; then
        local myarg="${1:2}"
      else
        local myarg="$1"
      fi
      # create a list, comma separated of all options
      if [ -z "$buildOpts" ]; then
          local buildOpts="$myarg"
        else
          local buildOpts="$buildOpts,$myarg"
      fi
    done
    shift
  done
  case $action in
    create) DistribFile.Create $DistribFile;;
    delete) DistribFile.Delete $DistribFile;;
    append) IFS=",";
      for parameter in $buildOpts; do
        # remove opposite options from the distribution:
        # if option disable-something, remove previous option enable-something and vice versa
        # latest option win
        case "$(cut -d '-' -f1 <<<$parameter )" in
          disable) DistribFile.Remove $DistribFile ${parameter//disable/enable};;
          enable) DistribFile.Remove $DistribFile ${parameter//enable/disable};;
          without) DistribFile.Remove $DistribFile ${parameter//without/with};;
          with) DistribFile.Remove $DistribFile ${parameter//with/without};;
        esac
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
    sed -i "/^--${2//\//\\\/}$/d" $1
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
  if [ -f $1 ]; then
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
