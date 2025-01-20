#!/usr/bin/env zsh
#
# ./update.sh [opts] VERSION
#
#   For version, only single number is currently expected.
#
# (opts must be in alphabetical order)
#
#   -b      branch to work in (default: main)
#
#   -c X    continue with part X (default: 0)
#
#   -d      dry run (no destructive changes)
#
#   -p      WIP: previous version (default VERSION - 1)
#
#   -h      TODO: HELP (echo this)
#
#
#   Rebase parts (ad "-c" arg)
#
#     __TODO__
#
#


set -xe

## Methods
dry () {
  { local cmd="$@" ; } 2>/dev/null

  zsh -n -c "$cmd"

  [[ -n "$d" ]] && {
    { echo "<<<dry>>> $cmd"
      return
    } 2>/dev/null
  }

  zsh -c "$cmd"
}

ext () {
  {
    local n=$(( $c + 1 ))
    echo -e "\n>>> You can continue with: ${x} -c $n"
  } 2>/dev/null

  exit 0
}


## Syntax check
zsh -n "$0"

{ echo;
  x="$(readlink -e $0)"
} 2>/dev/null


## Args
: 'Branch = -b'
[[ "$1" == "-b" ]] && {
  b="${2}"
  shift 2 ||:
  :
} || b='main'


: 'Continue = -c'
[[ "$1" == "-c" ]] && {
  c="${2}"
  shift 2 ||:

  [[ -n "$c" ]]
  [[ ${c} -ge 0 ]]
  [[ ${c} -lt 1000 ]]
  :
} || c=0

: 'Dry mode = -d'
[[ "$1" == "-d" ]] && {
  d=dry
  shift ||:
  :
} || d=

: "Previous version = -p"
[[ "$1" == "-p" ]] && {
  pv="$2"
  shift 2 ||:
  :
} || pv=


: 'Quiet mode = -q'
[[ "$1" == "-q" ]] && {
  q=quiet
  set +x
  shift ||:
  :
} || q=


: 'Version = $1'
v="$1"
shift

[[ -n "$v" ]]
[[ ${v} -gt 0 ]]
[[ ${v} -lt 1000 ]]

{
  echo -e "\n>>> #${c}\n"

} 2>/dev/null


## First part
[[ $c -lt 1 ]] && {

  : 'Checkout main'
  [[ -n "$b" ]]
  gitc "$b"
  gitp
  gits | grep "^Your branch is up to date with"

  [[ "$b" == 'main' ]] && \
    s='' \
    || s="-${b}"

  p="${v}-pre-rebase${s}"
  : "Switch to pre-release branch: $p"
  dry gitcb "$p"
  dry gituu origin "$p"

  r="rebase-${v}${s}"
  : "Switch to rebase branch: $r"
  dry gitcb "$r"
  dry gituu origin "$r"
  gits | grep "^Your branch is up to date with"

  : 'Check upstream tag'
  gitf upstream-ng
  gith "${v}" | head -n 1 | grep ^tag

  : 'Rebase'
  dry gite "${v}"

  : 'Verify commits'
  gitlp ||:

  ext
}
{ echo; } 2>/dev/null


## Second part
[[ $c -lt 2 ]] && {
: 'Continue #1'

: "Diff from upstream changes"
gitds -p ${v}
gitds -p ${v} \
  | tee "dracut_rebase_${v}_diff_upstream_$(date -I).log"

: 'Get previous version'
[[ -n "$pv" ]] || pv="$(( ${v} - 1 ))"

[[ -n "$pv" ]]
[[ ${pv} -gt 0 ]]
[[ ${pv} -lt $v ]]

: 'List files changed downstream'
F="$((gitds ${v}-pre-rebase ${pv} | head -n -1; gitds ${v} | head -n -1) | tr -s ' ' | cut -d' ' -f2 | sort -u | xargs echo)"

: "Diff downstream changes"
gitds -p ${v}-pre-rebase -- `echo $F`
gitds -p ${v}-pre-rebase -- `echo $F` \
  | tee "dracut_rebase_${v}_diff_downstream_$(date -I).log"

exit 7

: 'Upgrade files version'


: 'Bump spec version'


: 'Review'


: 'Create SRPM'
packit srpm --no-update-release --release-suffix 1


: 'Cleanup'


: 'Mock build'
mck *.src.rpm


: 'Mock install'
mck i result/*.(noarch|x86_64).rpm


: 'COPR scratch-build'
~/lpcsf-new/test/scripts/pkgs/cr-build.sh -s dracut


: 'Koji scratch-build'
~/lpcsf-new/test/scripts/pkgs/kj-build.sh -s rawhide


: 'Test'
pushd ../fedora
vagrant halt
vagrant status
vagrant up
sleep 3
vagrant status
vagrant provision
vagrant halt||:
vagrant halt
sleep 3
vagrant up
vagrant ssh -c 'rpm -q dracut; uname -r; ls -lahd /boot/*init*'
popd

exit 3
}
{ echo; } 2>/dev/null
exit 999


# Third part
[[ $c -lt 3 ]] && {
: 'Continue #2'

: 'Push'
gits
gitu


: 'Pull request'
gh pr create -d -f -l bug -a '@me' -R redhat-plumbers/dracut-fedora

exit 4
}

[[ $c -lt 4 ]] && {
: 'Continue #3'

: 'Change dir'
cd ../dracut


: 'Import'
fedpkg import ../source-git/dracut-${pv}-None.fc41.src.rpm
gitiam "$M"

exit 5
}


[[ $c -lt 5 ]] && {
: 'Continue #4'

: 'Downstream PR'
gitcb rebase-${v}
gituu
~/lpcsf-new/test/scripts/fedora/create_pr.sh -g


: 'TBD'
exit 6
}

: 'Wrong continue'
exit 7
