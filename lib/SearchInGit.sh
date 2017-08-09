#!/bin/bash
SearchGitCommit() {
  # return all the commands required to set the repo to the desired state
  # (change branch and head to a commit found by search on the repo tree)
  # return also a trigger value "repChanged" that's true if the repo must be updated
  # Usage = FundGitCommit [--branch|-t [branch name], --commit|-t [commit], --tag|-t [tag]]
  ##CONSTRAINT : if commit|tag is used it must exist in the current/new branch
  # options precedence: branch + commit > tag > default
  # accept long options with '=' (--branch="master"|--branch master)
  # accept long and short commit hash
  local rcode=false myBranch myCommit myTag myTagCommit HeadBranch HeadCommit latestTagCommit latestCommit
  if [ ! -d .git ]; then
    # /!\ Current directory must be inside the git repository
    echo "Error: current directory is not a git repository !" >&2
    return 2
  fi
  while [ $# -ne 0 ]; do
    case $1 in
      "--branch*"|'-b')
        if [[ $1 =~ "=" ]]; then
          myBranch=$(echo $1 |cut -d '=' -f2)
          shift 1
        else
          local myBranch=$2
          shift 2
        fi
        ;;
      "--commit*"|'-c')
        if [[ $1 =~ "=" ]]; then
          myCommit=$(echo $1 |cut -d '=' -f2)
          shift 1
        else
          local myCommit=$2
          shift 2
        fi
        ;;
      "--tag*"|'-t')
        if [[ $1 =~ "=" ]]; then
          myTag=$(echo $1 |cut -d '=' -f2)
          shift 1
        else
          local myTag=$2
          shift 2
        fi
        ;;
      *) shift 1 ;;
    esac
  done
  # getting local info on the repository.
  HeadBranch=$(git branch|grep -e '^\*' |awk '{print $NF}')
  HeadCommit=$(git rev-parse HEAD)
  git fetch
  # checking if args are valid inside the repository
  if [ -n "$myBranch" ]; then
    if ! git branch -a| grep -q $myBranch; then
      # check if branch doesn't exist localy or remotely, then quit.
      echo "Error: $myBranch is not a valid branch." >&2
      return 1
    fi
    #change the remote branch if needed and reset to latestCommit
    latestCommit=$(git log -1 origin/${myBranch}| grep ^commit | awk '{print $NF}')
    [ "${myBranch}" != "${HeadBranch}" ] && echo "git checkout ${myBranch};" && rcode=true
    HeadBranch="$myBranch"
    # return 0
  fi
  if [ -n "$myCommit" ]; then
    if ! git cat-file commit $myCommit >/dev/null; then
      # check if the commit doesn't exist
      echo "Error: $myCommit is not a valid commit." >&2
      return 1
    elif ! git log --simplify-by-decoration --decorate --pretty=oneline "origin/$HeadBranch" | grep -q "$myCommit"; then
      echo "Error: $myCommit is not in branch $HeadBranch." >&2
      return 1
    fi
    #find the commit's long hash from the short hash
    myCommit=$(git log --simplify-by-decoration --decorate --pretty=oneline "origin/$HeadBranch" | grep "$myCommit"|awk '{print $1}')
    [ "${myCommit}" != "${HeadCommit}" ] && echo "git reset --hard ${myCommit};" && rcode=true
    echo "repChanged=$rcode"
    return 0
  fi
  if [ -n "$myTag" ]; then
     if ! git ls-remote -t | grep -q tags/${myTag}^; then
       # check if the Tag doesn't exist
       echo "Error: $myTag is not a valid Tag." >&2
       return 1
     elif ! git log --simplify-by-decoration --decorate --pretty=oneline "origin/$HeadBranch" | grep -Eq "tag:.*$myCommit"; then
       echo "Error: $myTag is not in branch $HeadBranch." >&2
       return 1
     fi
    myTagCommit=$(git log --simplify-by-decoration --decorate --pretty=oneline "origin/$HeadBranch" | grep -Em 1 "tag:.*$myCommit"|awk '{print $1}')
    [ "${myTagCommit}" != "${HeadCommit}" ] && echo "git reset --hard ${myTagCommit};" && rcode=true
    echo "repChanged=$rcode"
    return 0
  else
    # if no argument has been given, just get the latest tag of the branch.
    latestTag=$(git log --simplify-by-decoration --decorate --pretty=oneline "origin/$HeadBranch" | grep -Em 1 "tag: ")
    latestTagCommit=$(echo "$latestTag"|awk '{print $1}')
    echo "echo \"Selected Tag: $(echo ${latestTag} | sed 's/.*tag: \(.*\)[)] .*/\1/') ${latestTag:0:7}\""
    [ "${latestTagCommit}" != "${HeadCommit}" ] && echo "git reset --hard ${latestTagCommit};" && rcode=true
    echo "repChanged=$rcode"
    return 0
  fi
  # this block is for completion as this function is never going to be called without args here.
  if [ -z "${myBranch}${myCommit}${myTag}" ]; then
    latestCommit=$(git log -1 origin/${HeadBranch}| grep ^commit | awk '{print $NF}')
    [ ${latestCommit} != ${HeadCommit} ] && echo "git reset --hard ${latestCommit};" && rcode=true
    echo "repChanged=$rcode"
    return 0
  fi
}


