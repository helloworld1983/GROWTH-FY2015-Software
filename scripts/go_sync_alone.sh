echo "Sync..."
while [ 1 = 1 ]; do
    detectorID=`growth_config -i`
    PI_HOME=/home/pi
    date +"%H%M%D"
    dataFolder=`date +%Y%m`
    rsync -auv $PI_HOME/work/observation/${detectorID}/${dataFolder}/*.fits galileo:work/growth/data/${detectorID}/${dataFolder}/
    rsync -auv $PI_HOME/work/observation/${detectorID}/${dataFolder}/hk galileo:work/growth/data/${detectorID}/${dataFolder}/
    echo "Sleep 3600sec"
    sleep 3600
done
