# Fixing Corrupted Packages on OpenWrt

This guide is for an ASUS TUF-AX6000 running OpenWrt 24.10.3 on Filogic / ARMv8.

Typical symptoms:

- `apk` or `opkg` downloads fail with checksum or signature errors
- large downloads produce different hashes each time
- HTTPS downloads succeed but the file contents are corrupted

In practice, this usually points to one of these:

1. bad Ethernet link or cable
2. MTU mismatch
3. hardware/software offload issue
4. packet steering issue
5. Wi-Fi corruption or interference
6. bad RAM, flash, power supply, or upstream modem/ONT

Work through the steps in order.

## 1. Confirm where the corruption happens

Test on the router itself first.

SSH into the router:

```sh
ssh root@192.168.1.1
```

Download the same file twice and compare hashes:

```sh
cd /tmp
wget -O test1.bin https://downloads.openwrt.org/releases/24.10.3/targets/mediatek/filogic/sha256sums
wget -O test2.bin https://downloads.openwrt.org/releases/24.10.3/targets/mediatek/filogic/sha256sums
sha256sum test1.bin test2.bin
cmp -s test1.bin test2.bin && echo identical || echo different
```

Expected result: both hashes should match and `cmp` should report `identical`.

If the files differ when downloaded on the router, the problem is on the router path, WAN link, or upstream modem/ONT.

If the router is clean but a client device gets corrupted files, focus on that client, its Wi-Fi link, or the LAN path to it.

## 2. Check current relevant config on this repo snapshot

Your saved config already shows one setting worth testing:

- `openwrt/etc/config/network:10` has `option packet_steering '1'`

That is not always a problem, but it is a good first thing to disable temporarily during troubleshooting.

Your WAN zone also has MTU clamping enabled:

- `openwrt/etc/config/firewall:28` has `option mtu_fix '1'`

That is usually fine and should stay enabled while testing.

## 3. Disable packet steering temporarily

### LuCI

Go to:

- `Network` -> `Interfaces` -> `Global network options`

Find:

- `Packet Steering`

Disable it, then click `Save & Apply`.

### CLI

Check the current value:

```sh
uci get network.globals.packet_steering
```

Disable it:

```sh
uci set network.globals.packet_steering='0'
uci commit network
/etc/init.d/network restart
```

Verify:

```sh
uci get network.globals.packet_steering
```

Retest the repeated download from step 1.

If corruption stops, leave packet steering disabled.

## 4. Disable flow offloading temporarily

Flow offloading can sometimes cause corrupted transfers or odd checksum failures on specific drivers or SoCs.

### LuCI

Go to:

- `Network` -> `Firewall` -> `General Settings`

Look for:

- `Software flow offloading`
- `Hardware flow offloading`

Disable both, then click `Save & Apply`.

### CLI

Show current settings:

```sh
uci show firewall | grep flow_offloading
```

Disable both if present:

```sh
uci set firewall.@defaults[0].flow_offloading='0'
uci set firewall.@defaults[0].flow_offloading_hw='0'
uci commit firewall
/etc/init.d/firewall restart
```

Verify:

```sh
uci show firewall | grep flow_offloading
```

Retest the repeated download.

If this fixes the issue, leave hardware offloading off. You can later re-enable software offloading only and test whether that remains stable.

## 5. Check for interface errors and driver problems

Run these commands on the router:

```sh
ip -s link
logread | grep -i -E 'mtk|eth|wan|dma|crc|reset|error|timeout'
```

What to look for:

- RX/TX errors increasing on `eth1`, `wan`, `br-lan`, or other active interfaces
- CRC errors
- DMA resets
- repeated link up/down messages
- MediaTek driver warnings

If counters increase while downloading files, that strongly suggests a cable, port, modem/ONT, or driver issue.

If `ethtool` is installed, also run:

```sh
ethtool -S eth1
ethtool -S eth0
```

On many OpenWrt systems `eth1` is WAN and `eth0` is LAN-facing CPU port, but confirm with:

```sh
ubus call network.interface.wan status
ubus call network.interface.lan status
```

## 6. Rule out a bad Ethernet cable or port

This is one of the most common causes of random corruption.

Do these physical tests:

1. replace the WAN cable between router and modem/ONT
2. if possible, move to another modem/ONT port
3. test a wired client directly on LAN with a different cable
4. if corruption happens only on one client, swap that client cable and port too

Then rerun:

```sh
ip -s link
```

If RX/TX errors stop increasing after a cable swap, you found the problem.

## 7. Check MTU and PPPoE or tunnel overhead

Corruption-like symptoms often turn out to be fragmentation or PMTU issues, especially with PPPoE, VLANs, VPNs, or nested tunnels.

Your saved WAN config is DHCP over VLAN 300:

- `openwrt/etc/config/network:27`
- `openwrt/etc/config/network:39`
- `openwrt/etc/config/network:81`

