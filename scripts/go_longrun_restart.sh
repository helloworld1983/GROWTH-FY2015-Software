#!/bin/bash

# GRWOTH-FY2015
# Long run start up script

PI_HOME=/home/pi
DATA_DIR=/home/pi/work/observation
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

# detector-dependent long-run configuration file
if [ ! -f ${DATA_DIR}/configuration_without_wf.yaml ]; then
	echo "Error: $/home/pi/work/observation/configuration_without_wf.yaml not found."
	echo "        Create a detector-dependent long-run configuration file."
	exit -1
fi

# rsync script
#if [ ! -f ${HDD}/go_sync_fy2015.sh ]; then
#	echo "Error: ${HDD}/go_sync_fy2015.sh not found."
#	echo "       Copy GRWOTH-FY2015-Software/scripts/go_sync_fy2015.sh or create new rsync script."
#	exit -1
#fi

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
$PI_HOME/work/install/bin/go_loop_daq_hongo.sh ${DATA_DIR}/configuration_without_wf.yaml &

#---------------------------------------------
#echo "Start rsyncing"
#$PI_HOME/work/install/bin/go_sync_hongo.sh &

#---------------------------------------------
#if [ -f $PI_HOME/tell_ip.sh ]; then
#	echo "Start IP address notification"
#	nohup bash $PI_HOME/tell_ip.sh &
#fi
