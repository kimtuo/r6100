#!/bin/bash


function reset
{
    echo "-----reset-----"
    if [ -f /script/init ]
    then
        echo "find init"
        mac1=$(ifconfig eth0 | grep eth0 | awk '{print $5}' | sed -e 's/\:/-/g')
      
        /usr/libexec/softethervpn/vpnclient stop

        sed -i -e "s/00-AC-B0-9D-6A-01/$mac1/" /usr/libexec/softethervpn/vpn_client.config

        /usr/libexec/softethervpn/vpnclient start

        rm /script/init
    fi

}

function check_iprule
{
    echo "-----check_iprule-----"
    rule_count=$(ip rule | wc -l )
    echo "rule count = $rule_count "
    if [ $rule_count -lt 2000 ]
    then
        echo "add ip rule "
        for cn_ip in $(cat /script/CN.ip)
        do
        #	ip rule del to $cn_ip table cn pref 888
            ip rule add to $cn_ip table cn pref 888
        done
        for yt_ip in $(cat /script/SERVER.ip)
        do
        #        ip rule del to $yt_ip table wan pref 889
                ip rule add to $yt_ip table wan pref 89
        done
        ip route flush cache
    elif [ $rule_count -gt 10000 ]
    then
        reboot
    fi

}

function check_wanroute
{
    echo "-----check_wanroute-----"

    wan_route=$(ip route list table wan | wc -l)
    vpn_route=$(ip route list table vpn | grep 10.11.12.1 | wc -l)
    cn_route=$(ip route list table cn | wc -l)

    wan_gw=$(ifstatus wan | grep nexthop | grep -v '0.0.0.0' | awk -F\" '{print $4}')
    wwan_gw=$(ifstatus wwan | grep nexthop | grep -v '0.0.0.0' | awk -F\" '{print $4}')
    l2_gw=$(ifstatus l2 | grep nexthop | grep -v '0.0.0.0' | awk -F\" '{print $4}')

    if [ $(ip rule | grep $wan_gw | wc -l) -eq 0 ]; then
        ip rule add to $wan_gw table main pref 1
    fi

    if [ $(ip rule | grep $wwan_gw | wc -l) -eq 0 ]; then
        ip rule add to $wwan_gw table main pref 1
    fi

    if [ $(ip rule | grep $l2_gw | wc -l ) -eq 0 ]; then
        ip rule add to $l2_gw table main pref 1
    fi

    if [ $wan_route -lt 1 ];then

        if [ $wan_gw ]; then
            bash /script/ACTION.sh add_route_to_table $wan_gw wan 100
            bash /script/ACTION.sh add_route_to_table $wan_gw cn 100
            bash /script/ACTION.sh add_route_to_table $wan_gw vpn 100
        fi

        if [ $wwan_gw ]; then
            bash /script/ACTION.sh add_route_to_table $wwan_gw wan 200
            bash /script/ACTION.sh add_route_to_table $wwan_gw cn 200
            bash /script/ACTION.sh add_route_to_table $wwan_gw vpn 200
        fi
    fi

    if [ $vpn_route -lt 1 ];then
        if [ $l2_gw ]; then
            ash /script/ACTION.sh add_route_to_table $l2_gw vpn 2
            bash /script/ACTION.sh changeDNS
        fi
    fi

     if [ $cn_route -lt 1 ];then

        if [ $wan_gw ]; then
            bash /script/ACTION.sh add_route_to_table $wan_gw wan 100
            bash /script/ACTION.sh add_route_to_table $wan_gw cn 100
            bash /script/ACTION.sh add_route_to_table $wan_gw vpn 10
        fi

        if [ $wwan_gw ]; then
            bash /script/ACTION.sh add_route_to_table $wwan_gw wan 200
            bash /script/ACTION.sh add_route_to_table $wwan_gw cn 200
            bash /script/ACTION.sh add_route_to_table $wwan_gw vpn 20
        fi
    fi

}

reset
check_iprule
check_wanroute
