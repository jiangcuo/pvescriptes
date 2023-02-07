#!/bin/bash
pcislot="0000:01:00.0"
if [ $1 = "pre-start" ];then
    echo "reset vga"
    echo $pcislot > /sys/bus/pci/drivers/vfio-pci/unbind
    echo 1 >/sys/bus/pci/devices/$pcislot/remove 
    echo 1 >/sys/bus/pci/rescan 
fi

    