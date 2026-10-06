# FPGA Poisson-CG Accelerator — Project Plan

## 0. Project identity

**Working title:** Deterministic-Latency FPGA Poisson Solver  
**Primary target:** Zybo-class FPGA board  
**Primary HDL:** SystemVerilog  
**Reference software:** C++  
**Numerical method:** Matrix-free Conjugate Gradient (CG)  
**PDE:** 2D Poisson equation on a regular grid  
**Arithmetic:** Fixed point in the main RTL path  
**Primary objective:** Learn and demonstrate serious FPGA engineering through an end-to-end numerical accelerator.

This document is both:
- a human-readable roadmap for the project;
- the main technical context document for coding agents.

Agents should read this file before making architectural changes.

---

# 1. Project goal

Build a complete FPGA implementation of a bounded numerical solver:

$$
-\nabla^2 u(x,y) = f(x,y)
$$

on a rectangular 2D domain with simple Dirichlet boundary conditions, discretized on a regular grid with the standard five-point finite-difference stencil.

The resulting linear system

$$
A u = b
$$

is symmetric positive definite and is solved using the Conjugate Gradient method.

The FPGA implementation should eventually accept an input field $f$, solve for $u$, and return the solution field.

The main difficulty should come from FPGA design, not from mathematical complexity.

The final project must demonstrate:

- clean RTL architecture;
- pipelined arithmetic;
- fixed-point design;
- BRAM/register/DSP trade-offs;
- streaming and buffering;
- reduction trees;
- control/data-path separation;
- verification against a software reference;
- synthesis and place-and-route;
- timing closure;
- real hardware execution;
- quantitative latency, throughput, resource, and accuracy measurements.

---

# 2. What this project is not

The following are explicitly out of scope unless the core project is already complete:

- a general PDE framework;
- arbitrary meshes;
- finite elements;
- arbitrary sparse matrices;
- CSR/CSC sparse-matrix engines;
- multigrid;
- domain decomposition;
- arbitrary boundary-condition frameworks;
- multi-FPGA scaling;
- GPU comparison as a major research direction;
- high-level synthesis as the primary implementation method;
- ML-based solvers;
- a general linear algebra library.

The project should remain narrow enough that the implementation effort is concentrated on FPGA engineering.

---

# 3. Mathematical problem

Use a simple domain such as

$$
\Omega = [0,1]^2
$$

with homogeneous Dirichlet boundary conditions

$$
u = 0 \quad \text{on } \partial \Omega.
$$

For a regular grid with spacing $h$, use the standard five-point discretization:

$$
4u_{i,j}
-u_{i-1,j}
-u_{i+1,j}
-u_{i,j-1}
-u_{i,j+1}
=
h^2 f_{i,j}.
$$

Do not explicitly construct the sparse matrix in the FPGA implementation.

Instead, use a matrix-free stencil operator:

$$
(Ap)_{i,j}
=
4p_{i,j}
-p_{i-1,j}
-p_{i+1,j}
-p_{i,j-1}
-p_{i,j+1}.
$$

The exact sign/scaling convention must be fixed once in the software reference and then kept consistent everywhere.

---

# 4. Conjugate Gradient algorithm

Use the standard CG recurrence for SPD systems.

Given $x_0$:

$$
r_0 = b - A x_0,
$$

$$
p_0 = r_0.
$$

For each iteration $k$:

$$
\alpha_k =
\frac{r_k^T r_k}
{p_k^T A p_k},
$$

$$
x_{k+1} =
x_k + \alpha_k p_k,
$$

$$
r_{k+1} =
r_k - \alpha_k A p_k,
$$

$$
\beta_k =
\frac{r_{k+1}^T r_{k+1}}
{r_k^T r_k},
$$

$$
p_{k+1} =
r_{k+1} + \beta_k p_k.
$$

Start with a fixed iteration count $K$.

Only after the fixed-iteration implementation is correct should an adaptive stopping rule such as

$$
\|r_k\|_2 < \varepsilon
$$

be added.

Fixed iteration count is preferred initially because it provides deterministic latency.

---

# 5. Top-level architecture

The eventual architecture should conceptually resemble:

