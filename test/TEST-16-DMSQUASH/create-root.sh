#!/bin/sh

trap 'poweroff -f' EXIT

# don't let udev and this script step on eachother's toes
for x in 64-lvm.rules 70-mdadm.rules 99-mount-rules; do
    : > "/etc/udev/rules.d/$x"
done
rm -f -- /etc/lvm/lvm.conf
udevadm control --reload
set -e

udevadm settle

# create a single partition using 50% of the capacity of the image file created by test_setup() in test.sh
sfdisk /dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_root << EOF
2048,161792
EOF

udevadm settle

mkfs.ext4 -q -L dracut /dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_root-part1
mkdir -p /root
mount -t ext4 /dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_root-part1 /root
mkdir -p /root/run /root/testdir
cp -a -t /root /source/*
echo "Creating squashfs"
mksquashfs /source /root/testdir/rootfs.img -quiet

# Write the erofs compressed filesystem to the partition
if [ -e "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_root_erofs" ]; then
    sfdisk /dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_root_erofs << EOF
2048,161792
EOF

    udevadm settle

    echo "Creating erofs"
    mkfs.erofs /dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_root_erofs-part1 /source
fi

# Copy rootfs.img to the NTFS drive if exists
if [ -e "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_root_ntfs" ]; then
    mkfs.ntfs -q -F -L dracut_ntfs /dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_root_ntfs
    mkdir -p /root_ntfs
    mount -t ntfs3 /dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_root_ntfs /root_ntfs
    mkdir -p /root_ntfs/run /root_ntfs/testdir
    cp /root/testdir/rootfs.img /root_ntfs/testdir/rootfs.img
fi

umount /root
echo "dracut-root-block-created" | dd oflag=direct,dsync of=/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_marker status=none
poweroff -f
