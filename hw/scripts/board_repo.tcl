# Point Vivado at the AUP-ZU3 board files fetched into hw/board_files/.
#
# Sourced by the project creation script. Kept separate so it can also be
# sourced interactively when poking at an existing project.
#
# Nothing is written into the Vivado install tree, so the board files travel
# with the repository rather than with the machine.

set _script_dir [file normalize [file dirname [info script]]]
set _board_dir  [file normalize [file join $_script_dir .. board_files]]

if {![file isdirectory $_board_dir]} {
    error "Board files missing at $_board_dir.\
           Run hw/scripts/fetch_board_files.sh (or .ps1) first."
}

set_param board.repoPaths $_board_dir

# The 8 GB and 4 GB boards are not interchangeable. This project targets 8 GB.
set BOARD_PART "realdigital.org:aup-zu3-8gb:part0:1.0"

# Speed grade -2, read off the board file's PART_NAME rather than assumed.
# Setting board_part overrides part anyway, so a mismatch here would be silently
# corrected and then confuse every timing report that followed.
set FPGA_PART  "xczu3eg-sfvc784-2-e"

puts "board.repoPaths -> $_board_dir"
puts "board part      -> $BOARD_PART"
puts "part            -> $FPGA_PART"
