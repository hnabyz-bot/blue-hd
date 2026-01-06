
#==============================================================================
# Timing Constraints
#==============================================================================

# System Clock (50 MHz input)
create_clock -period 20.000 -name MCLK_50M [get_ports MCLK_50M_p]

# Generated Clocks (from Clock Wizard)
# These will be automatically derived by Vivado from Clock Wizard

# AFE2256 LVDS DCLK clocks (14 channels)
# Assuming 2.34 MHz DCLK (MCLK=10MHz, STR=1024)
create_clock -period 427.350 -name DCLK_CH0 [get_ports DCLKP[0]]
create_clock -period 427.350 -name DCLK_CH1 [get_ports DCLKP[1]]
create_clock -period 427.350 -name DCLK_CH2 [get_ports DCLKP[2]]
create_clock -period 427.350 -name DCLK_CH3 [get_ports DCLKP[3]]
create_clock -period 427.350 -name DCLK_CH4 [get_ports DCLKP[4]]
create_clock -period 427.350 -name DCLK_CH5 [get_ports DCLKP[5]]
create_clock -period 427.350 -name DCLK_CH6 [get_ports DCLKP[6]]
create_clock -period 427.350 -name DCLK_CH7 [get_ports DCLKP[7]]
create_clock -period 427.350 -name DCLK_CH8 [get_ports DCLKP[8]]
create_clock -period 427.350 -name DCLK_CH9 [get_ports DCLKP[9]]
create_clock -period 427.350 -name DCLK_CH10 [get_ports DCLKP[10]]
create_clock -period 427.350 -name DCLK_CH11 [get_ports DCLKP[11]]
create_clock -period 427.350 -name DCLK_CH12 [get_ports DCLKP_12_13[12]]
create_clock -period 427.350 -name DCLK_CH13 [get_ports DCLKP_12_13[13]]

# LVDS Input Delays (relative to DCLK)
# Setup/Hold margins for LVDS data
set_input_delay -clock DCLK_CH0 -max 1.5 [get_ports DOUTP[0]]
set_input_delay -clock DCLK_CH0 -min -1.0 [get_ports DOUTP[0]]
set_input_delay -clock DCLK_CH0 -max 1.5 [get_ports DOUTN[0]]
set_input_delay -clock DCLK_CH0 -min -1.0 [get_ports DOUTN[0]]

# Note: Repeat for all 14 channels (simplified here for brevity)
# In production, use a loop in TCL

# Clock Domain Crossing (CDC) constraints
# DCLK -> clk_100mhz async
set_clock_groups -asynchronous \
    -group [get_clocks DCLK_CH*] \
    -group [get_clocks clk_100mhz]

# False Paths
# SPI control signals are quasi-static
set_false_path -from [get_ports nRST]

# Clock Routing
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets U8_r/g_dclk_int_*]
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets clk_inst0/inst/clk_in1_clk_ctrl]

# pin map

#i2c
set_property PACKAGE_PIN N15 [get_ports scl_out]
set_property PACKAGE_PIN R17 [get_ports sda]
set_property IOSTANDARD LVCMOS25 [get_ports scl_out]
set_property IOSTANDARD LVCMOS25 [get_ports sda]
##

set_property PACKAGE_PIN T20 [get_ports nRST]
set_property IOSTANDARD LVCMOS25 [get_ports nRST]

#
set_property PACKAGE_PIN L3 [get_ports MCLK_50M_p]
set_property PACKAGE_PIN K3 [get_ports MCLK_50M_n]
set_property IOSTANDARD LVDS_25 [get_ports MCLK_50M_p]
set_property IOSTANDARD LVDS_25 [get_ports MCLK_50M_n]

# ROIC INTERFACE RIGHT

set_property PACKAGE_PIN U21 [get_ports ROIC_TP_SEL]
set_property PACKAGE_PIN P19 [get_ports ROIC_SYNC]
set_property IOSTANDARD LVCMOS25 [get_ports ROIC_TP_SEL]
set_property IOSTANDARD LVCMOS25 [get_ports ROIC_SYNC]

