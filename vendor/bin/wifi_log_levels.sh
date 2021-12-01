#!/vendor/bin/sh
## Copyright (c) 2017 - 2021 Amazon.com, Inc. or its affiliates. All rights reserved.
##
## PROPRIETARY/CONFIDENTIAL. USE IS SUBJECT TO LICENSE TERMS.
LOGSRC="wifi"
LOGNAME="wifi_log_levels"
DELAY=120
LOOPSTILMETRICS=29 # Should send to metrics buffer every hour
currentLoop=0
SUPPORT_BAND=-1 # Not initialized
FW_ANT_SWITCH_METADATA_NUM=4 # Metadata number
FW_ANT_SWITCH_METADATA1_NUM=4 # Metadata1 number
# The number of the combination of metadata and metadata1 in fw_ant_switch metrics
FW_ANT_SWITCH_TOTAL_METADATA_MULTI_METADAT1_NUM=16
alias IWPRIV='/vendor/bin/iwpriv $WLAN_INTERFACE'
alias IWPRIV_DRV='IWPRIV driver'
alias LOG_TO_PMET='log -m -t "metrics.$LOGNAME"'
alias LOG_TO_KDM='log -v -t "Vlog"'
alias LOG_TO_MAIN='log -t "main.$LOGNAME"'

if [ ! -x $IWPRIV ] ; then
	exit
fi

function set_wlan_interface ()
{
	local driver_status=`getprop wlan.driver.status`
	if [ "$driver_status" = "ok" ]; then
		WLAN_INTERFACE=`getprop wifi.interface`
	else
		WLAN_INTERFACE=""
	fi
}

