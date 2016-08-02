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

#---------------------------------------------
echo "Start HK recording"
$PI_HOME/work/install/bin/go_loop_hk_alone.sh &
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
$PI_HOME/work/install/bin/go_loop_daq_alone.sh ${DATA_DIR}/configuration_without_wf.yaml &

#---------------------------------------------
#echo "Start rsyncing"
#$PI_HOME/work/install/bin/go_sync_alone.sh &

#---------------------------------------------
if [ -f $PI_HOME/tell_temp_m2x.sh ]; then
	echo "Starting M2X script (temperature)"
	nohup bash $PI_HOME/tell_temp_m2x.sh &
fi

#---------------------------------------------
if [ -f $PI_HOME/tell_size_m2x.sh ]; then
	echo "Starting M2X script (file size)"
	nohup bash $PI_HOME/tell_size_m2x.sh &
fi
