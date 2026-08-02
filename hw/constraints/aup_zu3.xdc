# -----------------------------------------------------------------------------
# AUP-ZU3 physical constraints.
#
# Pin locations and IO standards are taken from the board file
# (board_files/aup-zu3-8gb/1.0/part0_pins.xml), not from the reference manual,
# so they stay consistent with whatever the board preset configures.
#
# All PL user IO on this board is LVCMOS12.
# -----------------------------------------------------------------------------

# ---- User LEDs, active high ----
set_property -dict {PACKAGE_PIN AF5 IOSTANDARD LVCMOS12} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN AE7 IOSTANDARD LVCMOS12} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN AH2 IOSTANDARD LVCMOS12} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN AE5 IOSTANDARD LVCMOS12} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN AH1 IOSTANDARD LVCMOS12} [get_ports {led[4]}]
set_property -dict {PACKAGE_PIN AE4 IOSTANDARD LVCMOS12} [get_ports {led[5]}]
set_property -dict {PACKAGE_PIN AG1 IOSTANDARD LVCMOS12} [get_ports {led[6]}]
set_property -dict {PACKAGE_PIN AF2 IOSTANDARD LVCMOS12} [get_ports {led[7]}]

# -----------------------------------------------------------------------------
# Not yet used, recorded here so the pinout lives in one place.
#
#   DIP switches, active high:
#     SW0 AB1   SW1 AF1   SW2 AE3   SW3 AC2
#     SW4 AC1   SW5 AD6   SW6 AD1   SW7 AD2
#
#   Push buttons, active high:
#     PB0 AB6   PB1 AB7   PB2 AB2   PB3 AC6
#
# The traffic generator at M1 will want a switch or button to gate injection,
# so these get uncommented then rather than guessed at now.
# -----------------------------------------------------------------------------
