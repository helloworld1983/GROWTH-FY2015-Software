#!/bin/bash

exp=1800
PIHOME="/home/pi"
DATADIR="/home/pi/work/observation"
BINDIR="${PIHOME}/work/install/bin"


#check growth_config.yaml
if [ ! -f $PIHOME/growth_config.yaml ]; then
	echo "Error: Execute 'growth_config -g' before running this script."
	exit -1
fi

#check detector ID
detectorID=`ruby ${BINDIR}/growth_config --id`
if [ _$detectorID = _ ]; then
	echo "Error: Check the content of ${PIHOME}/growth_config.yaml"
	echo "       It should contain detectorID entry."
	exit -1
fi

#check detector folder
if [ ! -d ${DATADIR}/${detectorID} ]; then
	mkdir -p ${DATADIR}/${detectorID}
	if [ ! -d ${DATADIR}/${detectorID} ]; then
		echo "Error: Could not create ${DATADIR}/${detectorID}"
		echo "       Run this script as superuser."
		exit -1
	fi
fi

pushd ${DATADIR}/$detectorID

while [ 1 = 1 ]; do

echo "Current dir: `pwd`"
date=`date +"%Y%m%d_%H%M%S"`
echo "Start $date"

dir=`date +"%Y%m"`
echo "Output directory: $dir"

if [ ! -d $dir ]; then
	mkdir $dir
fi

#enter the output folder
pushd $dir

	#create hk folder if necessary
	if [ ! -d hk ]; then
		mkdir hk
	fi

	#execute DAQ software
	${BINDIR}/growth_fy2015_read_hk $exp &> hk/hk_$date.data

#exit from the output folder
popd

done

popd
