## Vivado constraints for pong.v on the Digilent Nexys 4 (original, Rev B)
## Pin numbers taken from Digilent's Nexys-4-Master.xdc.
##
## If you have a Nexys 4 DDR / Nexys A7 instead, the VGA pins are identical but
## the buttons and 7-segment pins differ: see the commented block at the bottom.

## Clock: 100 MHz oscillator
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports CLK100MHZ]
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5} [get_ports CLK100MHZ]

## Reset (red CPU RESET button, active low)
set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports CPU_RESETN]

## Push buttons
set_property -dict { PACKAGE_PIN E16 IOSTANDARD LVCMOS33 } [get_ports BTNC]
set_property -dict { PACKAGE_PIN F15 IOSTANDARD LVCMOS33 } [get_ports BTNU]
set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS33 } [get_ports BTNL]
set_property -dict { PACKAGE_PIN R10 IOSTANDARD LVCMOS33 } [get_ports BTNR]
set_property -dict { PACKAGE_PIN V10 IOSTANDARD LVCMOS33 } [get_ports BTND]

## VGA
set_property -dict { PACKAGE_PIN A3 IOSTANDARD LVCMOS33 } [get_ports {VGA_R[0]}]
set_property -dict { PACKAGE_PIN B4 IOSTANDARD LVCMOS33 } [get_ports {VGA_R[1]}]
set_property -dict { PACKAGE_PIN C5 IOSTANDARD LVCMOS33 } [get_ports {VGA_R[2]}]
set_property -dict { PACKAGE_PIN A4 IOSTANDARD LVCMOS33 } [get_ports {VGA_R[3]}]
set_property -dict { PACKAGE_PIN C6 IOSTANDARD LVCMOS33 } [get_ports {VGA_G[0]}]
set_property -dict { PACKAGE_PIN A5 IOSTANDARD LVCMOS33 } [get_ports {VGA_G[1]}]
set_property -dict { PACKAGE_PIN B6 IOSTANDARD LVCMOS33 } [get_ports {VGA_G[2]}]
set_property -dict { PACKAGE_PIN A6 IOSTANDARD LVCMOS33 } [get_ports {VGA_G[3]}]
set_property -dict { PACKAGE_PIN B7 IOSTANDARD LVCMOS33 } [get_ports {VGA_B[0]}]
set_property -dict { PACKAGE_PIN C7 IOSTANDARD LVCMOS33 } [get_ports {VGA_B[1]}]
set_property -dict { PACKAGE_PIN D7 IOSTANDARD LVCMOS33 } [get_ports {VGA_B[2]}]
set_property -dict { PACKAGE_PIN D8 IOSTANDARD LVCMOS33 } [get_ports {VGA_B[3]}]
set_property -dict { PACKAGE_PIN B11 IOSTANDARD LVCMOS33 } [get_ports VGA_HS]
set_property -dict { PACKAGE_PIN B12 IOSTANDARD LVCMOS33 } [get_ports VGA_VS]

## 7-segment display (SEG[0]=CA ... SEG[6]=CG)
set_property -dict { PACKAGE_PIN L3 IOSTANDARD LVCMOS33 } [get_ports {SEG[0]}]
set_property -dict { PACKAGE_PIN N1 IOSTANDARD LVCMOS33 } [get_ports {SEG[1]}]
set_property -dict { PACKAGE_PIN L5 IOSTANDARD LVCMOS33 } [get_ports {SEG[2]}]
set_property -dict { PACKAGE_PIN L4 IOSTANDARD LVCMOS33 } [get_ports {SEG[3]}]
set_property -dict { PACKAGE_PIN K3 IOSTANDARD LVCMOS33 } [get_ports {SEG[4]}]
set_property -dict { PACKAGE_PIN M2 IOSTANDARD LVCMOS33 } [get_ports {SEG[5]}]
set_property -dict { PACKAGE_PIN L6 IOSTANDARD LVCMOS33 } [get_ports {SEG[6]}]
set_property -dict { PACKAGE_PIN M4 IOSTANDARD LVCMOS33 } [get_ports DP]
set_property -dict { PACKAGE_PIN N6 IOSTANDARD LVCMOS33 } [get_ports {AN[0]}]
set_property -dict { PACKAGE_PIN M6 IOSTANDARD LVCMOS33 } [get_ports {AN[1]}]
set_property -dict { PACKAGE_PIN M3 IOSTANDARD LVCMOS33 } [get_ports {AN[2]}]
set_property -dict { PACKAGE_PIN N5 IOSTANDARD LVCMOS33 } [get_ports {AN[3]}]
set_property -dict { PACKAGE_PIN N2 IOSTANDARD LVCMOS33 } [get_ports {AN[4]}]
set_property -dict { PACKAGE_PIN N4 IOSTANDARD LVCMOS33 } [get_ports {AN[5]}]
set_property -dict { PACKAGE_PIN L1 IOSTANDARD LVCMOS33 } [get_ports {AN[6]}]
set_property -dict { PACKAGE_PIN M1 IOSTANDARD LVCMOS33 } [get_ports {AN[7]}]

## Configuration
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

## --------------------------------------------------------------------------
## Nexys 4 DDR / Nexys A7 alternative: comment out the button and 7-seg lines
## above and uncomment these instead. Clock, reset and VGA pins are unchanged.
## --------------------------------------------------------------------------
# set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports BTNC]
# set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports BTNU]
# set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports BTNL]
# set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS33 } [get_ports BTNR]
# set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports BTND]
# set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports {SEG[0]}]
# set_property -dict { PACKAGE_PIN R10 IOSTANDARD LVCMOS33 } [get_ports {SEG[1]}]
# set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS33 } [get_ports {SEG[2]}]
# set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 } [get_ports {SEG[3]}]
# set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports {SEG[4]}]
# set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports {SEG[5]}]
# set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 } [get_ports {SEG[6]}]
# set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports DP]
# set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports {AN[0]}]
# set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports {AN[1]}]
# set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports {AN[2]}]
# set_property -dict { PACKAGE_PIN J14 IOSTANDARD LVCMOS33 } [get_ports {AN[3]}]
# set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports {AN[4]}]
# set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 } [get_ports {AN[5]}]
# set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 } [get_ports {AN[6]}]
# set_property -dict { PACKAGE_PIN U13 IOSTANDARD LVCMOS33 } [get_ports {AN[7]}]
