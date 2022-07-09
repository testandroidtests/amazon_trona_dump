#!/system/bin/sh

PATH=/vendor/bin:/sbin:/system/sbin:/system/bin:/system/xbin

ENABLE=`getprop vendor.debug.mdump`
if [ "$ENABLE" != "1" ]; then
    exit;
fi;

# ensure any directories/files created are initially only
# u+rwx, g+rw, o+r
umask 0017


# enable ramdump if ramdump partition exists
DUMP_SYSFS_NODE=/sys/kernel/mdump/compmsg
WAIT_CNT=1
MEMDUMP_OVERRIDE=1
MEMDUMP_LIMIT=2

while [ ! -e $DUMP_SYSFS_NODE ]
do
        sleep 1;
        WAIT_CNT=$(($WAIT_CNT + 1))
        if [[ "$WAIT_CNT" -eq "10" ]]; then
                # sysfs node does not exist, exit but don't reboot
                # - this could well be a normal charging mode
                exit 4
        fi
done

FILE_ROOT_DIR="/data/vendor"
FILE_PATH="$FILE_ROOT_DIR/crashes"
FILE_PREFIX="crashdump-"
FILE_INDEX=1
FILE_SUFFIX=".bin"
FILE_NAME=$FILE_PREFIX$FILE_INDEX$FILE_SUFFIX
MEMDUMP_FILE_NAME=$FILE_PATH/$FILE_NAME
MEMDUMP_LOG="memdump-log.txt"

WAIT_CNT=1
while [ ! -d $FILE_ROOT_DIR ]
do
        sleep 1
        WAIT_CNT=$(($WAIT_CNT + 1))
        if [[ "$WAIT_CNT" -eq "15" ]]; then
                echo "#######Error: userdata is not mounted! #######"
                reboot
        fi
done

LOG_FILE_CNT=0


if ! test -d $FILE_PATH; then
	mkdir -p $FILE_PATH
	echo "Create the memory dump folder" >> $FILE_PATH/$MEMDUMP_LOG
        # for debug
        # echo "--begin" >> $FILE_PATH/$MEMDUMP_LOG
        # cat /proc/vmstat | grep wmark >> $FILE_PATH/$MEMDUMP_LOG
else
	LOG_FILE_CNT=`ls $FILE_PATH -l | grep $FILE_SUFFIX | wc -l`

	if [ $MEMDUMP_OVERRIDE -eq 1 ] && [ $LOG_FILE_CNT -eq $MEMDUMP_LIMIT ]; then
		file_to_rm=""
		oldest_file_time=`date +%s`
		while [ -e $FILE_PATH/$FILE_NAME ]
		do
			filetime=`stat -c %Y $FILE_PATH/$FILE_NAME`
			if [ $filetime -lt $oldest_file_time ]; then
				oldest_file_time=$filetime
				file_to_rm=$FILE_NAME
			fi
			FILE_INDEX=$(($FILE_INDEX + 1))
			FILE_NAME=$FILE_PREFIX$FILE_INDEX$FILE_SUFFIX
		done
		rm -rf $FILE_PATH/$file_to_rm
		echo "remove old log file: $file_to_rm" >> $FILE_PATH/$MEMDUMP_LOG
		LOG_FILE_CNT=$LOG_FILE_CNT-1
		FILE_NAME=$file_to_rm
	else
		# for debug
		# echo "--begin" >> $FILE_PATH/$MEMDUMP_LOG
		# cat /proc/vmstat | grep wmark >> $FILE_PATH/$MEMDUMP_LOG
		echo "Add new memory dump file" >> $FILE_PATH/$MEMDUMP_LOG
		while [ -e $FILE_PATH/$FILE_NAME ]
		do
			FILE_INDEX=$(($FILE_INDEX + 1))
			FILE_NAME=$FILE_PREFIX$FILE_INDEX$FILE_SUFFIX
		done
		echo $FILE_NAME >> $FILE_PATH/$MEMDUMP_LOG
		LOG_FILE_CNT=$LOG_FILE_CNT+1
	fi
fi

# save last kmsg to debug_service before dumping crashdump.
LOGTIMESTAMP=`expr $(date +%s%N) / 1000000`
LASTKMSG=/data/system/dropbox/SYSTEM_LAST_KMSG_MDUMP@$LOGTIMESTAMP.txt
THISPBLMSG=/data/system/dropbox/SYSTEM_THIS_PBLMSG_MDUMP@$LOGTIMESTAMP.txt
THISLKMSG=/data/system/dropbox/SYSTEM_THIS_LKMSG_MDUMP@$LOGTIMESTAMP.txt
LASTKEDUMPINFO=/data/system/dropbox/SYSTEM_LAST_KEDUMPINFO_MDUMP@$LOGTIMESTAMP.txt
if [ -e /data/system/dropbox ]; then
	echo "/data/system/dropbox is existed" >> $FILE_PATH/$MEMDUMP_LOG
else
	echo "/data/system/dropbox is not existed, create it !!" >> $FILE_PATH/$MEMDUMP_LOG
	mkdir -p /data/system/dropbox
fi

if [ -e /proc/last_kmsg ]; then
	echo $LASTKMSG >> $FILE_PATH/$MEMDUMP_LOG
	cat /proc/last_kmsg >> $LASTKMSG
	if [ -e /proc/life_cycle_reason ]; then
		cat /proc/life_cycle_reason >> $LASTKMSG
	fi
else
	echo "/proc/last_kmsg does not exist!" >> $LASTKMSG
fi
if [ -e /sys/kernel/mdump/pblmsg ]; then
	echo $THISPBLMSG >> $FILE_PATH/$MEMDUMP_LOG
	cat /sys/kernel/mdump/pblmsg >> $THISPBLMSG
else
	echo "/sys/kernel/mdump/pblmsg does not exist!" >> $THISPBLMSG
fi
if [ -e /sys/kernel/mdump/lkmsg ]; then
	echo $THISLKMSG >> $FILE_PATH/$MEMDUMP_LOG
	cat /sys/kernel/mdump/lkmsg >> $THISLKMSG
else
	echo "/sys/kernel/mdump/lkmsg does not exist!" >> $THISLKMSG
fi
if [ -e /proc/last_kedump_info ]; then
	echo $LASTKEDUMPINFO >> $FILE_PATH/$MEMDUMP_LOG
	cat /proc/last_kedump_info >> $LASTKEDUMPINFO
else
	echo "/proc/last_kedump_info does not exist!" >> $LASTKEDUMPINFO
fi

# make sure the last kmsg is on disk before doing memdump
sync

if [ $LOG_FILE_CNT -le $MEMDUMP_LIMIT ]; then
    echo "Generate memdump $FILE_PATH/$FILE_NAME" >> $FILE_PATH/$MEMDUMP_LOG
    dd if=$DUMP_SYSFS_NODE of=$FILE_PATH/$FILE_NAME bs=4m
else
    echo "Ignored memdump $FILE_PATH/$FILE_NAME" >> $FILE_PATH/$MEMDUMP_LOG
fi

# for debug
# echo "--end" >> $FILE_PATH/$MEMDUMP_LOG
# cat /proc/vmstat | grep wmark >> $FILE_PATH/$MEMDUMP_LOG

# echo 0 > /proc/sys/kernel/printk
reboot
