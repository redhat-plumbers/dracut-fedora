#!/usr/bin/env zsh
#
# .distro/rebase.sh [opts] VERSION
#
#   For version, only single number is currently expected.
#
# (opts must be in alphabetical order)
#
#   -b      branch to work in (default: main)
#           Uses current branch if empty. Also used as a suffix!
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
# Rebase parts (ad "-c" arg)
#
#   __TODO__
#
#
# Examples
#
#   $ .distro/rebase.sh -b rhel-10 -c 1 -p 103 105
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


wip () {
  {
    echo -e "\n>>> WIP <<<\n"

  } 2>/dev/null

  exit 999
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

  [[ -z "$b" ]] && {
    b="$(gitb | grep '^* ' | cut -d' ' -f2-)"
  }
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


## Common vars
[[ "$b" == 'main' ]] && {
  s=''

} || s="-${b}"

p="${v}-pre-rebase${s}"


## First part
[[ $c -lt 1 ]] && {

  # TODO: ./rebase.sh -b rhel-10 -p 103 105

  : 'Checkout main'
  [[ -n "$b" ]]
  gitc "$b"
  gitp
  gits | grep "^Your branch is up to date with"

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

: 'Get previous version'
[[ -n "$pv" ]] || pv="$(( ${v} - 1 ))"

[[ -n "$pv" ]]
[[ ${pv} -gt 0 ]]
[[ ${pv} -lt $v ]]


: 'List files changed downstream'
F="$( (gitds ${p} ${pv} | head -n -1; gitds ${v} | head -n -1) | tr -s ' ' | cut -d' ' -f2 | sort -u | xargs echo)"


: "Diff downstream changes"
gitds -p ${p} -- `echo $F`
gitds -p ${p} -- `echo $F` > "dracut_rebase_${v}_changes_downstream${s}_$(date -I).diff"


: "Diff from upstream changes"
gitds -p ${v}
gitds -p ${v} > "dracut_rebase_${v}_changes_upstream${s}_$(date -I).diff"


: "Complete diff"
gitds -p ${p}
gitds -p ${p} > "dracut_rebase_${v}_changes_complete${s}_$(date -I).diff"


# WORK IN PROGRESS
wip

ls -d dracut_rebase_108_changes_*| xargs -ri zsh -c "echo -n '{}: '; gist -spf {}{,}"


# Next part

## Todo: version bumps (probably a second step)
rpmdev-bumpspec -D -c 'build: upgrade to dracut 107' -u 'Pavel Valena <pvalena@redhat.com>' .distro/*.spec

nn .distro/dracut.spec



gitl1 107-pre-rebase -1

gitl1 107 -1


nn .packit.yml

cp -vi .packit.yml .distro/source-git.yaml

nn .distro/source-git.yaml

gita .packit.yml .distro/source-git.yaml


gita .distro/dracut.spec


## Todo: source-git commit
gitim 'build: upgrade to dracut 107'

gith

## SRPM -- once
nn .distro/*.spec
n=1; rm .distro/*.patch; rm *.src.rpm; packit srpm --no-update-release --release-suffix ${n}
nn .distro/*.patch


# Next step
## SRPM -- again?
## TODO: builds

### Report (if all succeeds?)
gitd 107-pre-rebase | gist -spf dracut_rebase_107_changes_complete_$(date -I).diff


### Next step

gist -spf dracut_rebase_107_changes_downstream_2025-07-02.diff{,}
gist -spf dracut_rebase_107_changes_upstream_2025-07-02.diff{,}


MSG="
Rebase from downstream commit a4e87db1ba678f7f3b65cd65730132ca399cdf3e onto upstream tag 107 (279da16f1b8fcca27d41937967c4e8f4c295086a).

Test builds:
 - Koji Rawhide: TBD
 - Koji F42: TBD
 - COPR: https://copr.fedorainfracloud.org/coprs/build/9233168

Smoke tests:
 - Rawhide aarch64: https://gist.github.com/pvalena/9151b9ae01288759a9b5d1bb989b99c7
 - Rawhide x86_64 (no reboot): https://gist.github.com/pvalena/8f7b7d2ae219eaec9d68922eaf6d4372
 - F42 aarch64: https://gist.github.com/pvalena/284a0cf9da6dcc2d0e40d239660d1e99
 - F41 x86_64: https://gist.github.com/pvalena/e0016f383a00e032b0728ddd34b0239e

Diff:
 - Downstream-modified changes only: https://gist.github.com/pvalena/d1af4a74194e77417d496b6abe294ae9
 - Changes from upstream: https://gist.github.com/pvalena/06fc42934b1f345e8a53b18075cc7eee
 - Complete diff: https://gist.github.com/pvalena/12de812cc0ae7829c9d5479f2b44359e
"


gh pr create -f -a '@me' -R "redhat-plumbers/dracut-fedora"


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


### WIP ###
    wip


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
