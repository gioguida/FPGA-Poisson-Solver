CXX     ?= g++
CXXFLAGS = -O3

SOURCES = src/cpp/walltime.cpp  tests/cpp/test_reference.cpp
HEADERS = src/cpp/walltime.hpp src/cpp/data.hpp src/cpp/linalg.hpp
OBJ     = src/cpp/walltime.o   tests/cpp/test_reference.o

cpp: main

walltime.o: walltime.cpp walltime.hpp
	$(CXX) $(CXXFLAGS) -c $<

main.o: test_reference.cpp $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $<

main: $(OBJ)
	$(CXX) $(CXXFLAGS) $(OBJ) -o $@

.PHONY: clean
clean:
	$(RM) main $(OBJ) output.*