```text
Host / Zynq PS / STM32
        |
        v
Input / configuration interface
        |
        v
Field memory / BRAM banks
        |
        +--------------------+
        |                    |
        v                    v
Stencil engine          Vector engine
(A * p)                 AXPY / updates
        |                    |
        +---------+----------+
                  |
                  v
            Reduction engine
           dot products / norms
                  |
                  v
             CG controller
                  |
                  v
           Output field memory
                  |
                  v
              Host / PS
```

The architecture should remain modular.

The three main compute engines are:

1. **Stencil engine**
   - computes $A p$;
   - exploits the five-point grid structure;
   - uses line buffers or equivalent on-chip storage;
   - should avoid storing an explicit sparse matrix.

2. **Vector engine**
   - AXPY-like operations;
   - vector scaling and updates;
   - configurable coefficients;
   - designed for pipelined throughput.

3. **Reduction engine**
   - dot products;
   - norms;
   - partial sums;
   - pipelined reduction tree or equivalent architecture.

A separate **CG controller** coordinates dependencies between these engines.

---

# 6. Development principles

## 6.1 Reference-first

Every hardware block must have a software model or a clearly defined mathematical specification before RTL integration.

## 6.2 Verify before optimizing

Correctness first.

Only optimize:
- after a block passes tests;
- after interfaces are stable;
- after synthesis gives evidence of a real bottleneck.

## 6.3 Hardware difficulty should dominate

Avoid adding numerical sophistication that does not force meaningful FPGA design decisions.

## 6.4 No premature genericity

Do not build abstractions for arbitrary sparse matrices, arbitrary dimensions, or arbitrary PDEs before the bounded Poisson solver works end-to-end.

## 6.5 Measure everything

Performance claims must come from synthesis, place-and-route, simulation, or hardware measurements.

Do not report estimated Fmax or latency as measured results.

---

# 7. Milestone roadmap

## Milestone 0 — Repository and toolchain bring-up

### Goal
Create the clean project skeleton and prove the local FPGA toolchain works.

### Tasks
- initialize repository structure;
- add lint/test/simulation scripts;
- establish simulator choice;
- establish synthesis flow;
- compile and simulate one trivial SystemVerilog module;
- synthesize a trivial design for the target FPGA;
- document board part / device part / tool version.

### Exit criteria
- `make test` or equivalent runs at least one RTL test;
- synthesis runs successfully;
- toolchain commands are documented;
- no architecture work begins before this is stable.

---

## Milestone 1 — Floating-point C++ reference solver

### Goal
Create the golden numerical implementation.

### Tasks
- implement a regular-grid Poisson problem generator;
- implement matrix-free five-point stencil application;
- implement floating-point CG;
- add residual history;
- add known analytic/manufactured-solution test cases;
- verify convergence;
- export deterministic test vectors for RTL.

### Required outputs
- input field $f$;
- reference solution $u$;
- per-iteration scalar values when useful;
- vector snapshots for selected tiny grids;
- machine-readable test-vector format.

### Suggested first grids
- $4\times4$;
- $8\times8$;
- $16\times16$;
- larger grids later.

### Exit criteria
- reference solver is trusted;
- unit tests pass;
- known problems converge correctly;
- test vectors can be consumed by RTL tests.

---

## Milestone 2 — Fixed-point numerical study

### Goal
Choose an initial fixed-point representation based on evidence.

### Tasks
- implement a software fixed-point emulation layer;
- test candidate formats;
- evaluate overflow risk;
- evaluate quantization error;
- evaluate CG convergence degradation;
- inspect dynamic ranges of:
  - $x$;
  - $r$;
  - $p$;
  - $Ap$;
  - dot-product accumulators;
  - $\alpha$;
  - $\beta$.

### Candidate formats
Examples only:
- Q8.24;
- Q12.20;
- Q16.16.

Do not assume one is correct before testing.

### Important rule
Accumulator width may need to be wider than vector element width.

### Exit criteria
Document:
- chosen initial element format;
- accumulator format;
- scalar format;
- saturation or wrap policy;
- rounding policy;
- numerical error versus floating-point reference.

---

## Milestone 3 — RTL arithmetic primitives

### Goal
Build and verify the basic arithmetic building blocks.

### Modules
- fixed-point multiply;
- fixed-point add/subtract;
- scaling / rounding helper;
- optional saturating arithmetic helper;
- valid pipeline helper where needed.

