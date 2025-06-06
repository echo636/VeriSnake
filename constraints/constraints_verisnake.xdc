# =============================================================
# Constraints file for Verilog Snake Game
# Based on constraints_lab8.xdc
# =============================================================

# -------------------------------------------------------------
# 1. Main System Clock
# -------------------------------------------------------------
# Assumes your top module has an input port named 'sys_clk'
set_property PACKAGE_PIN AC18 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS18 [get_ports sys_clk]
create_clock -period 10.000 -name sys_clk [get_ports sys_clk]

# -------------------------------------------------------------
# 2. Push Buttons (Keys) for Game Control
# -------------------------------------------------------------
# You need to decide which physical buttons map to which game functions.
# I'll map BTN[0] to UP, BTN[1] to DOWN, BTNX4 to LEFT,
# and use switches for RIGHT, START/PAUSE, and RESET.
# Please adjust these to match your board and preferences.

# Example mapping:
# BTN[0] as UP
set_property PACKAGE_PIN AF10 [get_ports btn_up_raw_in]
set_property IOSTANDARD LVCMOS15 [get_ports btn_up_raw_in]

# BTN[1] as DOWN
set_property PACKAGE_PIN AF13 [get_ports btn_down_raw_in]
set_property IOSTANDARD LVCMOS15 [get_ports btn_down_raw_in]

# BTNX4 as LEFT (or another button if you prefer)
set_property PACKAGE_PIN AE13 [get_ports btn_left_raw_in]
set_property IOSTANDARD LVCMOS15 [get_ports btn_left_raw_in]

# Using a switch (e.g., SW[0]) for RIGHT
set_property PACKAGE_PIN AF8 [get_ports btn_right_raw_in]
set_property IOSTANDARD LVCMOS15 [get_ports btn_right_raw_in]

# Using a switch (e.g., SW[1]) for START/PAUSE
set_property PACKAGE_PIN AB10 [get_ports btn_start_pause_raw_in]
set_property IOSTANDARD LVCMOS15 [get_ports btn_start_pause_raw_in]

# Using a switch (e.g., SW[2]) for GAME RESET
# This will be your active-low physical reset button if connected to sys_reset_n
# If you have a dedicated reset button (like RSTN W13 in the commented section), use that instead.
# For now, assuming one of the switches acts as a global reset for the logic.
# However, it's better to have a dedicated reset button mapped to your top-level 'sys_reset_n'.
# Let's assume you have a dedicated active-low reset button on pin W13 (from commented section):
set_property PACKAGE_PIN W13 [get_ports sys_reset_n]
set_property IOSTANDARD LVCMOS18 [get_ports sys_reset_n]
# If you use a switch for game logic reset (via input_handler), use its pin, for example:
set_property PACKAGE_PIN AA13 [get_ports btn_game_reset_raw_in]
set_property IOSTANDARD LVCMOS15 [get_ports btn_game_reset_raw_in]


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