FindOnlineSet() {
  # Search Libreoffice "core" and "online" repositories for a supposed compatible set of branches
  # for a better LibreOffice Online experience :)
  # return 1 branch name for each core and online that match a set
  # Take 5 arguments:
  # $1 the set name
  # $2 the "core" repository url
  # $3 a expected regex defining the branch name in the core repository
  # $4 the "online" repository url
  # $5 a expected regex defining the branch name in the online repository
  # 1 optional arg:
  # $6 a desired common version for the set. (latest possible if let unused)
  local set_name="$1" core_repo="$2" core_regex="$3" online_repo="$4" online_regex="$5" set_ver core_avail online_avail
  [ -n "$6" ] && set_ver=$(echo "$6"| tr '-' '.')
  core_avail=$(git ls-remote --heads $core_repo "*$set_name*"|awk '{print $2}'|sed 's/refs\/heads\///g'|grep -E "$core_regex")
  online_avail=$(git ls-remote --heads $online_repo "*$set_name*"|awk '{print $2}'|sed 's/refs\/heads\///g'|grep -E "$online_regex")
  [[ (-z "$core_avail") || (-z "$online_avail") ]] && echo "No set found for $set_name">&2 && return 1
  if [[ ($(echo "$core_avail"| wc -w) -eq 1) && ($(echo "$online_avail"| wc -w) -eq 1) ]]; then
    echo "$core_avail $online_avail"
    return 0
  fi
  if [ -n "$set_ver" ]; then
    FindSetVersion() {
      # nested function for searching a common version number
      # $@ is a list for branch name
      local interview
      local ver_branch_set
      for candidate in "$@"; do
        interview=$(echo $candidate | tr '-' '.' | grep $set_ver)
        [ -n "$interview" ] && ver_branch_set="$ver_branch_set $candidate"
          # if more than one match (sub version), rely on git sorting the version to get the latest available
          echo $ver_branch_set|awk '{print $NF}'
      done
    }
    core_avail=$(FindSetVersion $core_avail)
    online_avail=$(FindSetVersion $online_avail)
    if [[ ( -z "$core_avail" ) || ( -z "$online_avail" ) ]]; then
      echo "Unable to find a proper set for $set_name at version $set_ver." >&2
      return 2
    fi
  fi
    # if more than one match, rely on git sorting the version to get the latest available
    # /!\ limited results when to much branches
    echo $core_avail|awk '{print $NF}'
    echo $online_avail|awk '{print $NF}'
    return 0
}
