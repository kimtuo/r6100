#---------------------------------
#
#   deep_ping.sh V0.1
#              Kim 20180814
#---------------------------------

run_log="/tmp/deep_run.log"
deep_list="/tmp/deep_ip_list"

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

function deep_ping(){

    deeping_file="/tmp/deeping_file"
    cat $deep_list > $deeping_file
    >$deep_list

    wan_interface=$(ifstatus wan | grep l3_device | awk -F\" '{print $4}')
    vpn_interface="vpn_l2"  #

    if [ $(cat $deeping_file | wc -l ) -gt 0  ]; then

        cat $deeping_file | while read line
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
                wan_ping=$(smart_ping $dst $wan_interface 10 $port)
            else
                wan_ping=1000
            fi

            if [ $vpn_status -gt 0 ] && [ $vpn_ip -gt 0 ]; then
                vpn_ping=$(smart_ping $dst $vpn_interface 10 $port)
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

            if [ "$diff" == "WAN" ]; then
                #wan is less then vpn 50ms
                if [ "$out_int" == $vpn_interface ]; then #if now is from vpn 
                    add_route $dst wan
                    
                fi               
            elif [ "$diff" == "VPN" ]; then
                #wan is greater then vpn 50ms
                if [ "$out_int" == $wan_interface ]; then #if now if from wan
                    add_route $dst vpn

                fi
            fi    

        done
    fi
}

#main loop---

if [ ! -f "/tmp/deep_tcppng" ]; then
    touch /tmp/deep_tcppng_pid
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
        deep_ping
        echo "----------------------" >> $run_log
        sleep 5
    done
    rm /tmp/deep_tcppng_pid
fi