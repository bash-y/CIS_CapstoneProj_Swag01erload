#!/usr/bin/env python3
"""Add a gateway route inside this container: add-route.py <network/prefix> <gateway>.

US-19 (#130). The ZAP image has no `ip` tool, so the route to the Business subnet through the firewall
is added with the kernel's route ioctl. Needs CAP_NET_ADMIN. An existing identical route is not an error.
"""
import errno
import fcntl
import ipaddress
import socket
import struct
import sys

SIOCADDRT = 0x890B
RTF_UP, RTF_GATEWAY = 0x0001, 0x0002


def sockaddr(ip):
    # struct sockaddr_in: family (2 bytes), port (2), address (4), 8 bytes of padding
    return struct.pack("@HH4s8x", socket.AF_INET, 0, ipaddress.IPv4Address(ip).packed)


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: add-route.py <network/prefix> <gateway>")
    net = ipaddress.IPv4Network(sys.argv[1])
    gateway = ipaddress.IPv4Address(sys.argv[2])
    # struct rtentry, laid out by native alignment like the C struct (LP64: 120 bytes)
    rtentry = struct.pack(
        "@L16s16s16sHhLPhPLLH",
        0, sockaddr(net.network_address), sockaddr(gateway), sockaddr(net.netmask),
        RTF_UP | RTF_GATEWAY, 0, 0, 0, 0, 0, 0, 0, 0,
    )
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        try:
            fcntl.ioctl(s.fileno(), SIOCADDRT, rtentry)
        except OSError as err:
            if err.errno != errno.EEXIST:
                sys.exit(f"add-route: cannot add {net} via {gateway}: {err}")
    print(f"add-route: {net} via {gateway}")


if __name__ == "__main__":
    main()
