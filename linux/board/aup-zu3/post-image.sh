#!/bin/sh
# Runs after all images are built. Points U-Boot at our devicetree under the
# name it looks for, then assembles the SD card image.

set -e

BOARD_DIR="$(dirname "$0")"

# U-Boot loads the devicetree from a file called system.dtb by default.
ln -fs "system-top.dtb" "${BINARIES_DIR}/system.dtb"

support/scripts/genimage.sh -c "${BOARD_DIR}/genimage.cfg"
