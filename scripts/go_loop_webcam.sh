#!/bin/bash

HDD=/media/hdd
detectorID=`growth_config -i`
if [ _$detectorID = _ ]; then
	echo "Error: execute 'growth_config -g' before running this script."
	exit -1
fi

while [ 1 = 1 ]; do
	webcamDir=$HDD/growth/data/${detectorID}/`date '%Y%m'`/webcam
	if [ ! -d ${webcamDir} ]; then
		mkdir -p ${webcamDir}
	fi
	pushd ${webcamDir}
		fswebcam --resolution 3000x2000 `date "+%Y%m%d_%H%M%S.jpg"`
	popd
	sleep 600
done
