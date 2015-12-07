#!/bin/bash

# GRWOTH-FY2015
# Long run start up script

PI_HOME=/home/pi
DEV_HDD=/dev/sda1
HDD=/media/hdd
sleepSec=5

#---------------------------------------------
echo "Initial wait ${sleepSec} sec"
sleep ${sleepSec}

#---------------------------------------------
echo "Get detectorID"
detectorID=`growth_config -i`
if [ _$detectorID = _ ]; then
	echo "Error: execute growth_config first."
	exit -1
fi
echo "detectorID = ${detectorID}"

#---------------------------------------------
echo "Mount USB HDD"
sudo mount ${DEV_HDD} ${HDD}

#---------------------------------------------
# check
#---------------------------------------------

# hdd mounted?
if [ ! -d ${HDD}/growth ]; then
	echo "Error: HDD was not properly mouned, or ${HDD}/growth/ folder not found."
	echo "       Check HDD availability as ${DEV_HDD} or otherwise change the path"
	echo "       in the long-run script."
	exit -1
fi

# detector-dependent long-run configuration file
if [ ! -f ${HDD}/growth/data/${detectorID}/configuration_without_wf.yaml ]; then
	echo "Error: ${HDD}/growth/data/${detectorID}/configuration_without_wf.yaml not found."
	echo "        Create a detector-dependent long-run configuration file."
	exit -1
fi

# rsync script
if [ ! -f ${HDD}/go_sync_fy2015.sh ]; then
	echo "Error: ${HDD}/go_sync_fy2015.sh not found."
	echo "       Copy GRWOTH-FY2015-Software/scripts/go_sync_fy2015.sh or create new rsync script."
	exit -1
fi

#---------------------------------------------
echo "Start HK recording"
nohup sudo $PI_HOME/work/install/bin/go_loop_hk.sh &
sleep 5

#---------------------------------------------
echo "Turn on FPGA and high voltage"
echo "FPGA On"
fpga_on
sleep 3
echo "HV On"
hv_on
sleep 3

#---------------------------------------------
echo "Start observation"
cd ${HDD}/growth/data/${detectorID}
nohup sudo $PI_HOME/work/install/bin/go_loop_daq.sh configuration_without_wf.yaml &

#---------------------------------------------
echo "Start rsyncing"
cd ${HDD}
nohup bash go_sync_fy2015.sh &

#---------------------------------------------
if [ -f $PI_HOME/tell_temp_m2x.sh ]; then
	echo "Starting M2X script"
	nohup bash $PI_HOME/tell_temp_m2x.sh &
fi

#---------------------------------------------
if [ -f $PI_HOME/tell_ip.sh ]; then
	echo "Start IP address notification"
	nohup bash $PI_HOME/tell_ip.sh &
fi