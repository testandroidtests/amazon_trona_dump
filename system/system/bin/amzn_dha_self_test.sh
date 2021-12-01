#!/system/bin/sh
#
# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#

# Check if service amzn_drmprov exists and is stopped
while true
do
    value=$(getprop init.svc.amzn_drmprov dummy)
    if [[ "$value" = "dummy" || "$value" = "stopped" ]]; then
        break
    fi
    sleep 1
done

# Executes the amzn_dha_tool self-test
amzn_dha_tool -t > /dev/null 2>&1

# Check return status and setprop accordingly
if [ $? -eq 0 ]; then
	setprop ro.amzn_dha.self_test success
else
	setprop ro.amzn_dha.self_test fail
fi
