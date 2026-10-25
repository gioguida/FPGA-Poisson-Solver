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
DOT_GENERATOR = gen_fxp_dot_vectors
DOT_VECTOR_FILE = ../build/test_vectors/fxp_dot_Q8_24.hex

RAM_SIM = ram_tb

.PHONY: test mul-vectors mul-test axpy-test dot-vectors dot-test ram-test clean

test: mul-test axpy-test dot-test ram-test

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

# AXPY streaming test
$(AXPY_GENERATOR): cpp/gen_fxp_axpy_vectors.cpp
	$(CXX) $(CXXFLAGS) -std=c++17 $< -o $@

$(AXPY_VECTOR_FILE): $(AXPY_GENERATOR)
	./$(AXPY_GENERATOR) $@

axpy-vectors: $(AXPY_VECTOR_FILE)

$(AXPY_SIM): ../src/rtl/fxp_mul.sv ../src/rtl/fxp_add.sv ../src/rtl/fxp_axpy.sv rtl/fxp_axpy_tb.sv
	$(SV) $(SVFLAGS) $^ -o $@

axpy-test: axpy-vectors $(AXPY_SIM)
	$(VVP) $(AXPY_SIM)

# Dot-product test
$(DOT_GENERATOR): cpp/gen_fxp_dot_vectors.cpp
	$(CXX) $(CXXFLAGS) -std=c++17 $< -o $@

$(DOT_VECTOR_FILE): $(DOT_GENERATOR)
	./$(DOT_GENERATOR) $@

dot-vectors: $(DOT_VECTOR_FILE)

$(DOT_SIM): ../src/rtl/fxp_dot.sv rtl/fxp_dot_tb.sv
	$(SV) $(SVFLAGS) $^ -o $@

dot-test: dot-vectors $(DOT_SIM)
	$(VVP) $(DOT_SIM)

# RAM test
$(RAM_SIM): ../src/rtl/ram.sv rtl/ram_tb.sv
	$(SV) $(SVFLAGS) $^ -o $@

ram-test: $(RAM_SIM)
	$(VVP) $(RAM_SIM)

clean:
	$(RM) $(MUL_GENERATOR) $(MUL_SIM) $(AXPY_GENERATOR) $(AXPY_SIM) \
		$(DOT_GENERATOR) $(DOT_SIM) $(RAM_SIM) *.o
