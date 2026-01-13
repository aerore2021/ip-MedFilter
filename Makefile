# Verilog Simulation Makefile
# Using Icarus Verilog and VVP

VERILOG_FILES = file.f
MODULE_NAME = tb_MedFilt
OUTPUT_NAME = tb_MedFilt

.PHONY: all compile simulate view clean

all: compile simulate view

compile:
	iverilog -g2012 -o $(OUTPUT_NAME).vvp -f $(VERILOG_FILES)
	@echo "[OK] Compilation done: $(OUTPUT_NAME).vvp"

simulate: compile
	vvp $(OUTPUT_NAME).vvp
	@echo "[OK] Simulation done: $(OUTPUT_NAME).vcd"

view: simulate
	gtkwave $(OUTPUT_NAME).vcd &
	@echo "[OK] Waveform viewer opened"

clean:
	rm -f $(OUTPUT_NAME).vvp $(OUTPUT_NAME).vcd
	@echo "[OK] Clean done"

help:
	@echo "Available commands:"
	@echo "  make         - Compile + Simulate + View (full flow)"
	@echo "  make compile - Compile only"
	@echo "  make simulate- Compile and simulate"
	@echo "  make view    - View waveform"
	@echo "  make clean   - Clean generated files"
