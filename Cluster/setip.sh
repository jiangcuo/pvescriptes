#!/bin/bash
#if vmbr0i(eth0)=10.13.14.254
#eth1=10.0.1.254
ipaddr=`ip addr show  vmbr0|grep  -v "inet6"|grep inet|awk '{print $2}'|sed "s/10.13.14./10.0.1./g"`
eth="enp6s19"
cat << EOF >> /etc/network/interfaces 
auto $eth
iface $eth inet static
        address $ipaddr
EOF
ifreload -a