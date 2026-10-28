SV ?= iverilog
SVFLAGS ?= -g2012 -Wall -Winfloop -pfileline=1
BUILD_DIR ?= ../../build/rtl-compile

ADD = fxp_add.sv
SUB = fxp_sub.sv
MUL = fxp_mul.sv
AXPY = fxp_axpy.sv $(MUL) $(ADD)
AXPY_MULTIPLEXED = fxp_axpy_multiplexed.sv $(MUL) $(ADD)
DOT = fxp_dot.sv
RAM = ram.sv
FETCH = stencil_neighborhood_fetch.sv
STENCIL = poisson_stencil.sv $(ADD) $(SUB)
ENGINE = poisson_stencil_engine.sv $(FETCH) $(STENCIL)
PASS = poisson_stencil_pass.sv $(ENGINE)

MODULES = fxp_add fxp_sub fxp_mul fxp_axpy fxp_axpy_multiplexed fxp_dot \
          ram stencil_neighborhood_fetch poisson_stencil \
          poisson_stencil_engine poisson_stencil_pass

.PHONY: all clean $(MODULES)

all: $(MODULES)

fxp_add: $(ADD)
fxp_sub: $(SUB)
fxp_mul: $(MUL)
fxp_axpy: $(AXPY)
fxp_axpy_multiplexed: $(AXPY_MULTIPLEXED)
fxp_dot: $(DOT)
ram: $(RAM)
stencil_neighborhood_fetch: $(FETCH)
poisson_stencil: $(STENCIL)
poisson_stencil_engine: $(ENGINE)
poisson_stencil_pass: $(PASS)

$(MODULES):
	@mkdir -p $(BUILD_DIR)
	$(SV) $(SVFLAGS) -s $@ -o $(BUILD_DIR)/$@.vvp $^

clean:
	$(RM) -r $(BUILD_DIR)
