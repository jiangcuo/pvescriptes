#!/bin/bash
#if hostname=pve{1..5}
fig="07:22:97:BE:CD:B6:3B:B2:9C:2A:DF:B8:4F:16:7F:BD:F5:5B:EA:F9:C5:D8:28:09:6D:B6:32:D5:B2:71:8C:92"
cluster="10.13.14.51"
link0=`ip addr show vmbr0|grep  -v "inet6"|grep inet|awk '{print $2}'|cut -d "/" -f1`
link1=`ip addr show enp6s19|grep  -v "inet6"|grep inet|awk '{print $2}'|cut -d "/" -f1`
nodeid=`hostname|sed "s/pve//g"`
passwd="P@SSword"
pvesh create /cluster/config/join \
--password $passwd \
--hostname $cluster \
--fingerprint $fig \
--nodeid $nodeid \
--link0 $link0 \
--link1 $link1 