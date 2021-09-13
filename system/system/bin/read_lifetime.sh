#!/system/bin/sh
#
# Copyright (c) 2019 - 2020 Amazon.com, Inc. or its affiliates.  All rights reserved.
#
# PROPRIETARY/CONFIDENTIAL.  USE IS SUBJECT TO LICENSE TERMS.

lifetime_file_name="/sys/block/mmcblk0/device/life_time";
pre_eol_info_file_name="/sys/block/mmcblk0/device/pre_eol_info";
manfid_file_name="/sys/block/mmcblk0/device/manfid";

lifetime=$(<$lifetime_file_name)
pre_eol_info=$(<$pre_eol_info_file_name)
manfid=$(<$manfid_file_name)

lifetime="${lifetime} ${pre_eol_info} ${manfid}"
setprop sys.amzn_bsp_diag.emmc_lifetime "$lifetime"