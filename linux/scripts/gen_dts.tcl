# Regenerate the device tree from the Vivado XSA.
#
# Usage, from the repository root:
#   xsct linux/scripts/gen_dts.tcl <path-to-device-tree-xlnx> [xsa] [outdir]
#
# device-tree-xlnx is not vendored. Fetch the branch matching the tool version:
#   git clone --depth 1 -b xlnx_rel_v2025.2 \
#       https://github.com/Xilinx/device-tree-xlnx.git
#
# IMPORTANT: the generated memory node is wrong for this board. XSCT does not
# appear to account for DDR4 bank groups and emits 4 GB where the board has 8.
# After regenerating, re-apply the correction documented in
# linux/dts/system-top.dts before building anything.

if {[llength $argv] < 1} {
    puts "usage: xsct gen_dts.tcl <device-tree-xlnx path> \[xsa\] \[outdir\]"
    exit 1
}

set DTG [file normalize [lindex $argv 0]]
set XSA [file normalize [expr {[llength $argv] > 1 ? [lindex $argv 1] : "hw/vivado/kbi.xsa"}]]
set OUT [file normalize [expr {[llength $argv] > 2 ? [lindex $argv 2] : "linux/dts"}]]

if {![file exists $XSA]} { error "no XSA at $XSA. Build the project first." }
if {![file isdirectory $DTG]} { error "no device-tree-xlnx at $DTG" }

file delete -force $OUT
file mkdir $OUT

hsi::open_hw_design $XSA
hsi::set_repo_path $DTG

# No BOARD override. The generator only ships dtsi files for AMD eval boards and
# fails outright on a name it does not know. Generating purely from the XSA gives
# the PS peripherals exactly as the board preset configured them, which is the
# part that has to be correct.
hsi::create_sw_design device-tree -os device_tree -proc psu_cortexa53_0
hsi::set_property CONFIG.dt_overlay false [hsi::get_os]

hsi::generate_target -dir $OUT

puts "GEN wrote to $OUT"
puts "GEN remember to re-apply the memory@0 correction"
exit
