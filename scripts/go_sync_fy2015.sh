echo "Sync..."
while [ 1 = 1 ]; do
	date +"%H%M%D"
	rsync -auv growth/data/growth-fy2015* yuasa@galileo.phys.s.u-tokyo.ac.jp:work/growth/data/
	echo "Sleep 1800sec"
	sleep 300
done
