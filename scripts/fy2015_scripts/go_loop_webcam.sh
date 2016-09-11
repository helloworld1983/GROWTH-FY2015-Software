#!/bin/bash

HDD=/media/hdd
detectorID=`growth_config -i`
if [ _$detectorID = _ ]; then
	echo "Error: execute 'growth_config -g' before running this script."
	exit -1
fi

while [ 1 = 1 ]; do
	webcamDir=$HDD/growth/data/${detectorID}/`date '+%Y%m'`/webcam
	if [ ! -d ${webcamDir} ]; then
		sudo mkdir -p ${webcamDir}
	fi
	pushd ${webcamDir}
		sudo fswebcam -S 30 --resolution 1200x1000 `date "+%Y%m%d_%H%M%S.jpg"`
	popd
	sleepTime=`ruby -e "hour=Time.now.hour;if(hour>17 or hour<6)then puts 1800; else puts 300;end"`
	echo "Sleeping ${sleepTime}sec"
	sleep $sleepTime
done
