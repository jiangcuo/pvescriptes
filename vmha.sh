#!/bin/bash
host="10.13.14.54"
vmid="122"
logfile="/var/log/vmha-$vmid.log"
vmstatus=`qm status $vmid|awk '{print $2}'`
echo "##############started####################" >> $logfile
#use ping to check
ping -c2 -i0.3 -W1 $host &>/dev/null
if [ $? == 0 ];then
    echo "`date` $host is on" >> $logfile
    # check backup vm status
    if [ $vmstatus == "stopped" ];then
        echo "`date` backupvm $vmid is off , do nothing " >> $logfile
    else 
        echo "`date` backupvm is on, do nothing" >> $logfile
        qm stop $vmid
    fi  
else
    #if 
    echo "`date` $host is off" >> $logfile
    if [ $vmstatus == "stopped" ];then
        echo "`date` backupvm $vmid is off , turn on" >> $logfile
        qm start $vmid
    else 
        echo "`date` backupvm is on, do nothing" >> $logfile
    fi  
fi
echo "##############End###################" >> $logfile