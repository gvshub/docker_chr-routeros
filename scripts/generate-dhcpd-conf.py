#!/usr/bin/env python3

import os 
import argparse
import ipaddress
import json
import socket
import subprocess
from typing import List, Iterable

DEFAULT_ROUTE = 'default'
DEFAULT_HWADDR = '44:55:AB:CD:EF:01'

DEFAULT_DNS_IPS = ('8.8.8.8', '8.8.4.4')

DHCP_CONF_TEMPLATE = """
start {host_addr}
end   {end_addr}
maxleases 32
interface {dhcp_intf}
# Static leases map
#static_lease 00:60:08:11:CE:4E 192.168.0.54
static_lease {chr_mac} {host_addr}
option dns      {dns}
option router   {gateway}
option subnet   {subnet}
option hostname {hostname}
"""

def default_route(routes):
    """Returns the host's default route"""
    for route in routes:
        if route['dst'] == DEFAULT_ROUTE:
            return route
    raise ValueError('no default route')

def addr_of(addrs, dev : str) -> ipaddress.IPv4Interface:
    """Finds and returns the IP address of `dev`"""
    for addr in addrs:
        if addr['ifname'] != dev:
            continue
        info = addr['addr_info'][0]
        haddr = ipaddress.IPv4Interface((info['local'], info['prefixlen']))
        return haddr
    raise ValueError('dev {0} not found'.format(dev))

def generate_conf(intf_name : str, dns : Iterable[str]) -> str:
    """Generates a dhcpd config. `intf_name` is the interface to listen on."""
    with subprocess.Popen(['ip', '-json', 'route'], stdout=subprocess.PIPE) as proc:
        routes = json.load(proc.stdout)
    with subprocess.Popen(['ip', '-json', 'addr'], stdout=subprocess.PIPE) as proc:
        addrs = json.load(proc.stdout)
    
    droute = default_route(routes)
    host_addr = addr_of(addrs, droute['dev'])
    try:
        hwaddr = os.environ['HWADDR']
    except KeyError:
        hwaddr = DEFAULT_HWADDR
    
    return DHCP_CONF_TEMPLATE.format(
        dhcp_intf = intf_name,
        dns = ' '.join(dns),
        gateway = droute['gateway'],
        host_addr = host_addr.ip,
        chr_mac = hwaddr,
        end_addr = host_addr.ip+20,
        hostname = socket.gethostname(),
        subnet = host_addr.network.netmask,
    )

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('intf_name')
    parser.add_argument('dns_ips', nargs='*')
    args = parser.parse_args()

    dns_ips = args.dns_ips
    if not dns_ips:
        dns_ips = DEFAULT_DNS_IPS

    print(generate_conf(args.intf_name, dns_ips))
