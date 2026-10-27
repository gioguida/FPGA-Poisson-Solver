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
STENCIL_GENERATOR = ../build/tests/gen_fxp_stencil_vectors
STENCIL_VECTOR_FILE = ../build/test_vectors/fxp_stencil_Q8_8.hex

.PHONY: test mul-vectors mul-test axpy-test dot-vectors dot-test ram-test stencil-fetch-test stencil-vectors stencil-engine-test clean

test: mul-test axpy-test dot-test ram-test stencil-fetch-test stencil-engine-test

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

# Packed RAM neighborhood fetch, including all boundaries and lane positions.
stencil-fetch-test:
	mkdir -p ../build/tests
	@set -e; for lanes in 2 4 8; do \
		$(SV) $(SVFLAGS) -s stencil_neighborhood_fetch_tb \
			-Pstencil_neighborhood_fetch_tb.LANES=$$lanes \
			../src/rtl/ram.sv ../src/rtl/stencil_neighborhood_fetch.sv \
			rtl/stencil_neighborhood_fetch_tb.sv \
			-o ../build/tests/stencil_neighborhood_fetch_$$lanes.vvp; \
		$(VVP) ../build/tests/stencil_neighborhood_fetch_$$lanes.vvp; \
	done

# Complete point stencil: packed RAM fetch, arithmetic, coordinates, and handshake.
$(STENCIL_GENERATOR): cpp/gen_fxp_stencil_vectors.cpp $(CPP_HEADERS)
	mkdir -p ../build/tests
	$(CXX) $(CXXFLAGS) -std=c++17 $< -o $@

$(STENCIL_VECTOR_FILE): $(STENCIL_GENERATOR)
	mkdir -p ../build/test_vectors
	$(STENCIL_GENERATOR) $@

stencil-vectors: $(STENCIL_VECTOR_FILE)

stencil-engine-test: stencil-vectors
	mkdir -p ../build/tests
	@set -e; for lanes in 2 4 8; do \
		$(SV) $(SVFLAGS) -s poisson_stencil_engine_tb \
			-Ppoisson_stencil_engine_tb.LANES=$$lanes \
			../src/rtl/ram.sv ../src/rtl/stencil_neighborhood_fetch.sv \
			../src/rtl/fxp_add.sv ../src/rtl/fxp_sub.sv \
			../src/rtl/poisson_stencil.sv ../src/rtl/poisson_stencil_engine.sv \
			rtl/poisson_stencil_engine_tb.sv \
			-o ../build/tests/poisson_stencil_engine_$$lanes.vvp; \
		$(VVP) ../build/tests/poisson_stencil_engine_$$lanes.vvp; \
	done

clean:
	$(RM) $(MUL_GENERATOR) $(MUL_SIM) $(AXPY_GENERATOR) $(AXPY_SIM) \
		$(DOT_GENERATOR) $(DOT_SIM) $(RAM_SIM) *.o