function iwpriv_conn_status ()
{
	local status_str=`IWPRIV connStatus`
	local conn_status=""

	IFS=$'\t\n'
	for line in ${status_str[@]}; do
		case $line in
			"connStatus:"*)
				conn_status=${line#*\: }
				conn_status=${conn_status%% \(*}
				;;
		esac
	done
	unset IFS
	echo $conn_status
}

# Output sample of command "iwpriv wlan0 stat"
#	Tx success = 88561
#	Tx retry count = 16387
#	Tx fail to Rcv ACK after retry = 0
#	Rx success = 31032
#	Rx with CRC = 3774376
#	Rx drop due to out of resource = 0
#	Rx duplicate frame = 0
#	False CCA(total) =
#	False CCA(one-second) =
#	RSSI = -52
#	P2P GO RSSI =
#	SNR-A =
#	SNR-B (if available) =
#	NoiseLevel-A =
#	NoiseLevel-B =
#
#	[STA] connected AP MAC Address = 18:64:72:74:42:7c
#	PhyMode:802.11n
#	RSSI =
#	Last TX Rate = 65000000
#	Last RX Rate = 65000000
function iwpriv_stat_tokens ()
{
	IFS=$'\t\n'
	STAT=($(IWPRIV stat))

	for line in ${STAT[@]}; do
		case $line in
			"Tx success"*)
				TXFRAMES=${line#*= }
				;;
			"Tx retry count"*)
				TXRETRIES=${line#*= }
				TXRETRIES=${TXRETRIES%,*}
				TXPER=${line#*PER=}
				;;
			"Tx fail to Rcv ACK after retry"*)
				TXRETRYNOACK=${line#*= }
				TXRETRYNOACK=${TXRETRYNOACK%,*}
				TXPLR=${line#*PLR=}
				;;
			"Rx success"*)
				RXFRAMES=${line#*= }
				;;
			"Rx with CRC"*)
				RXCRC=${line#*= }
				RXCRC=${RXCRC%,*}
				RXPER=${line#*PER=}
				;;
			"Rx drop due to out of resource"*)
				RXDROP=${line#*= }
				;;
			"Rx duplicate frame"*)
				RXDUP=${line#*= }
				;;
			"False CCA(total)"*)
				TOTALCCA=${line#*= }
				;;
			"False CCA(one-second)"*)
				ONECCA=${line#*= }
				;;
			"RSSI"*)
				if [ "$HADRSSI" -eq 0 ]; then
					RSSI=${line#*= }
					HADRSSI=1
				fi
				;;
			"PhyRate:"*)
				if [ "$HADPHYRATE" -eq 0 ] ; then
					PHYRATE=${line#*PhyRate:}
				fi
				HADPHYRATE=1
				;;
			"PhyMode:"*)
				if [ "$PHYMODE" = "unknown" ] ; then
					line=${line#*PhyMode:}
					# Delete all spaces from the string to unify following string process.
					line=${line// /}
					if [ -n "$line" ]; then
						PHYMODE=$line
					fi
				fi
				;;
			"Last TX Rate"*)
				if [ "$HADLASTTXRATE" -eq 0 ]; then
					LASTTXRATE=${line#*= }
					HADLASTTXRATE=1
				fi
				;;
			"Last RX Rate"*)
				if [ "$HADLASTRXRATE" -eq 0 ]; then
					LASTRXRATE=${line#*= }
					HADLASTRXRATE=1
				fi
				;;
			"SNR-A"*)
				SNRA=${line#*= }
				;;
			"SNR-B"*)
				SNRB=${line#*= }
				;;
			"NoiseLevel-A"*)
				NOISEA=${line#*= }
				;;
			"NoiseLevel-B"*)
				NOISEB=${line#*= }
				;;
		esac
	done

	unset IFS
}

# Output sample of command "iwpriv wlan0 get_int_stat"
#	Abnormal Interrupt:0
#	Software Interrupt:0
#	TX Interrupt:25
#	RX data:23
#	RX Event:39
#	RX mgmt:0
#	RX others:0
function iwpriv_int_stat_tokens ()
{
	IFS=$'\t\n'
	INTSTAT=($(IWPRIV get_int_stat))

	for line in ${INTSTAT[@]}; do
		case $line in
			"Abnormal Interrupt"*)
				ABNORMALINT=${line#*:}
				;;
			"Software Interrupt"*)
				SOFTINT=${line#*:}
				;;
			"TX Interrupt"*)
				TXINT=${line#*:}
				;;
			"RX data"*)
				RXDATAINT=${line#*:}
				;;
			"RX Event"*)
				RXEVENTINT=${line#*:}
				;;
			"RX mgmt"*)
				RXMGMTINT=${line#*:}
				;;
			"RX others"*)
				RXOTHERINT=${line#*:}
				;;
		esac
	done

	unset IFS
}

function get_max_signal_stats
{
	maxRssi=$RSSI
	maxNoise=$NOISEA

	# Update property for AmazonWifiManager.getNoise
	setprop 'vendor.wifi.wlan0.noise' $maxNoise
	if [[ "$maxRssi" -ne 0 && "$maxNoise" -ne 0 ]] ; then
		maxSnr=$(($maxRssi - $maxNoise))
	fi
}
function iwpriv_show_channel
{
	#wlan
	CHANNEL=`IWPRIV show_Channel`
	CHANNEL=${CHANNEL#*show_Channel:}
	if [ $CHANNEL -gt 5000 ]; then
		CHANNEL=$((CHANNEL-5000))
	elif [ $CHANNEL -gt 2407 ]; then
		CHANNEL=$((CHANNEL-2407))
	else
		CHANNEL=0 # Channel is unknown
	fi
	CHANNEL=$((CHANNEL/5))
}

function log_metrics_phymode
{
	if [ "$PHYMODE" ] ; then
		mode=${PHYMODE#802.*}
		mode=${mode%% *}
		# There's a bug where 5 GHz 11a is marked as 11g.
		if [[ "$mode" == "11g" && $CHANNEL -gt 14 ]] ; then
			mode="11a"
		fi
		logStr="$LOGSRC:$LOGNAME:WifiMode$mode=1;CT;1:NR"
		LOG_TO_PMET $logStr

		width=${PHYMODE#* }
		width=${width%Mhz*}"MHz"
		logStr="$LOGSRC:$LOGNAME:ChannelBandwidth$width=1;CT;1:NR"
		LOG_TO_PMET $logStr
	fi
}

function log_metrics_rssi
{
	# dev rssi
	if [ "$maxRssi" -eq 0 ]; then
		return 0
	fi
	logStr="$LOGSRC:$LOGNAME:RssiLevel$maxRssi=1;CT;1:NR"
	LOG_TO_PMET $logStr
}

function log_metrics_snr
{
	# dev snr
	if [ "$maxSnr" ]; then
		logStr="$LOGSRC:$LOGNAME:SnrLevel$maxSnr=1;CT;1:NR"
		LOG_TO_PMET $logStr
	fi
}

function log_metrics_noise
{
	# dev noise
	if [ "$maxNoise" -eq 0 ]; then
		return 0
	fi
	logStr="$LOGSRC:$LOGNAME:NoiseLevel$maxNoise=1;CT;1:NR"
	LOG_TO_PMET $logStr
}

function log_metrics_mcs
{
	#dev mcs
	mcs=${LASTRXRATE/,*/}
	if [ "$mcs" ] ; then
		logStr="$LOGSRC:$LOGNAME:$mcs=1;CT;1:NR"
		LOG_TO_PMET $logStr
	fi
}

function log_connstatus_metrics
{
	if [[ "$1" = "Connected" ]]; then
		logStr="$LOGSRC:$LOGNAME:ConnStatusConnected=1;CT;1;NR"
	elif [[ "$1" = "Not connected" ]]; then
		logStr="$LOGSRC:$LOGNAME:ConnStatusDisconnected=1;CT;1;NR"
	else
		logStr="$LOGSRC:$LOGNAME:ConnStatusOther=1;CT;1;NR"
	fi
	LOG_TO_PMET $logStr
}

function log_one_ant_switch_metric
{
	local curr_val=$1
	local last_val=$2
	local metric_key=$3
	local unsigned_int_max=4294967295

	curr_val=${curr_val#*= }
	if [ $curr_val -eq $last_val ]; then
		echo $last_val
		return
	fi

	if [ $curr_val -lt $last_val ]; then
		curr_val=$((unsigned_int_max-last_val+curr_val))
		last_val=0
	fi
	shift 3 # This function at least takes 4 parameters
	log_wifi_kdm_metric ant_switch $metric_key $((curr_val-last_val)) $@
	echo $curr_val
}

function log_kdm_ant_switch_metrics
{
	IFS=$'\t\n'
	STAT=($(IWPRIV_DRV "ant_switch_test 25"))
	# Using number instead of string is to save bandwidth of uploading metrics
	# Reason definition for key "ori", ori = Orientation:
	# 0 = remain
	# 1 = disconnect
	# 2 = scan
	# 3 = strong
	# 4 = success
	# 5 = switch back
	# Reason definition for key "scn", scn = Scan:
	# 0 = scan is successful
	# 1 = current antenna no response
	# 2 = target antenna no response
	# Reason definition for key "swt", swt = Switch:
	# 0 = total antenna switches
	# 1 = switch failure due to BT busy
	# 2 = switch failure due to timeout
	# 3 = switch failure due to wrong antenna
	# 4 = switch result other status
	for line in ${STAT[@]}; do
		case $line in
			"AS_ORIENTATION_REMAIN"*)
				ORIENTATION_REMAIN=`log_one_ant_switch_metric $line $ORIENTATION_REMAIN ori F 0`
				;;
			"AS_ORIENTATION_DISCONNECT"*)
				ORIENTATION_DISCONNECT=`log_one_ant_switch_metric $line $ORIENTATION_DISCONNECT ori F 1`
				;;
			"AS_ORIENTATION_SCAN"*)
				ORIENTATION_SCAN=`log_one_ant_switch_metric $line $ORIENTATION_SCAN ori F 2`
				;;
			"AS_ORIENTATION_STRONG"*)
				ORIENTATION_STRONG=`log_one_ant_switch_metric $line $ORIENTATION_STRONG ori S 3`
				;;
			"AS_ORIENTATION_SUCCESS"*)
				ORIENTATION_SUCCESS=`log_one_ant_switch_metric $line $ORIENTATION_SUCCESS ori S 4`
				;;
			"AS_ORIENTATION_SWITCHBACK"*)
				ORIENTATION_SWITCHBACK=`log_one_ant_switch_metric $line $ORIENTATION_SWITCHBACK ori S 5`
				;;
			"AS_SCAN_TOTAL"*)
				SCAN_TOTAL=`log_one_ant_switch_metric $line $SCAN_TOTAL scn 0`
				;;
			"AS_SCAN_CURRENT_NORSP"*)
				SCAN_CURRENT_NORSP=`log_one_ant_switch_metric $line $SCAN_CURRENT_NORSP scn 1`
				;;
			"AS_SCAN_TARGET_NORSP"*)
				SCAN_TARGET_NORSP=`log_one_ant_switch_metric $line $SCAN_TARGET_NORSP scn 2`
				;;
			"AS_SWITCH_TOTAL"*)
				SWITCH_TOTAL=`log_one_ant_switch_metric $line $SWITCH_TOTAL swt 0`
				;;
			"AS_SWITCH_BTBUSY"*)
				SWITCH_BTBUSY=`log_one_ant_switch_metric $line $SWITCH_BTBUSY swt 1`
				;;
			"AS_SWITCH_TIMEOUT"*)
				SWITCH_TIMEOUT=`log_one_ant_switch_metric $line $SWITCH_TIMEOUT swt 2`
				;;
			"AS_SWITCH_WRONGANT"*)
				SWITCH_WRONGANT=`log_one_ant_switch_metric $line $SWITCH_WRONGANT swt 3`
				;;
			"AS_SWITCH_OTHER"*)
				SWITCH_OTHER=`log_one_ant_switch_metric $line $SWITCH_OTHER swt 4`
				;;
			*)
				;;
		esac
	done

	unset IFS
}

