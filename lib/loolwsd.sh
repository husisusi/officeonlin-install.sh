#!/bin/bash
# shellcheck disable=SC2068
addwopihost() {
  myfile=$1
  mydomains=($2)
  [ ! -f $myfile ] && echo "ERROR: $myfile, do not exist !" && return 1
  let "myline = $(grep -n '<wopi .*>' $myfile | cut -d : -f1) + 1"
  mypattern="$(sed "${myline}q;d" $myfile)"
  for domain in ${mydomains[@]}; do
    if ! grep -q  "${domain//./\\\\.}" $myfile; then
      # generate the line to insert in the file
      # escaping the \ that's the dots. (so \\\\.)
      myinsert="$(sed -e "s/localhost/$domain/" -e 's/\.\([a-z]\)/\\\\.\1/g' <<<"$mypattern")"
      sed -i "${myline}a \\$myinsert" $myfile
    fi
  done
  return 0
}
