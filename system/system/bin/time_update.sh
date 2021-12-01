#!/system/bin/sh
#
# Copyright (c) 2018 - 2019  Amazon.com, Inc. or its affiliates.  All rights reserved.
#
# PROPRIETARY/CONFIDENTIAL.  USE IS SUBJECT TO LICENSE TERMS.
#
LOG=/system/bin/log
TAG=TimeService.Shell

print() {
    $LOG -t $TAG $1
}

store_time=`getprop persist.sys.saved_time`
store_time=${store_time%???}  #convert milliseconds to seconds
system_time="`date +%s`"
if (("$store_time" > "$system_time"))
then
    date -u @$store_time
    print "Successfully set time on boot"
else
    print "Did not set time on boot"
fi
