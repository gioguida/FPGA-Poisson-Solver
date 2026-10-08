CXX     ?= g++
CXXFLAGS = -O3

SOURCES_SIM = src/cpp/walltime.cpp  tests/cpp/test_reference.cpp
HEADERS_SIM = src/cpp/walltime.hpp src/cpp/data.hpp src/cpp/linalg.hpp
OBJ_SIM     = src/cpp/walltime.o   tests/cpp/test_reference.o

SOURCES_BIN = data/generate_vectors.cpp data/sourcefield.cpp
HEADERS_BIN = data/sourcefield.hpp
OBJ_BIN = data/generate_vectors.o data/sourcefield.o

cpp: main

walltime.o: walltime.cpp walltime.hpp
	$(CXX) $(CXXFLAGS) -c $<

main.o: test_reference.cpp $(HEADERS_SIM)
	$(CXX) $(CXXFLAGS) -c $<

main: $(OBJ_SIM)
	$(CXX) $(CXXFLAGS) $(OBJ_SIM) -o $@


vectors: vectors

sourcefield.o: sourcefield.cpp sourcefield.hpp
	$(CXX) $(CXXFLAGS) -c $<

generate_vectors.o: generate_vectors.cpp $(HEADERS_BIN)
	$(CXX) $(CXXFLAGS) -c $<

vectors: $(OBJ_BIN)
	$(CXX) $(CXXFLAGS) $(OBJ_BIN) -o $@

.PHONY: clean
clean:
	$(RM) main $(OBJ_SIM) output.*
	$(RM) vectors $(OBJ_BIN)
