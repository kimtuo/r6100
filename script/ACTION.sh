#!/bin/bash

hostname=$(uci get system.@system[0].hostname)

function ping_test
{
    ping -c 5 -W 1 -q $1  |grep round-trip |awk -F\/ '{print $4}' | awk -F\. '{print $1}'
}

function add_route_to_table
{
    gate_way=$1
    table=$2
    metric=$3

    if [ "$gate_way" != "" ] && [ "$table" != "" ] && [ "$metric" != "" ]
    then
        echo "add route $gate_way $table $metric"
        route_count=$(ip route list table $table | grep "metric $metric" | grep "$gate_way" | wc -l)

        if [ $route_count -eq 0 ]
        then
            ping=$( ping_test $gate_way )
            echo "ping is $ping"
            if [ $ping ]
            then
                echo "ip route add default via $gate_way metric $metric table $table"
                old_route_count=$(ip route list table $table | grep "metric $metric" | wc -l )
                if [ $old_route_count -gt 0 ]
                then
                    old_route=$(ip route list table $table | grep "metric $metric")
                    ip route delete $old_route
                fi
                ip route add default via $gate_way metric $metric table $table
            fi
        fi
    fi
}



function test
{
    echo "$2" > /tmp/test
}


function changeDNS
{
    system_from=$(uci get entsu_status.@system[0].from)
    if [ $system_from == 'CN' ]
    then
        uci set dhcp.@dnsmasq[0].resolvfile='/script/resolv.conf'
        uci commit dhcp
        /etc/init.d/dnsmasq restart
    fi
}

function changeDNS_BAK
{
    system_from=$(uci get entsu_status.@system[0].from)
    if [ $system_from == 'CN' ]
    then
        uci set dhcp.@dnsmasq[0].resolvfile='/tmp/resolv.conf.auto'
        uci commit dhcp
        /etc/init.d/dnsmasq restart
    fi
}
function action_start
{
    $*
}

############################

action_start $*