function log_each_key_fw_ant_switch_metrics
{
	local metric_key=$1
	local metadata_info=$2
	local metadata_arr metadata_arr_len count metadata metadata1

	OLD_IFS="$IFS"
	IFS=' '
	metadata_info=${metadata_info#*:}
	metadata_arr=($metadata_info)
	metadata_arr_len=${#metadata_arr[@]}
	IFS="$OLD_IFS"
	if [ $metadata_arr_len -ne $FW_ANT_SWITCH_TOTAL_METADATA_MULTI_METADAT1_NUM ]; then
		return
	fi

	index=0
	while(( $index<$FW_ANT_SWITCH_TOTAL_METADATA_MULTI_METADAT1_NUM )); do
		count=${metadata_arr[$index]}
		if [ $count -gt 0 ]; then
			metadata=`expr $index / $FW_ANT_SWITCH_METADATA_NUM`
			metadata1=`expr $index % $FW_ANT_SWITCH_METADATA_NUM`
			if [ $metadata -lt $FW_ANT_SWITCH_METADATA_NUM -a \
				$metadata1 -lt $FW_ANT_SWITCH_METADATA1_NUM ]; then
				log_wifi_kdm_metric fw_ant_switch $metric_key $count $metadata $metadata1
			fi
		fi
		let "index++"
	done
}

# Antenna switch triggerred by wifi firmware, currently it's used on Onyx
function log_kdm_fw_ant_switch_metrics
{
	IFS=$'\t\n'
	STAT=($(IWPRIV_DRV "get_fw_ant_switch_metrics"))

	#Operation: AntSwitch
	#Type: counter
	#Key, denotes the combinations of charging, device mobility and screen state, enumeration of them are:
	#0: on charging
	#1: on battery + device still + screen off
	#2: on battery + device still + screen on
	#3: on battery + device moving + screen off
	#4: on battery + device moving + screen on

	#Metadata, denotes the antenna switch result
	#0: not switched, main antenna is being used
	#1: not switched, aux antenna is being used
	#2: switched, main antenna is being used
	#3: switched, aux antenna is being used

	#Metadata1, RSSI difference of the two antennas
	#0: <= 5db
	#1: <= 10db
	#2: <= 15db
	#3: > 15db

	#iwpriv cmd return format as below:
	#KEY_1:3 0 0 0 1 0 0 0 18 0 0 0 20 0 0 0
	#KEY_3:0 5 0 0 1 0 0 0 10 0 0 0 50 0 0 0
	#This means only KEY_1 and KEY_3 exist, and take KEY_1 as an example, after KEY_1,
	#it's an array[16], the array index is the combination of metadata and metadata1,
	#such as array[0]=3 means metadata=0 and metadata1=0, the count value is 3.

	for line in ${STAT[@]}; do
		case $line in
			"KEY_0"*)
				log_each_key_fw_ant_switch_metrics 0 $line
				;;
			"KEY_1"*)
				log_each_key_fw_ant_switch_metrics 1 $line
				;;
			"KEY_2"*)
				log_each_key_fw_ant_switch_metrics 2 $line
				;;
			"KEY_3"*)
				log_each_key_fw_ant_switch_metrics 3 $line
				;;
			"KEY_4"*)
				log_each_key_fw_ant_switch_metrics 4 $line
				;;
			*)
				;;
		esac
	done

	unset IFS
}