### Tests
For each primitive:
- random vectors;
- edge values;
- signed values;
- overflow cases;
- comparison against software fixed-point model.

### Exit criteria
- all arithmetic primitives have automated tests;
- bit widths are explicit;
- no accidental implicit signed/unsigned conversions.

---

## Milestone 4 — Vector engine

### Goal
Implement a pipelined vector update engine.

Target operations include:

$$
y_i \leftarrow a x_i + y_i
$$

and the CG updates:

$$
x \leftarrow x + \alpha p
$$

$$
r \leftarrow r - \alpha Ap
$$

$$
p \leftarrow r + \beta p.
$$

### Engineering topics
- DSP inference;
- pipeline depth;
- initiation interval;
- valid/ready handling;
- memory read/write scheduling;
- parameterized vector width if useful.

### Exit criteria
- correct cycle-accurate RTL;
- randomized comparison against software;
- known latency documented;
- synthesis report collected.

---

## Milestone 5 — Reduction / dot-product engine

### Goal
Implement

$$
s = \sum_i x_i y_i.
$$

### Possible architecture
- parallel multipliers;
- pipelined reduction tree;
- widened accumulators;
- configurable degree of parallelism.

### Engineering topics
- adder-tree depth;
- accumulator width;
- throughput/area trade-off;
- deterministic latency;
- final scaling/rounding.

### Tests
- random vectors;
- small exact integer-like values;
- cancellation cases;
- maximum-magnitude cases.

### Exit criteria
- bit-accurate agreement with fixed-point reference;
- latency formula documented;
- synthesis/resource report collected.

---

## Milestone 6 — Matrix-free stencil engine

### Goal
Implement the five-point Poisson operator.

Compute:

$$
(Ap)_{i,j}
=
4p_{i,j}
-p_{i-1,j}
-p_{i+1,j}
-p_{i,j-1}
-p_{i,j+1}.
$$

### Preferred direction
Use streaming rows with line buffers / BRAM where practical.

### Engineering topics
- row buffering;
- neighborhood windows;
- BRAM inference;
- boundary handling;
- pipeline filling/flushing;
- valid generation;
- one-cell-per-cycle target if realistic.

### Avoid
- explicit sparse matrix storage;
- generic CSR logic.

### Exit criteria
- complete-grid output matches reference exactly in fixed-point arithmetic;
- boundaries are fully tested;
- pipeline latency is known;
- synthesis report collected.

---

## Milestone 7 — Memory subsystem

### Goal
Define a clean on-chip storage architecture for CG state.

State includes at least:
- $x$;
- $r$;
- $p$;
- $Ap$;
- $b$ or $f$ as needed.

### Questions to resolve
- single-port vs dual-port BRAM;
- number of banks;
- read/write conflicts;
- whether some vectors can be streamed instead of stored;
- whether ping-pong buffers are useful;
- maximum supported grid size on the target board.

### Exit criteria
- no unresolved memory-port conflict;
- memory map documented;
- BRAM usage estimated and verified by synthesis.

---

## Milestone 8 — One complete CG iteration

### Goal
Integrate all kernels to execute one mathematically correct CG iteration.

### Required sequence
Conceptually:
1. compute $Ap$;
2. compute $p^T Ap$;
3. obtain $\alpha$;
4. update $x$;
5. update $r$;
6. compute new $r^T r$;
7. obtain $\beta$;
8. update $p$.

### Important issue
Scalar division must be handled explicitly.

Possible implementation options:
- vendor divider IP;
- iterative divider;
- reciprocal approximation + multiply;
- software/PS-assisted scalar computation as a temporary bring-up step.

The final choice should be justified by latency, resource use, and project scope.

### Exit criteria
- one RTL CG iteration matches fixed-point software reference;
- controller state machine is documented;
- dependencies are explicit;
- no race conditions in memory accesses.

---

## Milestone 9 — Complete fixed-iteration solver

### Goal
Execute $K$ CG iterations fully in hardware.

### Tasks
- initialize vectors;
- iterate controller;
- expose iteration count;
- return solution vector/field;
- record total cycles.

### Exit criteria
For several small grids:
- output matches fixed-point reference;
- convergence trend is sensible;
- total latency is deterministic;
- latency formula is documented.