# ROIC SPI
set_property PACKAGE_PIN W21 [get_ports ROIC_SPI_SCK]
set_property PACKAGE_PIN W22 [get_ports ROIC_SPI_SDI]
set_property PACKAGE_PIN AA20 [get_ports ROIC_SPI_SDO]
set_property PACKAGE_PIN Y22 [get_ports ROIC_SPI_SEN_N]
set_property IOSTANDARD LVCMOS25 [get_ports ROIC_SPI_SCK]
set_property IOSTANDARD LVCMOS25 [get_ports ROIC_SPI_SDI]
set_property IOSTANDARD LVCMOS25 [get_ports ROIC_SPI_SDO]
set_property IOSTANDARD LVCMOS25 [get_ports ROIC_SPI_SEN_N]

# GATE DRIVE
set_property PACKAGE_PIN Y18 [get_ports GF_STV_L]
set_property PACKAGE_PIN Y19 [get_ports GF_STV_LR1]
set_property PACKAGE_PIN V18 [get_ports GF_STV_LR2]
set_property PACKAGE_PIN V19 [get_ports GF_STV_LR3]
set_property PACKAGE_PIN AA19 [get_ports GF_STV_LR4]
set_property PACKAGE_PIN AB20 [get_ports GF_STV_LR5]
set_property PACKAGE_PIN V17 [get_ports GF_STV_LR6]
set_property PACKAGE_PIN W17 [get_ports GF_STV_LR7]
set_property PACKAGE_PIN AA18 [get_ports GF_STV_LR8]
set_property PACKAGE_PIN U17 [get_ports GF_STV_R]

set_property IOSTANDARD LVCMOS25 [get_ports GF_STV_L]
set_property IOSTANDARD LVCMOS25 [get_ports GF_STV_LR1]
set_property IOSTANDARD LVCMOS25 [get_ports GF_STV_LR2]
set_property IOSTANDARD LVCMOS25 [get_ports GF_STV_LR3]
set_property IOSTANDARD LVCMOS25 [get_ports GF_STV_LR4]
set_property IOSTANDARD LVCMOS25 [get_ports GF_STV_LR5]
set_property IOSTANDARD LVCMOS25 [get_ports GF_STV_LR6]
set_property IOSTANDARD LVCMOS25 [get_ports GF_STV_LR7]
set_property IOSTANDARD LVCMOS25 [get_ports GF_STV_LR8]
set_property IOSTANDARD LVCMOS25 [get_ports GF_STV_R]
#
set_property PACKAGE_PIN P16 [get_ports GF_CPV]
set_property PACKAGE_PIN N14 [get_ports GF_OE]
set_property IOSTANDARD LVCMOS25 [get_ports GF_CPV]
set_property IOSTANDARD LVCMOS25 [get_ports GF_OE]
#

#set_property PACKAGE_PIN U18 [get_ports GF_XAO_0]
set_property PACKAGE_PIN U18 [get_ports GF_XAO_1]
set_property PACKAGE_PIN P14 [get_ports GF_XAO_2]
set_property PACKAGE_PIN R14 [get_ports GF_XAO_3]
set_property PACKAGE_PIN R18 [get_ports GF_XAO_4]
set_property PACKAGE_PIN T18 [get_ports GF_XAO_5]
set_property PACKAGE_PIN N17 [get_ports GF_XAO_6]
set_property PACKAGE_PIN P17 [get_ports GF_XAO_7]
set_property PACKAGE_PIN P15 [get_ports GF_XAO_8]
#set_property PACKAGE_PIN R16 [get_ports GF_XAO_9]
#set_property IOSTANDARD LVCMOS25 [get_ports GF_XAO_0]
set_property IOSTANDARD LVCMOS25 [get_ports GF_XAO_1]
set_property IOSTANDARD LVCMOS25 [get_ports GF_XAO_2]
set_property IOSTANDARD LVCMOS25 [get_ports GF_XAO_3]
set_property IOSTANDARD LVCMOS25 [get_ports GF_XAO_4]
set_property IOSTANDARD LVCMOS25 [get_ports GF_XAO_5]
set_property IOSTANDARD LVCMOS25 [get_ports GF_XAO_6]
set_property IOSTANDARD LVCMOS25 [get_ports GF_XAO_7]
set_property IOSTANDARD LVCMOS25 [get_ports GF_XAO_8]
#set_property IOSTANDARD LVCMOS25 [get_ports GF_XAO_9]

