CXX     ?= g++
CXXFLAGS = -O3

HEADERS = walltime.hpp data.hpp linalg.hpp
OBJ     = walltime.o    main.o

float: main_float

walltime.o: walltime.cpp walltime.hpp
	$(CXX) $(CXXFLAGS) -c $<

main.o: main.cpp $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $<

main_float: $(OBJ)
	$(CXX) $(CXXFLAGS) -DFLOAT_ $(OBJ) -o $@

fixed: main_fixed

main_fixed: $(OBJ)
	$(CXX) $(CXXFLAGS) -DFIXED_ $(OBJ) -o $@

.PHONY: clean
clean:
	$(RM) main_float main_fixed $(OBJ) output.*