That does not automatically imply an MTU problem, but it is still worth testing.

### Check current WAN status

```sh
ubus call network.interface.wan status
ip link show dev eth1
ip link show dev internet
ip link show dev internet.300
```

### Test path MTU from the router

```sh
ping -c 4 -M do -s 1472 1.1.1.1
ping -c 4 -M do -s 1464 1.1.1.1
ping -c 4 -M do -s 1452 1.1.1.1
```

If larger packets fail but smaller ones work, reduce WAN MTU and retest.

### Example: set WAN MTU to 1492

```sh
uci set network.wan.mtu='1492'
uci commit network
/etc/init.d/network restart
```

### Example: set WAN MTU to 1500 again

```sh
uci delete network.wan.mtu
uci commit network
/etc/init.d/network restart
```

If you use PPPoE instead of DHCP, `1492` is the usual first test value.

If you route traffic through WireGuard, also test with VPN disabled because your saved config uses MTU `1472` for `wg0` and `wg0_br`:

- `openwrt/etc/config/network:61`
- `openwrt/etc/config/network:95`

## 8. Separate wired from Wi-Fi problems

If only Wi-Fi clients see corrupted downloads:

1. test the same download over wired LAN
2. test 2.4 GHz and 5 GHz separately
3. temporarily disable one SSID and test the other
4. try a different channel
5. avoid crowded 2.4 GHz channels

Useful commands:

```sh
iwinfo
logread | grep -i -E 'wifi|wlan|mt76|deauth|disassoc|radar|reset'
```

Useful LuCI pages:

- `Network` -> `Wireless`
- `Status` -> `Wireless`
- `Status` -> `System Log`

Your current saved wireless config is in:

- `openwrt/etc/config/wireless`

If wired clients are clean and only Wi-Fi clients are affected, focus on radio settings, interference, or client device drivers rather than WAN.

## 9. Check storage, RAM, and power stability

If files arrive intact over the network but become corrupted after writing, the issue may be local hardware.

Useful checks:

```sh
dmesg | grep -i -E 'error|fail|ecc|ubi|ubifs|mtd|oom|segfault'
free -h
df -h
mount
```

Look for:

- flash or UBIFS errors
- kernel crashes or memory issues
- low free space in `/tmp` while testing downloads

Also check the power supply:

- use the original PSU if possible
- avoid flaky extension cords or overloaded power strips
- feel whether the router is unusually hot under load

## 10. Update OpenWrt to the latest maintenance release

If a newer `24.10.x` build exists for the TUF-AX6000, upgrade to it. MediaTek / Filogic fixes sometimes land in maintenance releases.

Useful places:

- LuCI: `System` -> `Backup / Flash Firmware`
- CLI release check:

```sh
cat /etc/openwrt_release
uname -a
```

Before upgrading, back up config:

```sh
sysupgrade -b /tmp/openwrt-backup-$(date +%F).tar.gz
ls -lh /tmp/openwrt-backup-*.tar.gz
```

Copy the backup off the router with `scp` if needed.

## 11. Minimal safe troubleshooting order

If you want the shortest path, do this sequence:

1. test repeated downloads on the router itself
2. disable `packet_steering`
3. disable software and hardware flow offloading
4. replace the WAN Ethernet cable
5. check `ip -s link` and `logread`
6. test wired versus Wi-Fi separately
7. test lower WAN MTU if needed
8. update to the newest `24.10.x`

## 12. If you want to restore settings after testing

### Re-enable packet steering

```sh
uci set network.globals.packet_steering='1'
uci commit network
/etc/init.d/network restart
```

### Re-enable flow offloading

```sh
uci set firewall.@defaults[0].flow_offloading='1'
uci set firewall.@defaults[0].flow_offloading_hw='1'
uci commit firewall
/etc/init.d/firewall restart
```

Only turn features back on one at a time, testing after each change.

## 13. When to suspect hardware failure

Start suspecting hardware if all of these are true:

- corruption happens on the router itself, not just one client
- it persists with offloading disabled
- it persists with packet steering disabled
- cables and ports were swapped
- logs show link or DMA errors, or behavior changes with heat/load

At that point the likely culprits are:

- router hardware
- power supply
- modem / ONT
- upstream ISP link

## Handy command set

You can paste this block into an SSH session to collect the most useful information quickly:

```sh
echo '=== release ==='
cat /etc/openwrt_release
uname -a
echo '=== network globals ==='
uci get network.globals.packet_steering 2>/dev/null
echo '=== firewall offloading ==='
uci show firewall | grep flow_offloading
echo '=== wan status ==='
ubus call network.interface.wan status
echo '=== link counters ==='
ip -s link
echo '=== recent errors ==='
logread | grep -i -E 'mtk|eth|wan|dma|crc|reset|error|timeout'
```
