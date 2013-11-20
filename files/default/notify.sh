#!/usr/bin/env bash

# Args from keepalived notify_*
action=$1
iface=$2
vip=$3
src=$4

# Custom routing table name/index
table=vips
index=100

# Ensure persistent table config
if ! grep -q "$index $table" /etc/iproute2/rt_tables; then echo "$index $table" >> /etc/iproute2/rt_tables; fi

# Setup our custom table and rule
ip route add local $vip dev $iface table vips
if ! (ip rule list | grep -q $table); then ip rule add iif $iface lookup $table; fi

# Make sure forwarding is on
sysctl net.ipv4.ip_forward=1

case $action in
  haproxy)
    logger -t keepalived-notify-$action "Ensuring haproxy APIPA bind for $vip"
    ip addr add $src/32 dev lo
    ;;& # Check remaining patterns
  add|haproxy)
    logger -t keepalived-notify-$action "Removing local route for $vip"
    ip route del table local local $vip

    logger -t keepalived-notify-$action "Adding VIP NATs for $vip"
    while ! iptables -t nat -I PREROUTING -d $vip/32 -j DNAT --to-dest $src; do sleep 1; done
    while ! iptables -t nat -I OUTPUT -d $vip/32 -j DNAT --to-dest $src; do sleep 1; done
    ;;
  del)
    logger -t keepalived-notify-$action "Deleting VIP NATs for $vip"
    iptables -t nat -D PREROUTING -d $vip/32 -j DNAT --to-dest $src
    iptables -t nat -D OUTPUT -d $vip/32 -j DNAT --to-dest $src
    ;;
esac
