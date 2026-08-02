#!/usr/bin/env bash
# Fetch the AUP-ZU3 board files into hw/board_files/.
#
# These are not committed. The upstream repository carries no LICENSE file, so
# redistributing its contents from this public repo would be presumptuous. This
# script makes the dependency reproducible instead: run it once after cloning.
#
# Usage:  ./hw/scripts/fetch_board_files.sh

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dest="$repo_root/hw/board_files"
variant="aup-zu3-8gb"   # the 4 GB and 8 GB boards are NOT interchangeable
upstream="https://github.com/RealDigitalOrg/aup-zu3-bsp.git"

if [ -d "$dest/$variant" ]; then
    echo "Board files already present at $dest/$variant"
    exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Cloning $upstream ..."
git clone --depth 1 --quiet "$upstream" "$tmp"

if [ ! -d "$tmp/board-files/$variant" ]; then
    echo "Variant '$variant' not found upstream" >&2
    exit 1
fi

mkdir -p "$dest"
cp -r "$tmp/board-files/$variant" "$dest/"
echo "Installed board files to $dest/$variant"
echo
echo "Vivado picks these up via hw/scripts/board_repo.tcl, which the project"
echo "creation script sources. Nothing is written into the Vivado install"
echo "directory."
