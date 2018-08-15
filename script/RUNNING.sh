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

reset
check_iprule