set_property PACKAGE_PIN T21 [get_ports ROIC_AVDD2]
set_property PACKAGE_PIN P20 [get_ports ROIC_AVDD1]
set_property IOSTANDARD LVCMOS25 [get_ports ROIC_AVDD2]
set_property IOSTANDARD LVCMOS25 [get_ports ROIC_AVDD1]

set_property PACKAGE_PIN F15 [get_ports ROIC_MCLK0]
set_property IOSTANDARD LVCMOS25 [get_ports ROIC_MCLK0]

# CPU TO FPGA
set_property PACKAGE_PIN H4 [get_ports SSB]
set_property PACKAGE_PIN G4 [get_ports SCLK]
set_property PACKAGE_PIN K4 [get_ports MOSI]
set_property PACKAGE_PIN J4 [get_ports MISO]

set_property IOSTANDARD LVCMOS25 [get_ports SSB]
set_property IOSTANDARD LVCMOS25 [get_ports SCLK]
set_property IOSTANDARD LVCMOS25 [get_ports MOSI]
set_property IOSTANDARD LVCMOS25 [get_ports MISO]

#
set_property PACKAGE_PIN J16 [get_ports STATE_LED1]
#set_property PACKAGE_PIN M1 [get_ports F_SPARE_06]
#set_property PACKAGE_PIN J4 [get_ports F_SPARE_05]
#set_property PACKAGE_PIN K4 [get_ports F_SPARE_04]
#set_property PACKAGE_PIN G4 [get_ports F_SPARE_03]
#set_property PACKAGE_PIN H4 [get_ports F_SPARE_02]
#set_property PACKAGE_PIN G3 [get_ports F_SPARE_01]
#set_property PACKAGE_PIN H3 [get_ports F_SPARE_00]
set_property PACKAGE_PIN M17 [get_ports STATE_LED2]
set_property IOSTANDARD LVCMOS25 [get_ports STATE_LED1]
set_property IOSTANDARD LVCMOS25 [get_ports STATE_LED2]

# RESERVED
set_property PACKAGE_PIN F4 [get_ports exp_ack]
set_property PACKAGE_PIN H3 [get_ports exp_req]
set_property PACKAGE_PIN G3 [get_ports prep_ack]
set_property PACKAGE_PIN L6 [get_ports prep_req]
# set_property PACKAGE_PIN J4 [get_ports cancel_req]
set_property IOSTANDARD LVCMOS25 [get_ports exp_ack]
set_property IOSTANDARD LVCMOS25 [get_ports exp_req]
set_property IOSTANDARD LVCMOS25 [get_ports prep_ack]
set_property IOSTANDARD LVCMOS25 [get_ports prep_req]

# RF R
set_property PACKAGE_PIN B21 [get_ports DCLKP_11]
set_property PACKAGE_PIN E19 [get_ports FCLKP_11]
set_property PACKAGE_PIN C22 [get_ports DOUTP_11]

set_property PACKAGE_PIN E21 [get_ports DCLKP_10]
set_property PACKAGE_PIN F16 [get_ports FCLKP_10]
set_property PACKAGE_PIN D20 [get_ports DOUTP_10]

set_property PACKAGE_PIN H20 [get_ports DCLKP_9]
set_property PACKAGE_PIN E22 [get_ports FCLKP_9]
set_property PACKAGE_PIN G21 [get_ports DOUTP_9]

set_property PACKAGE_PIN J14 [get_ports DCLKP_8]
set_property PACKAGE_PIN F13 [get_ports FCLKP_8]
set_property PACKAGE_PIN E16 [get_ports DOUTP_8]

set_property PACKAGE_PIN F18 [get_ports DCLKP_7]
set_property PACKAGE_PIN J19 [get_ports FCLKP_7]
set_property PACKAGE_PIN J20 [get_ports DOUTP_7]

set_property PACKAGE_PIN F19 [get_ports DCLKP_6]
set_property PACKAGE_PIN K17 [get_ports FCLKP_6]
set_property PACKAGE_PIN H17 [get_ports DOUTP_6]

set_property PACKAGE_PIN K13 [get_ports DCLKP_5]
set_property PACKAGE_PIN H13 [get_ports FCLKP_5]
set_property PACKAGE_PIN M13 [get_ports DOUTP_5]

