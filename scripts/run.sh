#!/usr/bin/env bash

QEMU_BRIDGE='qemubr0'
DEFAULT_DEV='eth0'

# DHCPD must have an IP address to run, but that address doesn't have to
# be valid. This is the dummy address dhcpd is configured to use.
DUMMY_DHCPD_IP='10.0.0.1'

# These scripts configure/deconfigure the VM interface on the bridge.
QEMU_IFUP='/chr/qemu-ifup'
QEMU_IFDOWN='/chr/qemu-ifdown'

# The name of the dhcpd config file we make
DHCPD_CONF_FILE='/chr/dhcpd.conf'

# First step, we run the things that need to happen before we start mucking
# with the interfaces. We start by generating the DHCPD config file based
# on our current address/routes. We "steal" the container's IP, and lease
# it to the VM once it starts up.
/chr/generate-dhcpd-conf.py $QEMU_BRIDGE >$DHCPD_CONF_FILE

#First we clear out the IP address and route
ip addr flush dev $DEFAULT_DEV
# Next, we create our bridge, and add our container interface to it.
ip link add $QEMU_BRIDGE type bridge
ip link set dev $DEFAULT_DEV master $QEMU_BRIDGE
# Then, we toggle the interface and the bridge to make sure everything is up
# and running.
ip link set dev $DEFAULT_DEV up
ip link set dev $QEMU_BRIDGE up

# Finally, start our DHCPD server
udhcpd -I $DUMMY_DHCPD_IP -f $DHCPD_CONF_FILE &

# And run the VM! A brief explanation of the options here:
## -enable-kvm: Use KVM for this VM (much faster for our case).
# -nographic: disable SDL graphics.
# -serial mon:stdio: use "monitored stdio" as our serial output.
# -nic: Use a TAP interface with our custom up/down scripts.
#   mac: Interfaces mac addresses, can not be changed from RouterOS.
## -drive: The VM image we're booting.
exec qemu-system-x86_64 \
   -nographic -serial mon:stdio \
   -vnc 0.0.0.0:0 \
   -m 512 \
   -smp 4,sockets=1,cores=4,threads=1 \
   -nic tap,id=qemu0,mac=$HWADDR,script=$QEMU_IFUP,downscript=$QEMU_IFDOWN \
   "$@" \
   -hda $IMAGE