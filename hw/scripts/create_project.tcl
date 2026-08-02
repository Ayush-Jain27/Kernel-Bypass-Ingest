# Regenerate the Vivado project from source.
#
# The .xpr is never committed. This script is the source of truth, so the
# project can be rebuilt on any machine that has the board files fetched.
#
# Usage:
#   vivado -mode batch -source hw/scripts/create_project.tcl
#
# Optional -tclargs:
#   -force          delete and recreate an existing project without asking
#   -jobs <n>       parallel jobs for synth/impl (default: 4)
#
# M0 scope: processing system only, no PL logic yet. This is the known-good
# baseline that the traffic generator gets added to later.

set THIS_DIR  [file normalize [file dirname [info script]]]
set REPO_ROOT [file normalize [file join $THIS_DIR .. ..]]
set PROJ_DIR  [file join $REPO_ROOT hw vivado]
set PROJ_NAME "kbi"

source [file join $THIS_DIR board_repo.tcl]

# ---- argument parsing -------------------------------------------------------
set opt_force 0
set opt_jobs  4
for {set i 0} {$i < [llength $argv]} {incr i} {
    switch -- [lindex $argv $i] {
        -force { set opt_force 1 }
        -jobs  { incr i; set opt_jobs [lindex $argv $i] }
        default { puts "WARNING: ignoring unknown argument [lindex $argv $i]" }
    }
}

# ---- project ----------------------------------------------------------------
if {[file exists $PROJ_DIR]} {
    if {!$opt_force} {
        error "Project already exists at $PROJ_DIR. Re-run with -tclargs -force to recreate it."
    }
    puts "Removing existing project at $PROJ_DIR"
    file delete -force $PROJ_DIR
}

create_project $PROJ_NAME $PROJ_DIR -part $FPGA_PART
set_property board_part $BOARD_PART [current_project]

# Keep generated IP inside the project tree so the whole thing is disposable.
set_property target_language Verilog [current_project]

# ---- sources ----------------------------------------------------------------
# RTL must be added before the block design, because the blink module is
# instantiated into the BD by reference and Vivado has to be able to find it.
add_files -norecurse [glob [file join $REPO_ROOT hw rtl *.sv]]
add_files -fileset constrs_1 -norecurse [glob [file join $REPO_ROOT hw constraints *.xdc]]
update_compile_order -fileset sources_1

# ---- block design: processing system only -----------------------------------
set BD_NAME "sys"
create_bd_design $BD_NAME

set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ultra_ps_e_0]

# The board preset is the entire reason the board files matter. It configures
# the DDR4 controller, the PS clocks and the MIO pinout to match this board.
# Entering that by hand is how bring-up goes wrong.
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
    -config {apply_board_preset "1"} $ps

# The preset turns on the PS-to-PL AXI master ports. With no PL logic there is
# nothing to drive their clocks and nothing behind their address spaces, so
# validation fails on unconnected clock pins. Turn them off for the baseline.
#
#   GP0 = M_AXI_HPM0_FPD    GP1 = M_AXI_HPM1_FPD    GP2 = M_AXI_HPM0_LPD
#
# M2 re-enables one of these to carry the control interface for the DMA engine,
# and adds the S_AXI_HP / HPC slave that the DMA writes DDR4 through. That is
# also where the cache coherence decision gets made, since HP and HPC differ in
# whether writes are snooped against the PS caches.
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 {0} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__M_AXI_GP2 {0} \
] $ps

# The PL still needs a clock and a reset out of the PS. pl_clk0 at 100 MHz is
# the reference the blink divider is parameterised against, and it is the clock
# the traffic generator's free-running cycle counter will run on at M1, which is
# what every latency figure in this project ends up denominated in.
set_property -dict [list \
    CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
] $ps

# Expose the PL clock and reset so hw/rtl/top.sv can drive fabric logic with
# them. The block design deliberately contains the PS and nothing else: custom
# logic stays in SystemVerilog source rather than becoming a diagram.
create_bd_port -dir O -type clk pl_clk0
connect_bd_net [get_bd_pins ${ps}/pl_clk0] [get_bd_ports pl_clk0]

create_bd_port -dir O -type rst pl_resetn0
connect_bd_net [get_bd_pins ${ps}/pl_resetn0] [get_bd_ports pl_resetn0]

validate_bd_design
save_bd_design

# ---- HDL wrapper ------------------------------------------------------------
# The generated wrapper is instantiated by hw/rtl/top.sv, so `top` is the top,
# not the wrapper. The wrapper is a generated artefact and is never committed.
set bd_file [get_files ${BD_NAME}.bd]
make_wrapper -files $bd_file -top
add_files -norecurse [file join $PROJ_DIR ${PROJ_NAME}.gen sources_1 bd $BD_NAME hdl ${BD_NAME}_wrapper.v]
set_property top top [current_fileset]
update_compile_order -fileset sources_1

# ---- run configuration ------------------------------------------------------
set_property strategy Flow_PerfOptimized_high [get_runs synth_1]
set_property strategy Performance_ExtraTimingOpt [get_runs impl_1]

puts ""
puts "============================================================"
puts " Project created: [file join $PROJ_DIR ${PROJ_NAME}.xpr]"
puts " Part:            $FPGA_PART"
puts " Board part:      $BOARD_PART"
puts " Top:             top (hw/rtl/top.sv, wrapping ${BD_NAME}_wrapper)"
puts " Parallel jobs:   $opt_jobs"
puts ""
puts " Next: hw/scripts/build.tcl runs synth, impl, bitstream and"
puts " exports the XSA that PetaLinux consumes."
puts "============================================================"
