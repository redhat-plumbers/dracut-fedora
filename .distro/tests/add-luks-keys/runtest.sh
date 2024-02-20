#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /dracut/add-luks-keys
#   Description: Create and add a luks key to all luks devices to allow booting of a system without entering a passphrase
#   Author: Jan Stodola <jstodola@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2016 Red Hat, Inc. All rights reserved.
#   Red Hat Internal
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="dracut"

keyfile="/root/keyfile"
kernel_file=`grubby --default-kernel`
initrd_file=`grubby --info=$kernel_file | grep ^initrd= | sed 's/^initrd=//' | head -n1`
kernel_version=`rpm -qf $kernel_file --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n'`

rlJournalStart
  rlPhaseStartTest "Add luks keys to initramfs"

    if [ ! -e "$keyfile" ]; then
      rlLog "Creating new key file: $keyfile"
      rlRun "dd if=/dev/urandom bs=1 count=32 of=$keyfile" 
      rlRun "chmod 0400 $keyfile"
    else
      rlLog "Using existing key file: $keyfile"
    fi

    rlAssertExists "/etc/crypttab"
    rlFileSubmit "/etc/crypttab"
    UUIDS=`cat /etc/crypttab | cut -d' ' -f2 | cut -d'=' -f2`
    for UUID in $UUIDS; do
      rlRun "echo 'redhat' | /sbin/cryptsetup luksAddKey /dev/disk/by-uuid/$UUID $keyfile" 
    done;

    # modify /etc/crypttab, set key file in the thirth column of the file
    rlRun "awk -v \"KEY_FILE=$keyfile\" '{\$3=KEY_FILE; print \$0}' /etc/crypttab > crypttab_mod" 
    rlRun "mv -Z crypttab_mod /etc/crypttab"
    rlRun "chmod 0600 /etc/crypttab"

    rlRun "dracut -f -I $keyfile $initrd_file $kernel_version" 

    # zipl has to be executed on s390x
    if [ -x /sbin/zipl ]; then
      rlRun "/sbin/zipl"
    fi

  rlPhaseEnd
rlJournalEnd

