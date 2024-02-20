#!/usr/bin/bash

bash -n "$0" || exit 1
shopt -s extglob

patchnr() {
    local nr
    while [[ -n "$1" ]]; do
        nr=$(cut -d'.' -f1 <<< "$1")
        shift
        [[ $((10#$nr)) -gt 0 ]] || echo "Invalid patch number: $nr" >&2
        echo "$nr"
    done
}

if [[ -e "$HOME/git/dracut/$1" ]]; then
    srcrpm="$HOME/git/dracut/$1"
elif [[ -e "$HOME/dev/upstream/dracut/$1" ]]; then
    srcrpm="$HOME/dev/upstream/dracut/$1"
else
    srcrpm="$1"
fi

[[ -f $srcrpm ]] || exit 3

old_release=$(rpmspec -D "_sourcedir $(pwd)" -q --srpm --qf '%{release}' dracut.spec)
old_release=${old_release%%.*}

cp dracut.spec dracut.spec.old

rm *.patch; git reset --hard HEAD
last_patch_nr=$(patchnr *.patch | sort -n | tail -n 1)
last_patch_nr=${last_patch_nr:-0000}
#for i in *.patch; do git rm -f $i;done

if rpm -ivh --define "_srcrpmdir $PWD" --define "_specdir $PWD" --define "_sourcedir $PWD" "$srcrpm"; then
	  for nr in $(patchnr *.patch); do
	    [[ $((10#$nr)) -gt $((10#$last_patch_nr)) ]] && git add "${nr}.patch"
    done

    new_version=$(rpmspec -D "_sourcedir $(pwd)" -q --srpm --qf '%{version}' dracut.spec)
    new_release=$(rpmspec -D "_sourcedir $(pwd)" -q --srpm --qf '%{release}' dracut.spec)
    new_release_full=${new_release%.*}
    new_release=${new_release%%.*}

    do_print=""
    while IFS=$'\n' read -r line
    do
        if [ -z "$do_print" ] && [ "$line" = "%changelog" ]; then
            do_print="yes"
            echo "* $(LANG='C' date '+%a %b %d %Y') $(git config user.name) <$(git config user.email)> - ${new_version}-${new_release_full}"

            for ((i=old_release; i<new_release; i++)); do
                subject=$(grep '^Subject: ' +(0)$i.patch | head -1)
                if [ -n "$subject" ]; then
                    echo "-${subject#*\[PATCH\]}"
                fi
            done

            echo

        elif [ -n "$do_print" ]; then
            echo "$line"
        fi
    done < dracut.spec.old >> dracut.spec

    # Patch list:
    # ls *.patch | tr -s ' ' '\n' | cut -d'.' -f1 | xargs -i zsh -c "nr=\$((10#{})); echo \"Patch\${nr}: {}.patch\""

    git add dracut.spec

    msg="Resolves: $(
    for ((i=old_release; i<new_release; i++)); do
        resolves=$(grep '^Resolves: ' +(0)$i.patch | head -1)
        if [ -n "$resolves" ]; then
            echo "${resolves#Resolves: }"
        fi
    done | sed -e 's/rhbz#/#/g' | sort -u | tr -s '\n' ',')"

    git commit -m "$(echo -e "dracut-${new_version}-${new_release_full}\n\n${msg%,}")"

fi
