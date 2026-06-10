#!/bin/sh

command -v source_hook > /dev/null || . /lib/dracut-lib.sh

for ifpath in /sys/class/net/*; do
    ifname="${ifpath##*/}"

    # shellcheck disable=SC2015
    [ "$ifname" != "lo" ] && [ -e "$ifpath" ] && [ ! -e /tmp/networkd."$ifname".done ] || continue

    if /usr/lib/systemd/systemd-networkd-wait-online --timeout=0.000001 --interface="$ifname" 2> /dev/null; then
        leases_file="/run/systemd/netif/leases/$(cat "$ifpath"/ifindex)"
        dhcpopts_file="/tmp/dhclient.${ifname}.dhcpopts"
        if [ -r "$leases_file" ]; then
            while IFS='=' read -r key val; do
                case "$key" in
                    NEXT_SERVER) printf 'new_next_server=%q\n' "$val" ;;
                    ROOT_PATH) printf 'new_root_path=%q\n' "$val" ;;
                esac
            done < "$leases_file" > "$dhcpopts_file"
        fi

        source_hook initqueue/online "$ifname"
        /sbin/netroot "$ifname"

        : > /tmp/networkd."$ifname".done
    fi
done