---

## Milestone 10 — End-to-end interface

### Goal
Load a problem, launch the solver, and retrieve the result.

### Preferred order
1. simulation-only memory initialization;
2. Zynq PS / AXI interface if convenient;
3. optionally STM32 link later.

### Possible host path
```text
PC
 |
 v
Zynq PS software
 |
 v
AXI / register interface
 |
 v
FPGA accelerator
```

### Optional later path
```text
STM32
 |
SPI / UART / other simple link
 |
FPGA
```

Do not add the STM32 before the FPGA solver works independently.

### Exit criteria
- problem data can be loaded without recompiling RTL;
- solver can be started via software;
- status/result can be read back.

---

## Milestone 11 — Board deployment

### Goal
Run the design on the physical FPGA.

### Tasks
- synthesize;
- place and route;
- generate bitstream;
- program board;
- execute deterministic test problems;
- compare output against software;
- capture cycle counts / hardware counters.

### Exit criteria
- real-board result matches reference within documented fixed-point tolerance;
- bitstream build is reproducible;
- exact FPGA clock frequency is documented.

---

## Milestone 12 — Timing closure and architecture optimization

### Goal
Turn the correct design into a strong FPGA engineering project.

### Measure
- critical path;
- Fmax;
- LUTs;
- FFs;
- BRAMs;
- DSPs;
- cycles per stencil;
- cycles per reduction;
- cycles per CG iteration;
- total solve latency;
- throughput where meaningful.

### Explore controlled trade-offs
Examples:
- arithmetic parallelism;
- reduction-tree width;
- vector-engine lane count;
- BRAM banking;
- pipeline depth;
- fixed-point width.

Only change one architectural factor at a time where possible.

### Exit criteria
- at least one documented optimization cycle:
  - baseline;
  - bottleneck identified;
  - architectural change;
  - measured consequence.

---

## Milestone 13 — Numerical/hardware co-design study

### Goal
Show the effect of arithmetic precision and hardware architecture together.

### Example comparison axes
- Q8.24 vs Q12.20 vs Q16.16;
- solution error;
- convergence rate;
- LUT/DSP cost;
- Fmax;
- total solve latency.

### Suggested numerical metric

$$
\frac{\|u_{\mathrm{FPGA}}-u_{\mathrm{ref}}\|_2}
{\|u_{\mathrm{ref}}\|_2}.
$$

Also consider residual norms.

### Exit criteria
Produce a small table/plot set showing meaningful accuracy-resource-latency trade-offs.

---

## Milestone 14 — Optional adaptive convergence mode

Only after the fixed-iteration solver is complete.

### Add
$$
\|r_k\| < \varepsilon
$$

or an equivalent residual-based stopping rule.

### Compare
- deterministic fixed-$K$ mode;
- adaptive variable-latency mode.

### Questions
- how much latency variation occurs?
- what is the accuracy gain?
- is the extra control worthwhile?

---

## Milestone 15 — Final portfolio packaging

### README should prominently show

1. problem statement;
2. architecture diagram;
3. end-to-end dataflow;
4. verification methodology;
5. synthesis results;
6. timing results;
7. measured board results;
8. numerical accuracy;
9. key design trade-offs;
10. concise instructions to reproduce simulation and synthesis.

### Final project should be interview-ready

You should be able to explain:
- why matrix-free;
- why fixed point;
- how the stencil is buffered;
- how reductions are implemented;
- where the critical path is;
- why the chosen pipeline depth exists;
- how memory conflicts were handled;
- how numerical precision was selected;
- how latency is computed;
- what changed after timing closure;
- what would change on a larger FPGA.

---

# 8. Verification strategy

Verification is a first-class part of the project.

## 8.1 Layers

### Unit level
Test each RTL primitive independently.

### Block level
Test:
- vector engine;
- reduction engine;
- stencil engine.

### Integration level
Test:
- one CG iteration;
- multiple CG iterations;
- complete solver.

### Hardware level
Test:
- known deterministic problems;
- randomized bounded problems where practical.

---

## 8.2 Golden models

Use two software references where useful:

1. floating-point mathematical reference;
2. bit-accurate fixed-point reference.

The RTL should be compared primarily against the bit-accurate fixed-point model.

The floating-point reference is used to quantify numerical degradation.

