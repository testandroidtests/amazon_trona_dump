#!/system/bin/sh
#
# Copyright (c) 2018 - 2019 Amazon.com, Inc. or its affiliates.  All rights reserved.
# PROPRIETARY/CONFIDENTIAL.  USE IS SUBJECT TO LICENSE TERMS.
#
#
# Usage:
#
# # this command will try to create the image file if it's not existing,
# # otherwise the last two args are ignored
# vpartition.sh --mount <mount point> <image file> <block size> <number of blocks>
#
# # umount virtual partition
# vpartition.sh --umount <mount point>
#
# # erase image file. This command will try umount first if mount point is given
# vpartitoin.sh --erase <image file> [mount point]
#

TAG="vpartition"
PROP="vpartition.status.metrics"
log -p i -t $TAG "vpartition.sh $@"

if [ "$1" == "--mount" ]
then
    # check device encrypt state
    crypto_state=$(getprop "ro.crypto.state")
    vold_decrypt=$(getprop "vold.decrypt")
    log -p d -t $TAG "ro.crypto.state=$crypto_state, vold.decrypt=$vold_decrypt"
    if [ "$crypto_state" == "encrypted" ] && [ "$vold_decrypt" != "trigger_restart_framework" ]
    then
        log -p i -t $TAG "device is encrypted, skip virtual partition"
        exit 0
    fi

    # check if it's already mounted
    mountpoint -q $2
    if [ "$?" -eq 0 ]
    then
        log -p d -t $TAG "$2 is already mounted"
        exit 0
    fi

    # create image if not exist
    if [ ! -f $3 ]
    then
        log -p d -t $TAG "creating image $3"
        dd if=/dev/zero of=$3 bs=$4 count=$5
        mkfs.ext4 -t ext4 -b $4 -F $3
    fi

    # check image is available
    if [ ! -f $3 ]
    then
        setprop $PROP "error"
        log -p e -t $TAG "image file not exists"
        exit 1
    fi

    # Delegate mount to init due to SELinux neverallow rule restricting
    # domains that can mount
    setprop $PROP "mount"

elif [ "$1" == "--verify" ]
then
    # check if mount worked
    mountpoint -q $2
    if [ "$?" -ne 0 ]
    then
        setprop $PROP "error"
        log -p e -t $TAG "failed to mount $3 on $2"
        exit 1
    fi
    setprop $PROP "ready"
    log -p i -t $TAG "$3 is successfully mounted on $2"

elif [ "$1" == "--umount" ]
then
    # Use toybox's umount since it also frees the loop device.
    # Open file descriptors prevent unmount (including force), so do a lazy unmount.
    umount -l $2
    if [ "$?" -ne 0 ]
    then
        setprop $PROP "error"
        log -p e -t $TAG "failed to unmount $2"
        exit 1
    fi
    setprop $PROP "unmounted"
    log -p d -t $TAG "$2 is unmounted"

elif [ "$1" == "--erase" ]
then
    if [ "$#" -eq 3 ]
    then
        umount -l $3
        if [ "$?" -ne 0 ]
        then
            log -p e -t $TAG "failed to unmount $3"
        fi
    fi
    rm $2
    setprop $PROP "removed"
    log -p d -t $TAG "$2 is removed"

else
    echo "unrecognized command $@"
fi

exit 0
