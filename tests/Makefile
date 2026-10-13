CXX     ?= g++
SV 		?= iverilog
# CXXFLAGS = -O0 -g -fno-omit-frame-pointer -fsanitize=undefined -fno-sanitize-recover=all
CXXFLAGS = -O3
SVFLAGS = -g2012

HEADERS = ../src/cpp/linalg.hpp ../src/cpp/data.hpp ../src/cpp/fixed.hpp

.PHONY: fxp_mul_vectors fxp_mul_tb clean

fxp_mul_vectors: gen_fxp_mul_vectors

gen_fxp_mul_vectors: cpp/gen_fxp_mul_vectors.cpp $(HEADERS)
	$(CXX) $(CXXFLAGS) $< -o $@


fxp_mul_tb: ../src/rtl/fxp_mul.sv rtl/fxp_mul_tb.sv
	$(SV) $(SVFLAGS) $^ -o $@

clean:
	$(RM) gen_fxp_mul_vectors fxp_mul_tb *.o
