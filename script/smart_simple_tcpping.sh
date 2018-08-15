#---------------------------------
#
#   simple_tcpping.sh V0.1
#              Kim 20180814
#---------------------------------

run_log="/tmp/s_tcpping.log"
deep_list="/tmp/deep_ip_list"

#$1=host $2=interface $3=count $4=port
function smart_ping (){

    count="3"
    interface="eth0"
    port="80"

    if [ $1 ]
    then
        host=$1

        if [ $2 ]; then
            interface=$2
        fi

        if [ $3 ];then
            count=$3
        fi

        if [ $4 ];then
            port=$4
        fi

        ping_result=$(tcpping -c $count  -I  $interface -p $port $host | grep round-trip | awk '{print $4}')

        echo "tcpping -c $count  -I  $interface -p $port $host" >> $run_log

        echo $ping_result | awk -F/ '{print $2}' | awk '{print int($0)}'
    fi
}

function ip_to_network() {
    if [ $1 ]; then
        ip=$1
        # echo $ip
        a=$(echo $ip | awk -F\. '{print $1}')
        b=$(echo $ip | awk -F\. '{print $2}')
        c=$(echo $ip | awk -F\. '{print $3}')
        echo "$a.$b.$c.0/24"
    fi
}

function check_iptable(){
    LOG=$(iptables -L | grep LOG | wc -l)
    if [ $LOG -lt 1 ]; then
        echo "add iptable rule" >> $run_log
        iptables -A forwarding_lan_rule -p tcp -m conntrack --ctstate NEW -m limit --limit 30/sec -j LOG --log-prefix "NEW Conn "
    fi
}

function clear_tcpping(){
    pids=$(ps | grep "tcpping -c" | grep -v grep | awk '{print $1}')
    echo "kill $pids" >> $run_log
    for p in $(echo $pids)
    do
        kill -9 $pids
    done
}

function check_vpn_client(){
    line=$(top -n 1 | grep -A 1 PPID | grep vpnclient)
    if [ $(echo $line | wc -l ) -gt 1 ]; then    
        cpu=$(echo $line | awk  '{print $8}' | awk -F\% '{print $1}')
        if [ $cpu -gt 60 ]; then
            pid=$(echo $line | awk '{print $1}')
            echo "!!!!!!!!!!!!!!!!! cpu is upto $cpu , kill -9 $pid !!!!!!!!!!!!!!!!!!!" >> $run_log
            kill -9 $pid
            sleep 1 
            /usr/bin/vpnclient start
        fi
    fi
}

function calculate_diff(){
    wan_ping=$1
    vpn_ping=$2
    better="NONE"

    m=$(expr $wan_ping - $vpn_ping)
    n=${m/-/}

    echo "wan_ping is $wan_ping, vpn_ping is $vpn_ping, m is $m , n is $n " >> $run_log

    if [ $m -gt 0 ]; then
        #vpn is better
        if [ $n -gt $( expr $wan_ping / 3 ) ]; then
            better="VPN"
            echo "VPN is better " >> $run_log
        fi
    elif [ $m -lt 0 ];then
        #wan is better
        if [ $n -gt $( expr $vpn_ping / 3 ) ]; then
            better="WAN"
            echo "WAN is better " >> $run_log
        fi
    fi
    echo $better
}

function add_route(){
    dst=$1
    interface=$2

    network=$(ip_to_network $dst)
    net=$(echo $network | awk -F\/ '{print $1}')

    sed -i "/$net/d" /script/smart_route
    echo "ip rule add to $network table $interface pref 177" >> /script/smart_route   # add to /script/smart_route for restart 
    echo "ip rule add to $network table $interface pref 177" >> $run_log

    logger "ip rule del to $network pref 177"
    logger "ip rule add to $network table $interface pref 177"

    ip rule del to $network pref 177 
    ip rule add to $network table $interface pref 177  # switch to wan
}

function simple_ping(){

    tmp_record="/tmp/tmprecord"
    reading_file="/tmp/reading"

    wan_interface=$(ifstatus wan | grep l3_device | awk -F\" '{print $4}')
    vpn_interface="vpn_l2"  #

    cat $tmp_record > $reading_file
    >$tmp_record

    cat $reading_file | while read line
    do
        # $out_int $src $dst $proto $port 
        

        if [ ! "$line" ];then
                continue
        fi

        echo "----------New Line-----------------------" >> $run_log

        echo "$line" >> $run_log
        out_int=$(echo $line | awk '{print $1}')
        src=$(echo $line | awk '{print $2}')
        dst=$(echo $line | awk '{print $3}')
        proto=$(echo $line | awk '{print $4}')
        port=$(echo $line | awk '{print $5}')

        wan_status=$(ifstatus wan | grep "\"up\": true" | wc -l)
        vpn_status=$(ifstatus l2 | grep "\"up\": true"| wc -l)

        wan_ip=$(ifstatus wan | grep \"address\" | wc -l)
        vpn_ip=$(ifstatus l2 | grep \"address\" | wc -l)

        if [ $wan_status -gt 0 ] && [ $wan_ip -gt 0 ]; then
            wan_ping=$(smart_ping $dst $wan_interface 1 $port)
        else
            wan_ping=1000
        fi

        if [ $vpn_status -gt 0 ] && [ $vpn_ip -gt 0 ]; then
            vpn_ping=$(smart_ping $dst $vpn_interface 1 $port)
        else
            vpn_ping=1000
        fi
        
        if [ $wan_ping -eq 0 ]; then
            wan_ping=1000
        fi

        if [ $vpn_ping -eq 0 ]; then
            vpn_ping=1000
        fi

        # echo "wan_ping is $wan_ping" >> $run_log
        # echo "vpn_ping is $vpn_ping" >> $run_log

        diff=$(calculate_diff $wan_ping $vpn_ping)

        network=$(ip_to_network $dst)
        net=$(echo $network | awk -F\/ '{print $1}')

        is_in_smart_route=$(grep $network /script/smart_route | wc -l )
        echo "is_in_smart_route=$is_in_smart_route" >> $run_log

        if [ "$diff" == "WAN" ]; then
            #wan is less then vpn 50ms
            if [ "$out_int" == $vpn_interface ]; then #if now is from vpn 

                if [ $is_in_smart_route -ge 1 ]; then
                    echo $line  >> $deep_list
                    echo "send to deep check list" >> $run_log
                else
                    add_route $dst wan
                fi

            fi               
        elif [ "$diff" == "VPN" ]; then
            #wan is greater then vpn 50ms
            if [ "$out_int" == $wan_interface ]; then #if now if from wan

                if [ $is_in_smart_route -ge 1 ]; then
                    echo $line >> $deep_list
                    echo "send to deep check list" >> $run_log
                else
                    add_route $dst vpn
                fi
            fi
        fi    

    done
}

#main loop---

if [ ! -f "/tmp/simple_tcppng" ]; then
    touch /tmp/simple_tcppng_pid
    echo "----------------------" >> $run_log
    echo "New start.."> $run_log
    echo "----------------------" >> $run_log
    count=0
    
    while true
    do
        count=$( expr $count + 1 )
        echo "----------------------" >> $run_log
        echo "new loop $count.." >> $run_log
        echo "----------------------" >> $run_log
        simple_ping
        echo "----------------------" >> $run_log
        sleep 5
    done
    rm /tmp/simple_tcppng_pid
fi