# Synthesise, implement, write the bitstream and export the XSA.
#
# Usage:
#   vivado -mode batch -source hw/scripts/build.tcl
#
# Optional -tclargs:
#   -jobs <n>   parallel jobs (default: 4)
#   -reset      force a clean rerun of synthesis and implementation
#
# The XSA is what PetaLinux consumes via `petalinux-config --get-hw-description`.
# It is exported with -fixed (not a DFX platform) and with the bitstream
# included, so BOOT.BIN can carry the PL image.

set THIS_DIR  [file normalize [file dirname [info script]]]
set REPO_ROOT [file normalize [file join $THIS_DIR .. ..]]
set PROJ_DIR  [file join $REPO_ROOT hw vivado]
set PROJ_NAME "kbi"
set XPR       [file join $PROJ_DIR ${PROJ_NAME}.xpr]
set XSA       [file join $PROJ_DIR ${PROJ_NAME}.xsa]

set opt_jobs  4
set opt_reset 0
for {set i 0} {$i < [llength $argv]} {incr i} {
    switch -- [lindex $argv $i] {
        -jobs   { incr i; set opt_jobs [lindex $argv $i] }
        -reset  { set opt_reset 1 }
        default { puts "WARNING: ignoring unknown argument [lindex $argv $i]" }
    }
}

if {![file exists $XPR]} {
    error "No project at $XPR. Run hw/scripts/create_project.tcl first."
}

open_project $XPR

if {$opt_reset} {
    puts "Resetting runs"
    reset_run impl_1
    reset_run synth_1
}

set t_start [clock seconds]

# ---- synthesis --------------------------------------------------------------
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    launch_runs synth_1 -jobs $opt_jobs
    wait_on_run synth_1
}
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
    error "Synthesis failed: [get_property STATUS [get_runs synth_1]]"
}
set t_synth [clock seconds]

# ---- implementation and bitstream -------------------------------------------
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    launch_runs impl_1 -to_step write_bitstream -jobs $opt_jobs
    wait_on_run impl_1
}
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "Implementation failed: [get_property STATUS [get_runs impl_1]]"
}
set t_impl [clock seconds]

# ---- timing -----------------------------------------------------------------
open_run impl_1

# A PS-only design has no PL timing paths, so get_timing_paths returns an empty
# list and get_property errors on it. Guard for that: it is the normal case at
# M0 and stops being the case as soon as the traffic generator lands in the PL.
proc _slack {delay_type} {
    set paths [get_timing_paths -quiet -delay_type $delay_type]
    if {[llength $paths] == 0} { return "none (no PL timing paths)" }
    return "[get_property SLACK [lindex $paths 0]] ns"
}
set wns [_slack max]
set whs [_slack min]

# ---- export -----------------------------------------------------------------
write_hw_platform -fixed -include_bit -force $XSA
set t_end [clock seconds]

proc _mmss {s} { return [format "%d m %02d s" [expr {$s / 60}] [expr {$s % 60}]] }

puts ""
puts "============================================================"
puts " Build complete"
puts ""
puts " WNS (setup slack):  $wns"
puts " WHS (hold slack):   $whs"
puts ""
puts " synthesis:      [_mmss [expr {$t_synth - $t_start}]]"
puts " implementation: [_mmss [expr {$t_impl - $t_synth}]]"
puts " export:         [_mmss [expr {$t_end - $t_impl}]]"
puts " total:          [_mmss [expr {$t_end - $t_start}]]"
puts ""
puts " XSA: $XSA"
puts "============================================================"