set_property PACKAGE_PIN L14 [get_ports DCLKP_4]
set_property PACKAGE_PIN M15 [get_ports FCLKP_4]
set_property PACKAGE_PIN L16 [get_ports DOUTP_4]

set_property PACKAGE_PIN K18 [get_ports DCLKP_3]
set_property PACKAGE_PIN J22 [get_ports FCLKP_3]
set_property PACKAGE_PIN K21 [get_ports DOUTP_3]

set_property PACKAGE_PIN M21 [get_ports DCLKP_2]
set_property PACKAGE_PIN M18 [get_ports FCLKP_2]
set_property PACKAGE_PIN N18 [get_ports DOUTP_2]

set_property PACKAGE_PIN G15 [get_ports DCLKP_1]
set_property PACKAGE_PIN G17 [get_ports FCLKP_1]
set_property PACKAGE_PIN J15 [get_ports DOUTP_1]

set_property PACKAGE_PIN N22 [get_ports DCLKP_0]
set_property PACKAGE_PIN N20 [get_ports FCLKP_0]
set_property PACKAGE_PIN L19 [get_ports DOUTP_0]

# Add LVDS negative signals and channel 12-13
set_property PACKAGE_PIN A21 [get_ports DCLKN_11]
set_property PACKAGE_PIN D19 [get_ports FCLKN_11]
set_property PACKAGE_PIN B22 [get_ports DOUTN_11]

set_property PACKAGE_PIN D21 [get_ports DCLKN_10]
set_property PACKAGE_PIN E17 [get_ports FCLKN_10]
set_property PACKAGE_PIN C20 [get_ports DOUTN_10]

set_property PACKAGE_PIN G20 [get_ports DCLKN_9]
set_property PACKAGE_PIN D22 [get_ports FCLKN_9]
set_property PACKAGE_PIN G22 [get_ports DOUTN_9]

set_property PACKAGE_PIN H14 [get_ports DCLKN_8]
set_property PACKAGE_PIN F14 [get_ports FCLKN_8]
set_property PACKAGE_PIN D16 [get_ports DOUTN_8]

set_property PACKAGE_PIN E18 [get_ports DCLKN_7]
set_property PACKAGE_PIN H19 [get_ports FCLKN_7]
set_property PACKAGE_PIN J21 [get_ports DOUTN_7]

set_property PACKAGE_PIN F20 [get_ports DCLKN_6]
set_property PACKAGE_PIN J17 [get_ports FCLKN_6]
set_property PACKAGE_PIN H18 [get_ports DOUTN_6]

set_property PACKAGE_PIN K14 [get_ports DCLKN_5]
set_property PACKAGE_PIN G13 [get_ports FCLKN_5]
set_property PACKAGE_PIN L13 [get_ports DOUTN_5]

set_property PACKAGE_PIN L15 [get_ports DCLKN_4]
set_property PACKAGE_PIN M16 [get_ports FCLKN_4]
set_property PACKAGE_PIN K16 [get_ports DOUTN_4]

set_property PACKAGE_PIN K19 [get_ports DCLKN_3]
set_property PACKAGE_PIN H22 [get_ports FCLKN_3]
set_property PACKAGE_PIN K22 [get_ports DOUTN_3]

set_property PACKAGE_PIN L21 [get_ports DCLKN_2]
set_property PACKAGE_PIN L18 [get_ports FCLKN_2]
set_property PACKAGE_PIN N19 [get_ports DOUTN_2]

set_property PACKAGE_PIN G16 [get_ports DCLKN_1]
set_property PACKAGE_PIN G18 [get_ports FCLKN_1]
set_property PACKAGE_PIN H15 [get_ports DOUTN_1]

set_property PACKAGE_PIN M22 [get_ports DCLKN_0]
set_property PACKAGE_PIN M20 [get_ports FCLKN_0]
set_property PACKAGE_PIN L20 [get_ports DOUTN_0]

# Add channels 12-13
set_property PACKAGE_PIN Y9 [get_ports DCLKP_12]
set_property PACKAGE_PIN W9 [get_ports DCLKN_12]
set_property PACKAGE_PIN Y8 [get_ports FCLKP_12]
set_property PACKAGE_PIN Y7 [get_ports FCLKN_12]
set_property PACKAGE_PIN AA8 [get_ports DOUTP_12]
set_property PACKAGE_PIN AB8 [get_ports DOUTN_12]

