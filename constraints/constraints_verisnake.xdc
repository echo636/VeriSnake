# =============================================================
# Constraints file for Verilog Snake Game
# Based on constraints_lab8.xdc
# =============================================================

# -------------------------------------------------------------
# 1. Main System Clock
# -------------------------------------------------------------
# Assumes your top module has an input port named 'clk'
set_property PACKAGE_PIN AC18 [get_ports clk]
set_property IOSTANDARD LVCMOS18 [get_ports clk]
create_clock -period 10.000 -name clk [get_ports clk]

# -------------------------------------------------------------
# 2. Push Buttons (Keys) for Game Control
# -------------------------------------------------------------
# You need to decide which physical buttons map to which game functions.
# I'll map BTN[0] to UP, BTN[1] to DOWN, BTNX4 to LEFT,
# and use switches for RIGHT, START/PAUSE, and RESET.
# Please adjust these to match your board and preferences.

# Example mapping:

# Using a switch (e.g., SW[2]) for GAME RESET
# This will be your active-low physical reset button if connected to rst_n
# If you have a dedicated reset button (like RSTN W13 in the commented section), use that instead.
# For now, assuming one of the switches acts as a global reset for the logic.
# However, it's better to have a dedicated reset button mapped to your top-level 'rst_n'.
# Let's assume you have a dedicated active-low reset button on pin W13 (from commented section):
set_property PACKAGE_PIN W13 [get_ports rst_n]
set_property IOSTANDARD LVCMOS18 [get_ports rst_n]



# If your buttons are on paths that might be mistaken for clock paths by the tools:
# set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {btn_up_raw_in_IBUF}]
# set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {btn_down_raw_in_IBUF}]
# set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {btn_left_raw_in_IBUF}]
# (Add for other buttons if necessary, usually not needed for general push buttons)

# -------------------------------------------------------------
# 3. VGA Output
# -------------------------------------------------------------
# These pins are from the *commented out* VGA section of your original file,
# which seem more standard for VGA. The "Arduino-Segment & AN" section also
# has AN and SEGMENT which might be for a different display.
# Assuming standard VGA_R[3:0], VGA_G[3:0], VGA_B[3:0], VGA_HS, VGA_VS
# Please verify these pins with your board's VGA connector.

# VGA Red (4-bit) - Assuming port names vga_r[3:0]
set_property PACKAGE_PIN N21 [get_ports {vga_r[0]}]
set_property PACKAGE_PIN N22 [get_ports {vga_r[1]}]
set_property PACKAGE_PIN R21 [get_ports {vga_r[2]}]
set_property PACKAGE_PIN P21 [get_ports {vga_r[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[*]}]

# VGA Green (4-bit) - Assuming port names vga_g[3:0]
set_property PACKAGE_PIN R22 [get_ports {vga_g[0]}]
set_property PACKAGE_PIN R23 [get_ports {vga_g[1]}]
set_property PACKAGE_PIN T24 [get_ports {vga_g[2]}]
set_property PACKAGE_PIN T25 [get_ports {vga_g[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[*]}]

# VGA Blue (4-bit) - Assuming port names vga_b[3:0]
set_property PACKAGE_PIN T20 [get_ports {vga_b[0]}]
set_property PACKAGE_PIN R20 [get_ports {vga_b[1]}]
set_property PACKAGE_PIN T22 [get_ports {vga_b[2]}]
set_property PACKAGE_PIN T23 [get_ports {vga_b[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[*]}]

# VGA Sync Signals - Assuming port names vga_hs and vga_vs
set_property PACKAGE_PIN M22 [get_ports vga_hs]
set_property PACKAGE_PIN M21 [get_ports vga_vs]
set_property IOSTANDARD LVCMOS33 [get_ports vga_hs]
set_property IOSTANDARD LVCMOS33 [get_ports vga_vs]

# -------------------------------------------------------------
# 4. Seven Segment Display (Score & Game State)
# -------------------------------------------------------------
# Using the "Arduino-Segment & AN" pins from your file.
# Assumes your top module has 'seg_an[7:0]' and 'seg_data[7:0]'
# Your display_driver_basic uses 4 anodes, so AN[3:0] will be used.

# Anode selection (assuming 4 active low anodes for 4 digits from display_driver_basic)
# Your display_driver_basic maps its 4-bit AN to seg_an[3:0]
# and sets seg_an[7:4] to 4'b1111 (disabled).
set_property PACKAGE_PIN AD21 [get_ports {seg_an[0]}]  
set_property PACKAGE_PIN AC21 [get_ports {seg_an[1]}]  
set_property PACKAGE_PIN AB21 [get_ports {seg_an[2]}]
set_property PACKAGE_PIN AC22 [get_ports {seg_an[3]}]  
# If you use all 8 anodes, uncomment and map these:
# set_property PACKAGE_PIN PinX1 [get_ports {seg_an[4]}] // AN4
# set_property PACKAGE_PIN PinX2 [get_ports {seg_an[5]}] // AN5
# set_property PACKAGE_PIN PinX3 [get_ports {seg_an[6]}] // AN6
# set_property PACKAGE_PIN PinX4 [get_ports {seg_an[7]}] // AN7
set_property IOSTANDARD LVCMOS33 [get_ports {seg_an[*]}]

# Segment data (a-g, dp) - Assuming common anode display (segments active low)
set_property PACKAGE_PIN AB22 [get_ports {seg_data[0]}] 
set_property PACKAGE_PIN AD24 [get_ports {seg_data[1]}] 
set_property PACKAGE_PIN AD23 [get_ports {seg_data[2]}]
set_property PACKAGE_PIN Y21  [get_ports {seg_data[3]}] 
set_property PACKAGE_PIN W20  [get_ports {seg_data[4]}] 
set_property PACKAGE_PIN AC24 [get_ports {seg_data[5]}] 
set_property PACKAGE_PIN AC23 [get_ports {seg_data[6]}]
set_property PACKAGE_PIN AA22 [get_ports {seg_data[7]}] 
set_property IOSTANDARD LVCMOS33 [get_ports {seg_data[*]}]

# -------------------------------------------------------------
# 5. LEDs (Game State or Custom Pattern)
# -------------------------------------------------------------
# Assuming your top module has 'led[7:0]'
# I'll use the 'ard_led' pins from your provided file as an example.
# You might have dedicated LEDs on different pins.

set_property PACKAGE_PIN AF24 [get_ports {led[0]}]
set_property PACKAGE_PIN AE21 [get_ports {led[1]}]
set_property PACKAGE_PIN Y22  [get_ports {led[2]}]
set_property PACKAGE_PIN Y23  [get_ports {led[3]}]
set_property PACKAGE_PIN AA23 [get_ports {led[4]}]
set_property PACKAGE_PIN Y25  [get_ports {led[5]}]
set_property PACKAGE_PIN AB26 [get_ports {led[6]}]
set_property PACKAGE_PIN W23  [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

# -------------------------------------------------------------
# Buzzer Output (蜂鸣器输出)
# -------------------------------------------------------------
set_property PACKAGE_PIN AF25 [get_ports buzzer]
set_property IOSTANDARD LVCMOS33 [get_ports buzzer]

# -------------------------------------------------------------
# 6. PS/2 Interface (Keyboard Input)
# -------------------------------------------------------------
set_property PACKAGE_PIN N18 [get_ports ps2_clk]
set_property IOSTANDARD LVCMOS33 [get_ports ps2_clk]
set_property PACKAGE_PIN M19 [get_ports ps2_data]
set_property IOSTANDARD LVCMOS33 [get_ports ps2_data]
# =============================================================
# End of Constraints
# =============================================================