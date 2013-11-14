#!/usr/bin/env bash

action=$1
iface=$2
vip=$3
src=$4

# Make sure forwarding is on
sysctl net.ipv4.ip_forward=1

case $action in
  add)
    logger -t keepalived-notify-$action "Removing local route for $vip"
    ip route del table local local $vip

    logger -t keepalived-notify-$action "Adding VIP NATs for $vip"
    while ! iptables -t nat -I PREROUTING -d $vip/32 -j DNAT --to-dest $src; do sleep 1; done
    while ! iptables -t nat -I OUTPUT -d $vip/32 -j DNAT --to-dest $src; do sleep 1; done
    while ! iptables -t nat -I POSTROUTING -m conntrack --ctstate DNAT --ctorigdst $vip/32 -j SNAT --to-source $vip; do sleep 1; done
    ;;
  del)
    logger -t keepalived-notify-$action "Deleting VIP NATs for $vip"
    iptables -t nat -D PREROUTING -d $vip/32 -j DNAT --to-dest $src
    iptables -t nat -D OUTPUT -d $vip/32 -j DNAT --to-dest $src
    iptables -t nat -D POSTROUTING -m conntrack --ctstate DNAT --ctorigdst $vip/32 -j SNAT --to-source $vip
    ;;
esac
