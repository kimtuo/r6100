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

reset
