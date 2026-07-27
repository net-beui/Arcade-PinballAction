# Pinball Action MiSTer Core - supplemental timing constraints

# Let Quartus derive PLL output clocks from fitted PLLs.
derive_pll_clocks
derive_clock_uncertainty

# The framework sys_top.sdc already creates the board input clocks.
# Do not create CLK_50M here because TimeQuest reports no such top-level port.

# Group unrelated framework/core clocks using the exact clock names reported by TimeQuest.
set_clock_groups -asynchronous \
    -group [get_clocks -nowarn {emu|pll|pll_inst|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] \
    -group [get_clocks -nowarn {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}] \
    -group [get_clocks -nowarn {pll_audio|pll_audio_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] \
    -group [get_clocks -nowarn {FPGA_CLK1_50}] \
    -group [get_clocks -nowarn {FPGA_CLK2_50}] \
    -group [get_clocks -nowarn {FPGA_CLK3_50}] \
    -group [get_clocks -nowarn {sysmem|fpga_interfaces|clocks_resets|h2f_user0_clk}] \
    -group [get_clocks -nowarn {spi_sck}]

# Unused SDRAM pins are tied off in this core.
set_false_path -to   [get_ports -nowarn {SDRAM_*}]
set_false_path -from [get_ports -nowarn {SDRAM_*}]

# Framework-style output ports if present.
set_false_path -to [get_ports -nowarn {VGA_*}]
set_false_path -to [get_ports -nowarn {HDMI_*}]
set_false_path -to [get_ports -nowarn {AUDIO_*}]
set_false_path -to [get_ports -nowarn {LED_*}]

# Unused / framework-managed input ports
set_false_path -from [get_ports -nowarn {HDMI_I2C_SDA}]
set_false_path -from [get_ports -nowarn {HDMI_TX_INT}]
set_false_path -from [get_ports -nowarn {IO_SDA}]
set_false_path -from [get_ports -nowarn {SDCD_SPDIF}]

# Unused / framework-managed output or bidirectional ports
set_false_path -to [get_ports -nowarn {IO_SCL}]
set_false_path -to [get_ports -nowarn {IO_SDA}]
set_false_path -to [get_ports -nowarn {LED[*]}]
set_false_path -to [get_ports -nowarn {SDCD_SPDIF}]
set_false_path -to [get_ports -nowarn {SDIO_CLK}]
set_false_path -to [get_ports -nowarn {SDIO_CMD}]
set_false_path -to [get_ports -nowarn {SDIO_DAT[*]}]
set_false_path -to [get_ports -nowarn {SD_SPI_CS}]
set_false_path -to [get_ports -nowarn {USER_IO[*]}]