---

## 8.3 Required test categories

- deterministic hand-checkable tests;
- random tests;
- boundary tests;
- minimum/maximum representable values;
- zero field;
- simple symmetric fields;
- overflow-oriented tests;
- repeated regression tests.

---

# 9. Performance metrics

Every final performance claim should specify whether it comes from:

- RTL simulation;
- post-synthesis timing;
- post-route timing;
- physical-board measurement.

Record at minimum:

- clock frequency;
- Fmax;
- cycles per iteration;
- total solve cycles;
- end-to-end latency;
- initiation interval of major pipelines;
- grid size;
- iteration count;
- LUT use;
- FF use;
- BRAM use;
- DSP use;
- arithmetic format.

---

# 10. Suggested first target configuration

This is a bring-up configuration, not a permanent contract.

- grid: $8\times8$ or $16\times16$;
- homogeneous Dirichlet boundaries;
- zero initial guess;
- fixed number of CG iterations;
- one fixed-point format chosen from software evidence;
- simple on-chip BRAM storage;
- no external DRAM required initially;
- no STM32 initially;
- no generic sparse matrices;
- no adaptive convergence initially.

Scale only after correctness.

---

# 11. Main technical risks

## Risk 1 — Fixed-point CG instability
Mitigation:
- software fixed-point emulation before RTL;
- wider accumulators;
- controlled test problems;
- postpone aggressive bit-width reduction.

## Risk 2 — Division complexity
Mitigation:
- isolate scalar division behind a clear interface;
- begin with a simple correct implementation;
- optimize only later.

## Risk 3 — Memory-port conflicts
Mitigation:
- design memory schedule before full integration;
- bank vectors explicitly;
- document every simultaneous access.

## Risk 4 — Scope creep into numerical research
Mitigation:
- keep Poisson + regular grid + five-point stencil fixed;
- reject new PDE methods until core project is complete.

## Risk 5 — Building only simulation code
Mitigation:
- every major milestone after basic RTL should keep synthesis compatibility;
- board deployment is mandatory for project completion.

## Risk 6 — Over-optimizing too early
Mitigation:
- preserve a simple baseline;
- optimize only with evidence from synthesis/timing.

---

# 12. Definition of done

The core project is complete when all of the following are true:

- C++ floating-point reference exists and is tested;
- software fixed-point reference exists;
- vector engine is implemented and verified;
- dot-product/reduction engine is implemented and verified;
- matrix-free stencil engine is implemented and verified;
- complete CG controller is implemented;
- fixed-$K$ solver works end-to-end;
- input field can be loaded without editing RTL;
- output solution can be retrieved;
- design runs on the real FPGA board;
- post-route timing is clean at the chosen operating frequency;
- FPGA output agrees with the fixed-point model;
- numerical error relative to floating point is quantified;
- resource usage is documented;
- end-to-end latency is measured;
- at least one architecture optimization is justified quantitatively;
- repository can reproduce simulation and synthesis from documented commands.

---

# 13. Stretch goals

Only after the definition of done is satisfied:

- adaptive residual-based stopping;
- STM32 as an external producer/consumer;
- larger grids using external DDR;
- multiple parallel stencil/vector lanes;
- preconditioned CG;
- alternative numerical kernels;
- generic SPD matrix support;
- comparison against a CPU baseline;
- streaming multiple RHS problems;
- AXI-Stream interface;
- performance counters exposed to software.

Stretch goals must not destabilize the completed core design.

---

# 14. Immediate next actions

1. Create repository skeleton.
2. Confirm exact Zybo board/device and installed toolchain.
3. Implement C++ five-point stencil.
4. Implement C++ floating-point CG.
5. Add analytic/manufactured test case.
6. Create software fixed-point emulator.
7. Evaluate candidate Q formats.
8. Implement first RTL primitive.
9. Build automated RTL regression flow.
10. Proceed milestone by milestone.

Do not begin with the full solver RTL.

The intended progression is:

```text
reference math
    ->
fixed-point model
    ->
arithmetic primitives
    ->
vector engine
    ->
reduction engine
    ->
stencil engine
    ->
memory system
    ->
one CG iteration
    ->
full solver
    ->
hardware interface
    ->
board deployment
    ->
timing/resource optimization
```
