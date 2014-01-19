#!/bin/bash
# author: ibarria0
if [ $# -eq 1 ]; then
   CONNLIMIT=$1
   LOGFILE=/var/log/apache2/*.access.log
   ERRORFILE=/var/log/apache2/*.error.log
   IGNORE='facebook|google|prensa|\.com\.pa|Googlebot|\:\:1|\=\=\>'
   COUNTRIES=/home/ubuntu/evil_countries
   BANS=bans.tmp
   SLEEP=2
   /usr/games/cowsay "starting banhammer"
else
   echo "Usage: $0 connection_limit"
   exit 1
fi

function ddos_rules {
	# Interface 0 incoming syn-flood protection
	/sbin/iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
#	/sbin/iptables -N syn_flood
#	/sbin/iptables -A INPUT -p tcp --syn -j syn_flood
#	/sbin/iptables -A syn_flood -m limit --limit 1/s --limit-burst 3 -j RETURN
#	/sbin/iptables -A syn_flood -j DROP
	#Limiting the incoming icmp ping request:
#	/sbin/iptables -A INPUT -p icmp -j DROP
#	/sbin/iptables -A OUTPUT -p icmp -j ACCEPT
}

function ban_ip {
	if $(geoiplookup $1 | grep -q -E "Panama")
	then
	    true
	else
	    kill_proc $1
	    if cat $BANS | grep -q "$1"
	    then
		true
	    else
		echo "banning $1"
		echo $1 >> $BANS
		iptables -A INPUT -w -s $1 -j DROP 
	    fi 
    fi
}

function ban_countries {
for CC in $(cat $COUNTRIES)
    do
	echo "banning $CC"	
	iptables -A INPUT -w -m geoip --src-cc $CC -j DROP
    done
}


function ban_offenders {
    for IP in $(cat $ERRORFILE | grep -v "access denied" | awk '{print $1}' | sort | uniq)
    do
        ban_ip $IP
    done
}

function kill_proc {
    for PID in $(netstat -ntup | grep "$1" | awk '{print $7}'| cut -d/ -f1 | grep -v "-" | sort | uniq )
    do
        if $(geoiplookup $1 | grep -q Panama)
        then
	    true
        else
            kill -9 $PID
	fi
    done
}

function ban_strange_requests {
	echo "banning strange requests"
	for IP in $(tail -n 10000 $LOGFILE | grep -v -E $IGNORE | awk '{print $1}' | sort | uniq)
	do
	    ban_ip $IP
	done
}

function load_old {
	echo "loading old bans"
	iptables -w --list -n | grep DROP | awk '{print $4}' > $BANS
}

function ban_loop {
	echo "entering ban loop"
	while true
	do
	    for IP in $(netstat -ntu | grep ":80" | awk '{print $5}'| cut -d: -f1 | sort | uniq -c | sort -n | grep -v -E '23\.21\.221\.8' | grep -v -E '127\.0\.0\.1|\=\=\>' | awk -v connlimit=$CONNLIMIT '{if ($1 >= connlimit) print $2;}')
	    do
		ban_ip $IP
	    done
	    sleep $SLEEP
	done
}

load_old
ddos_rules
ban_strange_requests
ban_loop