set_property PACKAGE_PIN V9 [get_ports DCLKP_13]
set_property PACKAGE_PIN V8 [get_ports DCLKN_13]
set_property PACKAGE_PIN AB7 [get_ports FCLKP_13]
set_property PACKAGE_PIN AB6 [get_ports FCLKN_13]
set_property PACKAGE_PIN V7 [get_ports DOUTP_13]
set_property PACKAGE_PIN W7 [get_ports DOUTN_13]

# IOSTANDARD for all LVDS signals
set_property IOSTANDARD LVDS_25 [get_ports DCLKP_*]
set_property IOSTANDARD LVDS_25 [get_ports DCLKN_*]
set_property IOSTANDARD LVDS_25 [get_ports FCLKP_*]
set_property IOSTANDARD LVDS_25 [get_ports FCLKN_*]
set_property IOSTANDARD LVDS_25 [get_ports DOUTP_*]
set_property IOSTANDARD LVDS_25 [get_ports DOUTN_*]



# Set the bank voltage for IO Bank 35 to 1.8V by default.
#set_property IOSTANDARD LVCMOS18 [get_ports -of_objects [get_iobanks 35]]

# CSI2 MIPI pin map

# 1st
set_property PACKAGE_PIN B1 [get_ports mipi_phy_if_clk_hs_p]
set_property PACKAGE_PIN A1 [get_ports mipi_phy_if_clk_hs_n]
set_property IOSTANDARD LVDS_25 [get_ports mipi_phy_if_clk_hs_p]
set_property IOSTANDARD LVDS_25 [get_ports mipi_phy_if_clk_hs_n]

set_property PACKAGE_PIN G1 [get_ports {mipi_phy_if_data_hs_p[0]}]
set_property PACKAGE_PIN E2 [get_ports {mipi_phy_if_data_hs_p[1]}]
set_property PACKAGE_PIN E1 [get_ports {mipi_phy_if_data_hs_p[2]}]
set_property PACKAGE_PIN C2 [get_ports {mipi_phy_if_data_hs_p[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {mipi_phy_if_data_hs_p[*]}]

set_property PACKAGE_PIN F1 [get_ports {mipi_phy_if_data_hs_n[0]}]
set_property PACKAGE_PIN D2 [get_ports {mipi_phy_if_data_hs_n[1]}]
set_property PACKAGE_PIN D1 [get_ports {mipi_phy_if_data_hs_n[2]}]
set_property PACKAGE_PIN B2 [get_ports {mipi_phy_if_data_hs_n[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {mipi_phy_if_data_hs_n[*]}]

set_property PACKAGE_PIN F3 [get_ports mipi_phy_if_clk_lp_p]
set_property PACKAGE_PIN E3 [get_ports mipi_phy_if_clk_lp_n]
set_property IOSTANDARD LVCMOS25 [get_ports mipi_phy_if_clk_lp_p]
set_property IOSTANDARD LVCMOS25 [get_ports mipi_phy_if_clk_lp_n]

set_property PACKAGE_PIN J5 [get_ports {mipi_phy_if_data_lp_p[0]}]
set_property PACKAGE_PIN K2 [get_ports {mipi_phy_if_data_lp_p[1]}]
set_property PACKAGE_PIN H2 [get_ports {mipi_phy_if_data_lp_p[2]}]
set_property PACKAGE_PIN K1 [get_ports {mipi_phy_if_data_lp_p[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {mipi_phy_if_data_lp_p[*]}]

set_property PACKAGE_PIN H5 [get_ports {mipi_phy_if_data_lp_n[0]}]
set_property PACKAGE_PIN J2 [get_ports {mipi_phy_if_data_lp_n[1]}]
set_property PACKAGE_PIN G2 [get_ports {mipi_phy_if_data_lp_n[2]}]
set_property PACKAGE_PIN J1 [get_ports {mipi_phy_if_data_lp_n[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {mipi_phy_if_data_lp_n[*]}]


#SPI Flash memory set
set_property CONFIG_VOLTAGE 2.5 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

set_property BITSTREAM.CONFIG.USR_ACCESS TIMESTAMP [current_design]

