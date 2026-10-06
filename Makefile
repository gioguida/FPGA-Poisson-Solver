CXX     ?= g++
CXXFLAGS = -O3

SOURCES = src/cpp/walltime.cpp src/cpp/data.cpp src/cpp/linalg.cpp src/cpp/main.cpp
HEADERS = src/cpp/walltime.hpp src/cpp/data.hpp src/cpp/linalg.hpp
OBJ     = src/cpp/walltime.o   src/cpp/data.o   src/cpp/linalg.o   src/cpp/main.o

cpp: main

walltime.o: walltime.cpp walltime.hpp
	$(CXX) $(CXXFLAGS) -c $<

stats.o: stats.cpp stats.hpp
	$(CXX) $(CXXFLAGS) -c $<

data.o: data.cpp data.hpp
	$(CXX) $(CXXFLAGS) -c $<

operators.o: operators.cpp operators.hpp
	$(CXX) $(CXXFLAGS) -c $<

linalg.o: linalg.cpp linalg.hpp
	$(CXX) $(CXXFLAGS) -c $<

main.o: main.cpp $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $<

main: $(OBJ)
	$(CXX) $(CXXFLAGS) $(OBJ) -o $@

.PHONY: clean
clean:
	$(RM) main $(OBJ) output.*
