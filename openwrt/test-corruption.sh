#!/bin/sh
_8MB="https://downloads.openwrt.org/releases/24.10.3/targets/mediatek/filogic/openwrt-24.10.3-mediatek-filogic-asus_tuf-ax6000-initramfs-kernel.bin"
_200MB="https://dietpi.com/downloads/images/DietPi_NativePC-BIOS-x86_64-Trixie.img.xz"
_800MB="https://dietpi.com/downloads/images/DietPi_NativePC-BIOS-x86_64-Trixie_Installer.iso"
cd /tmp

sha_cmp() {
	wget -qO $(basename $1) "$1"
	wget -qO sha256.list "${1}.sha256"
	sha256sum -c sha256.list
}

bin_cmp() {
    wget -qO test1.bin --show-progress "$1"
    wget -qO test2.bin --show-progress "$1"
    cmp -s test1.bin test2.bin
    return $?
}

loop() {
	eval "url=\"\$_${2}\""
        i=1
	while [ $i -le $3 ]; do
	     $1 "$url" || { echo "Failed"; return; }
             echo "Attempt $i: success"
             i=$((i + 1))
	done
}

file_size="${1:-8}MB"
max_tries=${2:-1}

echo "$max_tries tries : $file_size"
loop bin_cmp $file_size $max_tries
