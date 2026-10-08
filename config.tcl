# OpenLane / Yosys Synthesis Configuration for GarbleChip
set ::env(DESIGN_NAME) "garblechip"

# Source files
set ::env(VERILOG_FILES) [glob -nocomplain $::env(DESIGN_DIR)/src/*.v $::env(DESIGN_DIR)/*.v]

# Clock Configuration (50 MHz, period 20.0 ns)
set ::env(CLOCK_PORT) "clk"
set ::env(CLOCK_NET) "clk"
set ::env(CLOCK_PERIOD) "20.0"

# Synthesis Optimization
set ::env(SYNTH_STRATEGY) "AREA 0"
set ::env(FP_CORE_UTIL) 40
set ::env(PL_TARGET_DENSITY) 0.45
