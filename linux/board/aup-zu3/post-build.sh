#!/bin/sh
# Runs after the rootfs is assembled, before it is packed into an image.
#
# $1 is the console (ttyPS0,115200), $2 the root device (mmcblk0p2), passed via
# BR2_ROOTFS_POST_SCRIPT_ARGS.

set -e

BOARD_DIR="$(dirname "$0")"

# Serial console on the PS UART. The device tree aliases serial0 to uart1 on
# this board, which becomes ttyPS0 as the first enabled PS UART.
if ! grep -q "${1%%,*}" "${TARGET_DIR}/etc/inittab" 2>/dev/null; then
    :
fi

# extlinux config telling U-Boot what to boot. Kept here rather than relying on
# a distro bootcmd so the boot path is explicit and greppable.
mkdir -p "${BINARIES_DIR}/extlinux"
cat > "${BINARIES_DIR}/extlinux/extlinux.conf" <<EOF
label kbi
  kernel /Image
  devicetree /system.dtb
  append console=$1 root=/dev/$2 rootwait earlycon
EOF
