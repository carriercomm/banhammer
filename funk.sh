#!/bin/bash
if [ $# -eq 1 ]; then
   HOST=$1
else
   echo "Usage: $0 host"
   exit 1
fi

for IP in $(tail -n 10000 /var/log/apache2/$HOST.access.log | grep -v $HOST | grep -v \"-\" | awk '{print $1}' | sort | uniq)
do
    if iptables --list -n | grep DROP | awk '{print $4}' | grep -q "$IP"
    then
        true
    else
        echo "banning $IP"
        iptables -A INPUT -s $IP -j DROP
        sleep 1
    fi
done