# VGA Red (4-bit) - Assuming port names vga_r_out[3:0]
set_property PACKAGE_PIN N21 [get_ports {vga_r_out[0]}]
set_property PACKAGE_PIN N22 [get_ports {vga_r_out[1]}]
set_property PACKAGE_PIN R21 [get_ports {vga_r_out[2]}]
set_property PACKAGE_PIN P21 [get_ports {vga_r_out[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r_out[*]}]

# VGA Green (4-bit) - Assuming port names vga_g_out[3:0]
set_property PACKAGE_PIN R22 [get_ports {vga_g_out[0]}]
set_property PACKAGE_PIN R23 [get_ports {vga_g_out[1]}]
set_property PACKAGE_PIN T24 [get_ports {vga_g_out[2]}]
set_property PACKAGE_PIN T25 [get_ports {vga_g_out[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g_out[*]}]

# VGA Blue (4-bit) - Assuming port names vga_b_out[3:0]
set_property PACKAGE_PIN T20 [get_ports {vga_b_out[0]}]
set_property PACKAGE_PIN R20 [get_ports {vga_b_out[1]}]
set_property PACKAGE_PIN T22 [get_ports {vga_b_out[2]}]
set_property PACKAGE_PIN T23 [get_ports {vga_b_out[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b_out[*]}]

# VGA Sync Signals - Assuming port names vga_hs_out and vga_vs_out
set_property PACKAGE_PIN M22 [get_ports vga_hs_out]
set_property PACKAGE_PIN M21 [get_ports vga_vs_out]
set_property IOSTANDARD LVCMOS33 [get_ports vga_hs_out]
set_property IOSTANDARD LVCMOS33 [get_ports vga_vs_out]

# -------------------------------------------------------------
# 4. Seven Segment Display (Score & Game State)
# -------------------------------------------------------------
# Using the "Arduino-Segment & AN" pins from your file.
# Assumes your top module has 'seg_an_out[7:0]' and 'seg_data_out[7:0]'
# Your display_driver_basic uses 4 anodes, so AN[3:0] will be used.

# Anode selection (assuming 4 active low anodes for 4 digits from display_driver_basic)
# Your display_driver_basic maps its 4-bit AN to seg_an_out[3:0]
# and sets seg_an_out[7:4] to 4'b1111 (disabled).
set_property PACKAGE_PIN AD21 [get_ports {seg_an_out[0]}]  
set_property PACKAGE_PIN AC21 [get_ports {seg_an_out[1]}]  
set_property PACKAGE_PIN AB21 [get_ports {seg_an_out[2]}]
set_property PACKAGE_PIN AC22 [get_ports {seg_an_out[3]}]  
# If you use all 8 anodes, uncomment and map these:
# set_property PACKAGE_PIN PinX1 [get_ports {seg_an_out[4]}] // AN4
# set_property PACKAGE_PIN PinX2 [get_ports {seg_an_out[5]}] // AN5
# set_property PACKAGE_PIN PinX3 [get_ports {seg_an_out[6]}] // AN6
# set_property PACKAGE_PIN PinX4 [get_ports {seg_an_out[7]}] // AN7
set_property IOSTANDARD LVCMOS33 [get_ports {seg_an_out[*]}]

# Segment data (a-g, dp) - Assuming common anode display (segments active low)
set_property PACKAGE_PIN AB22 [get_ports {seg_data_out[0]}] 
set_property PACKAGE_PIN AD24 [get_ports {seg_data_out[1]}] 
set_property PACKAGE_PIN AD23 [get_ports {seg_data_out[2]}]
set_property PACKAGE_PIN Y21  [get_ports {seg_data_out[3]}] 
set_property PACKAGE_PIN W20  [get_ports {seg_data_out[4]}] 
set_property PACKAGE_PIN AC24 [get_ports {seg_data_out[5]}] 
set_property PACKAGE_PIN AC23 [get_ports {seg_data_out[6]}]
set_property PACKAGE_PIN AA22 [get_ports {seg_data_out[7]}] 
set_property IOSTANDARD LVCMOS33 [get_ports {seg_data_out[*]}]

# -------------------------------------------------------------
# 5. LEDs (Game State or Custom Pattern)
# -------------------------------------------------------------
# Assuming your top module has 'led_out[7:0]'
# I'll use the 'ard_led' pins from your provided file as an example.
# You might have dedicated LEDs on different pins.

set_property PACKAGE_PIN AF24 [get_ports {led_out[0]}]
set_property PACKAGE_PIN AE21 [get_ports {led_out[1]}]
set_property PACKAGE_PIN Y22  [get_ports {led_out[2]}]
set_property PACKAGE_PIN Y23  [get_ports {led_out[3]}]
set_property PACKAGE_PIN AA23 [get_ports {led_out[4]}]
set_property PACKAGE_PIN Y25  [get_ports {led_out[5]}]
set_property PACKAGE_PIN AB26 [get_ports {led_out[6]}]
set_property PACKAGE_PIN W23  [get_ports {led_out[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_out[*]}]

# -------------------------------------------------------------
# Buzzer Output (蜂鸣器输出)
# -------------------------------------------------------------
set_property PACKAGE_PIN P26 [get_ports buzzer_physical_out]
set_property IOSTANDARD LVCMOS33 [get_ports buzzer_physical_out]


# =============================================================
# End of Constraints
# =============================================================