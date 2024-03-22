#!/usr/bin/bash

# called by dracut
check() {
    # If our prerequisites are not met, fail anyways.
    require_binaries mount.cifs || return 1

    [[ $hostonly ]] || [[ $mount_needs ]] && {
        for fs in "${host_fs_types[@]}"; do
            [[ $fs == "cifs" ]] && return 0
        done
        return 255
    }

    return 0
}

# called by dracut
depends() {
    # We depend on network modules being loaded
    echo network
}

# called by dracut
installkernel() {
    instmods cifs ipv6
    # hash algos
    instmods md4 md5 sha256 sha512
    # ciphers
    instmods aes arc4 des ecb gcm aead2
    # macs
    instmods hmac cmac ccm
}

# called by dracut
install() {
    local _nsslibs
    inst_multiple -o mount.cifs
    inst_multiple -o /etc/services /etc/nsswitch.conf /etc/protocols
    inst_multiple -o /usr/etc/services /usr/etc/nsswitch.conf /usr/etc/protocols

    inst_libdir_file 'libcap-ng.so*'

    _nsslibs=$(
        cat "$dracutsysrootdir"/{,usr/}etc/nsswitch.conf 2> /dev/null \
            | sed -e '/^#/d' -e 's/^.*://' -e 's/\[NOTFOUND=return\]//' \
            | tr -s '[:space:]' '\n' | sort -u | tr -s '[:space:]' '|'
    )
    _nsslibs=${_nsslibs#|}
    _nsslibs=${_nsslibs%|}

    inst_libdir_file -n "$_nsslibs" 'libnss_*.so*'

    inst_hook cmdline 90 "$moddir/parse-cifsroot.sh"
    inst "$moddir/cifsroot.sh" "/sbin/cifsroot"
    inst "$moddir/cifs-lib.sh" "/lib/cifs-lib.sh"
    dracut_need_initqueue
}
