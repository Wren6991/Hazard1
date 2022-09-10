TOP     := tb
DOTF    := tb.f
SCRIPTS := ../../../scripts

.PHONY: clean all
all: tb

SYNTH_CMD += read_verilog -I ../../../hdl $(shell $(SCRIPTS)/listfiles $(DOTF));
SYNTH_CMD += hierarchy -top $(TOP);
SYNTH_CMD += write_cxxrtl dut.cpp

dut.cpp: $(shell $(SCRIPTS)/listfiles $(DOTF))
	yosys -p "$(SYNTH_CMD)" 2>&1 > cxxrtl.log

clean::
	rm -f dut.cpp cxxrtl.log tb

tb: dut.cpp tb.cpp
	clang++ -O3 -std=c++14 $(addprefix -D,$(CDEFINES)) -I $(shell yosys-config --datdir)/include tb.cpp -o tb