function log_wifi_kdm_metric
{
	case $1 in
		chip_active)
			# $2: metric key, valid values:
			#     0: Wi-Fi HW is active
			#     1: Wi-Fi FW is active
			#     2: Wi-Fi is function on
			# $3: the duration in ms
			# $4: screen status, valid values:
			#     0: Screen is off
			#     1: Screen is on
			# $5: the reason, valid values:
			#     FW: The low power is controlled by firmware
			#     DRV: The low power is controlled by driver
			if [ $# -eq 5 ]; then
				LOG_TO_KDM "wifiKDM:conn-soc-active:fgtracking=false;DV;1,key=$2;DV;1,Timer=$3;TI;1,unit=ms;DV;1,metadata=!{\"d\"#{\"metadata\"#\"$4\"$\"metadata1\"#\"$5\"}};DV;1:HI"
			else
				echo "Error in logging conn-soc-active, requires 5 parameters, but only receives $# parameters"
			fi
			;;
		host_wakeup)
			# $2: metric key, valid values: wifi, app
			# $3: wake up counter value
			if [ $# -eq 3 ]; then
				LOG_TO_KDM "wifiKDM:wifi-num-wakeup-host:fgtracking=false;DV;1,key=$2;DV;1,Counter=$3;CT;1,unit=count;DV;1:NR"
			else
				echo "Error in logging wifi-num-wakeup-host, requires 3 parameters, but only receives $# parameters"
			fi
			;;
		ant_switch)
			# $2: metrics key, which denotes the antenna switch actions, such as orientation total, swtich total, etc.
			# $3: metric counter, the counter corresponding the key
			# $4: metadata, denotes the result of action
			# $5: metadata1, denotes the reason for the result of some actions
			if [ $# -eq 4 ]; then
				LOG_TO_KDM "wifiKDM:AntSwitch:fgtracking=false;DV;1,key=$2;DV;1,Counter=$3;CT;1,unit=count;DV;1,metadata=!{\"d\"#{\"metadata\"#\"$4\"}};DV;1:NR"
			elif [ $# -eq 5 ]; then
				LOG_TO_KDM "wifiKDM:AntSwitch:fgtracking=false;DV;1,key=$2;DV;1,Counter=$3;CT;1,unit=count;DV;1,metadata=!{\"d\"#{\"metadata\"#\"$4\"$\"metadata1\"#\"$5\"}};DV;1:NR"
			else
				echo "Error in logging AntSwitch, requires 4 or 5 parameters, but only receives $# parameters"
			fi
			;;
		fw_ant_switch)
			# $2: metric key, which denotes the device status, the status is the combination of charging, moving and screen status
			# $3: metric counter, the counter corresponding the key
			# $4: metadata, denotes the result of action
			# $5: metadata1, denotes the RSSI difference of the two antennas
			if [ $# -eq 5 ]; then
				LOG_TO_KDM "wifiKDM:AntSwitch:fgtracking=false;DV;1,key=$2;DV;1,Counter=$3;CT;1,unit=count;DV;1,metadata=!{\"d\"#{\"metadata\"#\"$4\"$\"metadata1\"#\"$5\"}};DV;1:NR"
			else
				echo "Error in logging AntSwitch, requires 5 parameters, but only receives $# parameters"
			fi
			;;
		wifi_band)
			# $2: metrics key: The channel number
			# $3: metadata: Bandwidth, such as 20Mhz, 40Mhz, 80Mhz, 160Mhz
			# $4: metadata1: 802.11 Phy Mode, such as 11a/b/g/n/ac
			if [ $# -eq 4 ]; then
				LOG_TO_KDM "wifiKDM:Band:fgtracking=false;DV;1,Counter=1;CT;1,unit=count;DV;1,metadata=!{\"d\"#{\"metadata1\"#\"$4\"$\"metadata\"#\"$3\"$\"key\"#\"$2\"}};DV;1:NR"
			elif [ $# -eq 3 ]; then
				LOG_TO_KDM "wifiKDM:Band:fgtracking=false;DV;1,Counter=1;CT;1,unit=count;DV;1,metadata=!{\"d\"#{\"metadata\"#\"$3\"$\"key\"#\"$2\"}};DV;1:NR"
			else
				echo "Error in logging Band, requires 4 parameters, but only receives $# parameters"
			fi
			;;
		*)
			echo "Unknown KDM metrics type $1"
			# the default case
			;;
	esac
}

# Retrieve attr value with key from a oneline string. The value should be enclosed by [].
function get_attr_value
{
	local ori_str=$1
	local attr_key=$2

	if [ "$attr_key" != "" ] && [[ "$ori_str" = *"$attr_key"* ]]; then
		ori_str=${ori_str#*${attr_key}[}
		echo ${ori_str%%]*}
	else
		echo 0
	fi
}

function log_kdm_wifi_power
{
	local fw_active_stat=`IWPRIV_DRV "fw_active_statistics get"`
	local fw_active_ms=`get_attr_value "$fw_active_stat" TimeDuringScreenOff`
	local hw_active_ms=`get_attr_value "$fw_active_stat" HwTimeDuringScreenOff`
	local wifi_on_stat=`IWPRIV_DRV "wifi_on_time_statistics get"`
	local screen_off_ms=`get_attr_value "$wifi_on_stat" TimeDuringScreenOff`
	local mgmt_wakeup=$((ABNORMALINT+SOFTINT+TXINT+RXEVENTINT+RXMGMTINT+RXOTHERINT))
	local data_wakeup=$RXDATAINT
	local unsigned_int_max=4294967295

	if [ $fw_active_ms -lt $LAST_FW_ACTIVE_MS ]; then
		# The value in driver is cumulative, not impacted by wifi reset. We reach here to handle the case of overflow.
		fw_active_ms=$((unsigned_int_max-LAST_FW_ACTIVE_MS+fw_active_ms))
		LAST_FW_ACTIVE_MS=0
	fi
	if [ $fw_active_ms -gt $LAST_FW_ACTIVE_MS ]; then
		log_wifi_kdm_metric chip_active 1 $((fw_active_ms-LAST_FW_ACTIVE_MS)) 0 FW # firmware active duration while screen off and FW own
		LAST_FW_ACTIVE_MS=$fw_active_ms
	fi

	if [ $hw_active_ms -lt $LAST_HW_ACTIVE_MS ]; then
		# The value in driver is cumulative, not impacted by wifi reset. We reach here to handle the case of overflow.
		hw_active_ms=$((unsigned_int_max-LAST_HW_ACTIVE_MS+hw_active_ms))
		LAST_HW_ACTIVE_MS=0 # Reset last value to 0 to report current value directly.
	fi
	if [ $hw_active_ms -gt $LAST_HW_ACTIVE_MS ]; then
		log_wifi_kdm_metric chip_active 0 $((hw_active_ms-LAST_HW_ACTIVE_MS)) 0 FW # hardware active duration while screen off and FW own
		LAST_HW_ACTIVE_MS=$hw_active_ms
	fi

	if [ $mgmt_wakeup -lt $LAST_MGMT_WAKEUP ]; then
		# The value in driver is cumulative, not impacted by wifi reset. We reach here to handle the case of overflow.
		mgmt_wakeup=$((unsigned_int_max-LAST_MGMT_WAKEUP+mgmt_wakeup))
		LAST_MGMT_WAKEUP=0 # Reset last value to 0 to report current value directly.
	fi
	if [ $mgmt_wakeup -gt $LAST_MGMT_WAKEUP ]; then
		log_wifi_kdm_metric host_wakeup mgmt $((mgmt_wakeup-LAST_MGMT_WAKEUP)) # Wifi wakes up host due to event/mgmt frames, the wake-up statistic data are collected in iwpriv_int_stat_tokens
		LAST_MGMT_WAKEUP=$mgmt_wakeup
	fi

	if [ $data_wakeup -lt $LAST_DATA_WAKEUP ]; then
		# The value in driver is cumulative, not impacted by wifi reset. We reach here to handle the case of overflow.
		data_wakeup=$((unsigned_int_max-LAST_DATA_WAKEUP+data_wakeup))
		LAST_DATA_WAKEUP=0 # Reset last value to 0 to report current value directly.
	fi
	if [ $data_wakeup -gt $LAST_DATA_WAKEUP ]; then
		log_wifi_kdm_metric host_wakeup app $((data_wakeup-LAST_DATA_WAKEUP)) # Wifi wakes up host due to receiving APP's data
		LAST_DATA_WAKEUP=$data_wakeup
	fi

	if [ $screen_off_ms -lt $LAST_WIFI_ON_SCR_OFF ]; then
		# The value in driver is cumulative, not impacted by wifi reset. We reach here to handle the case of overflow.
		screen_off_ms=$((unsigned_int_max-LAST_WIFI_ON_SCR_OFF+screen_off_ms))
		LAST_WIFI_ON_SCR_OFF=0 # Reset last value to 0 to report current value directly.
	fi
	if [ $screen_off_ms -gt $LAST_WIFI_ON_SCR_OFF ]; then
		log_wifi_kdm_metric chip_active 2 $((screen_off_ms-LAST_WIFI_ON_SCR_OFF)) 0 DRV # Wifi on duration during wifi off
		LAST_WIFI_ON_SCR_OFF=$screen_off_ms
	fi
}

function log_kdm_band
{
	local wifimode current_date

	case $SUPPORT_BAND in
	1)
		;;
	0)
		return
		;;
	*)
		if [[ "`IWPRIV`" != *"get_bandwidth"* ]]; then
			echo "iwpriv command get_bandwidth is not supported on this device"
			SUPPORT_BAND=0
			return
		else
			SUPPORT_BAND=1
		fi
		;;
	esac

	wifimode=${PHYMODE#802.}

	if [ "$wifimode" = "11g" ] && [ $CHANNEL -gt 14 ]; then
		wifimode=""
	fi
	current_date=`date -u +%j` # The day of year (001-366), in UTC
	bandwidth=`IWPRIV get_bandwidth`
	bandwidth=${bandwidth#*bandwidth = }
	# Report Band metric if anything changed or every day once even no change.
	if [ "$CHANNEL" != "$LAST_CHANNEL" ] || [ "$bandwidth" != "$LAST_BANDWIDTH" ] \
		|| [ "$LAST_WIFIMODE" != "$wifimode" ] || [ $current_date -gt $LAST_BANDWIDTH_DATE ]; then
		log_wifi_kdm_metric wifi_band $CHANNEL $bandwidth $wifimode
		LAST_CHANNEL=$CHANNEL
		LAST_BANDWIDTH=$bandwidth
		LAST_WIFIMODE=$wifimode
		LAST_BANDWIDTH_DATE=$current_date
	fi
}

function wifi_power_metrics_init
{
	LAST_HW_ACTIVE_MS=0
	LAST_FW_ACTIVE_MS=0
	LAST_MGMT_WAKEUP=0
	LAST_DATA_WAKEUP=0
	LAST_WIFI_ON_SCR_OFF=0
}

function log_wifi_metrics
{
	log_metrics_rssi
	log_metrics_snr
	log_metrics_noise
	log_metrics_mcs
	log_metrics_phymode

	log_kdm_ant_switch_metrics
	log_kdm_wifi_power
	log_kdm_fw_ant_switch_metrics
}

function log_logcat
{
	logStr="$LOGNAME:rssi=$maxRssi;noise=$maxNoise;channel=$CHANNEL;"
	logStr=$logStr"txframes=$TXFRAMES;txretries=$TXRETRIES;txper=$TXPER;txnoack=$TXRETRYNOACK;txplr=$TXPLR;"
	logStr=$logStr"rxframes=$RXFRAMES;rxcrc=$RXCRC;rxper=$RXPER;rxdrop=$RXDROP;rxdup=$RXDUP;"
	logStr=$logStr"falsecca=$TOTALCCA;onesecfalsecca=$ONECCA;"
	logStr=$logStr"phymode=$PHYMODE;phyrate=$PHYRATE;lasttxrate=$LASTTXRATE;lastrxrate=$LASTRXRATE;"
	logStr=$logStr"abnormal_int=$ABNORMALINT;soft_int=$SOFTINT;tx_int=$TXINT;rxdata_int=$RXDATAINT;"
	logStr=$logStr"rxevent_int=$RXEVENTINT;rxmgmt_int=$RXMGMTINT;rxother_int=$RXOTHERINT;"
	LOG_TO_MAIN $logStr

	log_maxmin_signals
}

# Log the maximum and minimum values regarding signal quality
function log_maxmin_signals
{
	if [[ ! "$PREVIOUS_CHANNEL" ]] ; then
		PREVIOUS_CHANNEL=$CHANNEL
	elif [[ $PREVIOUS_CHANNEL != $CHANNEL ]] ; then
		PREVIOUS_CHANNEL=$CHANNEL
		MAX_RSSI=''
		MIN_RSSI=''
		MAX_NOISE=''
		MIN_NOISE=''
	fi

	if [[ ! "$MAX_RSSI" && ! "$MIN_RSSI" && ! "$maxRssi" -eq 0 ]] ; then
		MAX_RSSI=$maxRssi
		MIN_RSSI=$maxRssi
	fi

	if [[ ! "$MAX_NOISE" && ! "$MIN_NOISE" && ! "$maxNoise" -eq 0 ]] ; then
		MAX_NOISE=$maxNoise
		MIN_NOISE=$maxNoise
	fi

	if [ ! $maxRssi -eq 0 ] ; then
		if [ $maxRssi -gt $MAX_RSSI ] ; then
			MAX_RSSI=$maxRssi
		fi

		if [ $maxRssi -lt $MIN_RSSI ] ; then
			MIN_RSSI=$maxRssi
		fi
	fi

	if [ ! $maxNoise -eq 0 ] ; then
		if [ $maxNoise -gt $MAX_NOISE ] ; then
			MAX_NOISE=$maxNoise
		fi

		if [ $maxNoise -lt $MIN_NOISE ] ; then
			MIN_NOISE=$maxNoise
		fi
	fi

	logStr="$LOGNAME:max_rssi=$MAX_RSSI;min_rssi=$MIN_RSSI;max_noise=$MAX_NOISE;min_noise=$MIN_NOISE;"
	LOG_TO_MAIN $logStr
}

function clear_stale_stats
{
	RSSI=""
	SNRA=""
	SNRB=""
	NOISEA=""
	NOISEB=
	LASTRXRATE=""
	HADLASTRXRATE=0
	HADLASTTXRATE=0
	HADPHYRATE=0
	HADRSSI=0
	PHYMODE="unknown"
}

function ant_switch_metric_count_init
{
	ORIENTATION_TOTAL=0
	ORIENTATION_REMAIN=0
	ORIENTATION_DISCONNECT=0
	ORIENTATION_SCAN=0
	ORIENTATION_STRONG=0
	ORIENTATION_SUCCESS=0
	ORIENTATION_SWITCHBACK=0
	SCAN_TOTAL=0
	SCAN_CURRENT_NORSP=0
	SCAN_TARGET_NORSP=0
	SWITCH_BTBUSY=0
	SWITCH_TIMEOUT=0
	SWITCH_WRONGANT=0
	SWITCH_OTHER=0
	SWITCH_TOTAL=0
}

function last_value_init
{
	LAST_CHANNEL=255
	LAST_BANDWIDTH=0
	LAST_BANDWIDTH_DATE=0
	LAST_WIFIMODE="unknown"
}

function run ()
{
	local conn_status

	set_wlan_interface

	# Issue iwpriv command only if Wi-Fi is on
	if [ -n "$WLAN_INTERFACE" ]; then
		conn_status=`iwpriv_conn_status`
		# All these functions take effect when Wi-Fi connected
		if [ "$conn_status" = "Connected" ]; then
			iwpriv_show_channel
			iwpriv_stat_tokens
			iwpriv_int_stat_tokens
			get_max_signal_stats
			log_logcat
			log_kdm_band # Check band information every 2 minutes, and report it upon change.
		fi
		if [ $currentLoop -eq $LOOPSTILMETRICS ] ; then
			if [ "$conn_status" = "Connected" ]; then
				log_wifi_metrics
			fi
			log_connstatus_metrics "$conn_status"
			currentLoop=0
		else
			((currentLoop++))
		fi
		clear_stale_stats
	fi
}

# Initialize parameters before main loop.
wifi_power_metrics_init
ant_switch_metric_count_init
clear_stale_stats
last_value_init

# Run the collection repeatedly, pushing all output through to the metrics log.
while true ; do
	run
	sleep $DELAY
done
