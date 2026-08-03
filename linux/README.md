# Linux for the AUP-ZU3

Buildroot builds the entire boot chain for this board. No PetaLinux, no Vitis, no
`bootgen`.

| Stage | Comes from |
|---|---|
| First stage loader | U-Boot SPL, in place of the Xilinx FSBL |
| PMU firmware | Xilinx `embeddedsw`, built with a MicroBlaze bare-metal toolchain Buildroot also builds |
| BL31 | ARM Trusted Firmware |
| Bootloader | U-Boot, `xilinx_zynqmp_virt` |
| Kernel | `linux-xlnx`, matching the 2025.2 tool release |
| SD image | genimage, producing a bootable `sdcard.img` |

## Why not PetaLinux

PetaLinux 2025.2 supports Ubuntu 22.04.x, OpenSuse Leap 15.4 and AlmaLinux only,
and asks for 100 GB of disk and eight cores. On a 4-core development host a Yocto
rebuild runs into hours, which directly undermines M0's own acceptance criterion
of a rebuild loop that is not a fight. PYNQ was also considered and rejected: the
`Xilinx/AUP-ZU3` repo ships no prebuilt image, only a `make image-8gb` target
that needs PetaLinux **and** Vivado 2024.1, so it costs more than PetaLinux and
drags the project back a release.

## Building

```sh
git clone --depth 1 -b 2026.02.3 https://gitlab.com/buildroot.org/buildroot.git ~/kbi/buildroot
./linux/build.sh
```

Build on a native Linux filesystem. Under WSL, building on `/mnt/c` is painfully
slow because Buildroot creates a very large number of small files.

Host packages required beyond a normal build environment:

```sh
sudo apt install -y bison flex libssl-dev device-tree-compiler u-boot-tools
```

## Two things that will bite

**`psu_init_gpl.c` must be ours.** It configures the DDR4 controller, the PS
clocks and the MIO pinout. Buildroot's own ZynqMP readme is blunt about the
failure mode: with the wrong one, `boot.bin` builds successfully and then does
nothing at all. Ours is extracted from `hw/vivado/kbi.xsa`, which is where the
RealDigital board preset ends up. Re-extract it whenever the PS configuration
changes:

```sh
unzip -o hw/vivado/kbi.xsa 'psu_init_gpl.*' -d linux/board/aup-zu3/
```

**The generated device tree gets the memory size wrong.** XSCT emits a 4 GB
memory node for this 8 GB board, apparently not accounting for DDR4 bank groups.
The board preset configures x8 DRAM with `BG_ADDR_COUNT=2`, and 2^17 rows × 2^10
columns × 4 banks × 4 bank groups × 32-bit bus is 8 GiB. Zynq UltraScale+ splits
DDR, so that is 2 GB at `0x0` and 6 GB at `0x8_0000_0000`, and 6 GiB needs both
size cells: `<0x8 0x0 0x1 0x80000000>`.

`linux/dts/system-top.dts` carries the correction and documents it inline. If you
regenerate with `linux/scripts/gen_dts.tcl`, re-apply it.

This is not cosmetic. Linux would otherwise see half the RAM, anything reserved
above 4 GB forces the PL DMA engine to 64-bit addressing at M2, and the
`reserved-memory` node at M3 is sized against this map. Verify against
`/proc/iomem` on first boot rather than trusting any of the above.

## Layout

```
linux/
  build.sh                  stages board files into Buildroot, configures, builds
  configs/                  Buildroot defconfig
  board/aup-zu3/            psu_init_gpl, post-build, post-image, genimage
  dts/                      device tree, generated then hand-corrected
  scripts/gen_dts.tcl       regenerates dts/ from the XSA
```

## Status

Not yet built or booted. The configuration above is written against Buildroot
2026.02.3 and its ZynqMP board support, and is untested until the host packages
are installed and `build.sh` runs. Nothing here has been verified on hardware.

Known gap: `BR2_TARGET_UBOOT_ZYNQMP_PM_CFG` is not set. Buildroot's own ZynqMP
boards each ship a `pm_cfg_obj.c` describing which peripherals the PMU should
permit. `xilinx_zynqmp_virt` may work without one; if the PMU refuses peripheral
access on first boot, that is the first thing to look at.
