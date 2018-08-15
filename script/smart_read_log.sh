#---------------------------------
#
#   read_log.sh V0.1
#              Kim 20180814
#---------------------------------


run_log="/tmp/read.log"

function read_log(){
    syslog="/tmp/syslog"
    tmp_log="/tmp/tmplog"
    tmp_record="/tmp/tmprecord"
    
    >$tmp_record
    touch $tmp_log
    touch $syslog

    wan_interface=$(ifstatus wan | grep l3_device | awk -F\" '{print $4}')
    vpn_interface="vpn_l2"  #

    threshold=50  # 50 ms

    grep 'NEW Conn' $syslog > $tmp_log  #only new conn log
    logcount=$(cat $tmp_log | wc -l )
    echo  "get $logcount lines log" >> $run_log
    >$syslog  #truncate syslog

    docount=0

    cat $tmp_log | while read line
    do
        docount=$( expr $docount + 1 )
        echo  "check $docount ......" >> $run_log
        myline=$(echo $line | awk -F 'NEW Conn' '{print $2}')
        out_int=$(echo $myline | awk '{print $2}'| awk -F= '{print $2}')
        src=$(echo $myline | awk '{print $4}'| awk -F= '{print $2}')
        dst=$(echo $myline | awk '{print $5}'| awk -F= '{print $2}')
        proto=$(echo $myline | awk '{print $12}'| awk -F= '{print $2}')
        port=$(echo $myline | awk '{print $14}'| awk -F= '{print $2}')
        echo $out_int $src $dst $proto $port >> $run_log
        if_test=$(grep $dst $tmp_record | wc -l )
        if [ $if_test -eq 0 ] && [ "$proto" == "TCP" ] ;then
            echo $out_int $src $dst $proto $port >> $tmp_record
        fi
    done
}

#main loop---

if [ ! -f "/tmp/read_log_pid" ]; then
    touch /tmp/read_log_pid
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
        read_log
        echo "----------------------" >> $run_log
        sleep 5
    done
    rm /tmp/read_log_pid
fi