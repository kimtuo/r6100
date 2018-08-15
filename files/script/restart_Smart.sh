
pids=$(ps | grep smart | grep -v grep | awk '{print $1}')

for p in $(echo $pids)
do
    kill -9 $pids
done
rm  /tmp/read_log_pid /tmp/simple_tcppng_pid /tmp/deep_tcppng_pid


function check_iptable(){
    LOG=$(iptables -L | grep LOG | wc -l)
    if [ $LOG -lt 1 ]; then
        echo "add iptable rule" >> /tmp/smart.log
        iptables -A forwarding_lan_rule -p tcp -m conntrack --ctstate NEW -m limit --limit 30/sec -j LOG --log-prefix "NEW Conn "
    fi
}

function clear_tcpping(){
    pids=$(ps | grep "tcpping -c" | grep -v grep | awk '{print $1}')
    echo "kill $pids" >> /tmp/smart.log
    for p in $(echo $pids)
    do
        kill -9 $pids
    done
}

check_iptable
clear_tcpping

touch /script/smart_route

if [ "$1" != "stop" ]; then
    bash /script/smart_deep_ping.sh &
    bash /script/smart_read_log.sh &
    bash /script/smart_simple_tcpping.sh &
fi
