#!/bin/bash

exp=1800

#check HDD
if [ ! -d /media/hdd/growth ]; then
	echo "Error: Mount USB HDD as /media/hdd"
	echo "       Then, create /media/hdd/growth/"
	exit -1
fi

#check growth_config.yaml
if [ ! -f $HOME/growth_config.yaml ]; then
	echo "Error: Execute 'growth_config -g' before running this script."
	exit -1
fi

#check detector ID
detectorID=`growth_config --id`
if [ _$detectorID = _ ]; then
	echo "Error: Check the content of ~/growth_config.yaml"
	echo "       It should contain detectorID entry."
	exit -1
fi

#check detector folder
if [ ! -f /media/hdd/growth/${detectorID} ]; then
	mkdir -p /media/hdd/growth/${detectorID}
	if [ ! -f /media/hdd/growth/${detectorID} ]; then
		echo "Error: Could not create /media/hdd/growth/${detectorID}"
		echo "       Run this script as superuser."
		exit -1
	fi
fi

#check argument
if [ _$1 = _ ]; then
	echo "Provide configuration file to be used for this long-run measurement."
	exit -1
fi

configurationFile=`ruby -e "puts File::expand_path('$1')"`

pushd /media/hdd/growth/$detectorID

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
	~pi/work/install/bin/growth_fy2015_read_hk $exp &> hk/hk_$date.data

#exit from the output folder
popd

done

popd
