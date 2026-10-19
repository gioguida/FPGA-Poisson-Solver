CXX ?= g++
SV  ?= iverilog
VVP ?= vvp

CXXFLAGS = -O3
SVFLAGS  = -g2012

CPP_HEADERS = ../src/cpp/linalg.hpp ../src/cpp/data.hpp ../src/cpp/fixed.hpp

MUL_GENERATOR   = gen_fxp_mul_vectors
MUL_VECTOR_FILE = ../build/test_vectors/fxp_mul_Q8_24.hex
MUL_SIM         = fxp_mul_tb

AXPY_GENERATOR   = gen_fxp_axpy_vectors
AXPY_VECTOR_FILE = ../build/test_vectors/fxp_axpy_Q8_24.hex
AXPY_SIM         = fxp_axpy_tb

DOT_SIM = fxp_dot_tb

RAM_SIM = ram_tb

.PHONY: mul-vectors mul-test axpy-vectors axpy-test dot-test ram-test clean

# Multiplier test
mul-vectors: $(MUL_VECTOR_FILE)

$(MUL_GENERATOR): cpp/gen_fxp_mul_vectors.cpp $(CPP_HEADERS)
	$(CXX) $(CXXFLAGS) $< -o $@

$(MUL_VECTOR_FILE): $(MUL_GENERATOR)
	./$(MUL_GENERATOR) $@

$(MUL_SIM): ../src/rtl/fxp_mul.sv rtl/fxp_mul_tb.sv
	$(SV) $(SVFLAGS) $^ -o $@

mul-test: mul-vectors $(MUL_SIM)
	$(VVP) $(MUL_SIM)

# AXPY test
axpy-vectors: $(AXPY_VECTOR_FILE)

$(AXPY_GENERATOR): cpp/gen_fxp_axpy_vectors.cpp $(CPP_HEADERS)
	$(CXX) $(CXXFLAGS) $< -o $@

$(AXPY_VECTOR_FILE): $(AXPY_GENERATOR)
	./$(AXPY_GENERATOR) $@

$(AXPY_SIM): ../src/rtl/fxp_axpy.sv ../src/rtl/fxp_mul.sv \
	../src/rtl/fxp_add.sv rtl/fxp_axpy_tb.sv
	$(SV) $(SVFLAGS) $^ -o $@

axpy-test: axpy-vectors $(AXPY_SIM)
	$(VVP) $(AXPY_SIM)

# Dot-product test
$(DOT_SIM): ../src/rtl/fxp_dot.sv rtl/fxp_dot_tb.sv
	$(SV) $(SVFLAGS) $^ -o $@

dot-test: $(DOT_SIM)
	$(VVP) $(DOT_SIM)

# RAM test
$(RAM_SIM): ../src/rtl/ram.sv rtl/ram_tb.sv
	$(SV) $(SVFLAGS) $^ -o $@

ram-test: $(RAM_SIM)
	$(VVP) $(RAM_SIM)

clean:
	$(RM) $(MUL_GENERATOR) $(MUL_SIM) $(AXPY_GENERATOR) $(AXPY_SIM) \
		$(DOT_SIM) $(RAM_SIM) *.o
