#!/bin/bash
# This file is part of dracut.
# SPDX-License-Identifier: GPL-2.0-or-later

check() {
    return 255
}

# called by dracut
install() {
    # Follow the same priority as `systemd-hwdb`; `/etc` is the default
    # and `/usr/lib` an alternative location.
    inst_multiple "${udevconfdir}"/hwdb.bin

    if [[ $hostonly ]]; then
        inst_multiple -H -o "${udevdir}"/hwdb.bin
    fi
}
