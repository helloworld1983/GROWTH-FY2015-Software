#!/bin/bash

temp=`growth_fy2015_read_hk 1 | awk '{print $5}'`
processADC=`pgrep growth_fy2015_a`
processHK=`pgrep growth_fy2015_r`
decision=`tempDecision.rb ${temp} ${processADC}`
startDecision=`startDecision.rb ${processHK}`
echo $decision
echo $startDecision
if [ $decision = "start" ]; then
    if [ $startDecision = "start" ]; then
	echo "longrun start"
	go_longrun_alone.sh
    elif [ $startDecision = "restart" ]; then
	echo "longrun restart"
	go_longrun_alone_restart.sh
    fi
elif [ $decision = "stop" ]; then
    echo "longrun stop"
    kill `pgrep go_loop_daq_alo`
    sleep 3s
    kill `pgrep growth_fy2015_a`
    sleep 3s
    fpga_off
    sleep 3s
    hv_off
fi
