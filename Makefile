CXX     ?= g++
CXXFLAGS = -O0 -g # -fno-omit-frame-pointer -fsanitize=undefined -fno-sanitize-recover=all

SOURCES_SIM = src/cpp/walltime.cpp	src/cpp/utils.cpp	src/cpp/main.cpp
HEADERS_SIM = src/cpp/walltime.hpp 	src/cpp/data.hpp 	src/cpp/linalg.hpp	src/cpp/utils.hpp	src/cpp/fixed.hpp
OBJ_SIM     = $(SOURCES_SIM:.cpp=.o)

SOURCES_BIN = scripts/generate_vectors.cpp src/cpp/utils.cpp src/cpp/sourcefield.cpp
HEADERS_BIN = src/cpp/sourcefield.hpp src/cpp/utils.hpp
OBJ_BIN     = $(SOURCES_BIN:.cpp=.o)

cpp: main

utils.o: utils.cpp $(HEADERS_SIM)
	$(CXX) $(CXXFLAGS) -c $<

walltime.o: walltime.cpp walltime.hpp
	$(CXX) $(CXXFLAGS) -c $<

main.o: main.cpp $(HEADERS_SIM)
	$(CXX) $(CXXFLAGS) -c $<

main: $(OBJ_SIM)
	$(CXX) $(CXXFLAGS) $(OBJ_SIM) -o $@


vectors: $(OBJ_BIN)
	$(CXX) $(CXXFLAGS) $(OBJ_BIN) -o $@

.PHONY: clean
clean:
	$(RM) main $(OBJ_SIM) output.*
	$(RM) vectors vectors.exe $(OBJ_BIN)
