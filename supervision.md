# Path:
1. Freeze the arithmetic contract before writing datapath RTL. Spend perhaps an hour turning the C++ conclusions into a small explicit specification. For every quantity, write down raw width, fractional bits, signedness, multiplication intermediate width, rounding/truncation location, accumulator width, and overflow behavior. In particular, distinguish the 32-bit Q8.24 stored vector representation from widened products/reductions. This document becomes the contract between C++ and RTL. Do not rely on SystemVerilog's implicit width or signedness rules anywhere important.
2. Your first RTL module should be a pipelined fixed-point multiply/rescale, not CG. Conceptually,
   $$
   a,b\in Q8.24
   \longrightarrow
   64\text{-bit raw product}
   \longrightarrow
   \text{round/shift}
   \longrightarrow
   Q8.24.
   $$
   Give it a clock and a valid signal and make its latency explicit. Generate raw integer input/output vectors from C++ and write a self-checking testbench. Test positives, negatives, zero, $\pm1$ LSB, values near limits, and rounding boundaries. The course material's verification philosophy is the right one here: expected outputs should be generated and compared automatically; manually inspecting waveforms is not a verification methodology.
   Then synthesize this tiny module immediately. This matters especially because Q8.24 means a 32×32 multiplication. Your Zynq-7000's DSP48E1 contains a native 25×18 multiplier, so a full 32×32 product cannot simply be one DSP slice; Vivado must decompose it somehow. Do not change Q8.24 because of that yet. Measure the result: DSP count, LUTs, registers, and achievable timing. That is your first genuine numerical-hardware co-design datapoint.
3. Turn that primitive into a one-element vector datapath. The first useful kernel should essentially implement
   $$
   y_i = a_i + \gamma b_i.
   $$
   That single structure covers all three CG updates:
   $$
   x\leftarrow x+\alpha p,\qquad
   r\leftarrow r-\alpha Ap,\qquad
   p\leftarrow r+\beta p.
   $$
   Initially, do not connect it to BRAM. Let the testbench stream one element per cycle into it. After pipeline fill, your target should be one result per cycle.
   I would keep the interface minimal: fixed-latency valid_i → valid_o, rather than introducing arbitrary backpressure now. Your internal CG machine is deliberately deterministic, so you do not need full ready/valid machinery inside every arithmetic pipe yet.
4. Then implement the reduction engine. This is your first really interesting hardware block:
   $$
   \sum_{i=0}^{255} a_i b_i.
   $$
   Use exactly the widened accumulator format established by the C++ study. At this stage I would build a streaming MAC/reduction: accept one pair per cycle, multiply, accumulate, and emit one result after 256 terms plus pipeline overhead.
   This teaches an important distinction between pipeline throughput and loop-carried dependence. The multiplication can be deeply pipelined, but the accumulator is a recurrence. This is directly relevant to CG and is more educational than writing a generic adder tree immediately.
5. Only now read the memory section. Finish Section 7 of the SystemVerilog guide, then read just enough about Xilinx BRAM inference and synchronous read semantics to understand what RTL structures Vivado recognizes. Your own project plan already reserves the dedicated memory-resource study for the point at which stencil/vector storage becomes relevant.
   One rule worth knowing in advance: do not reset every word of a large vector memory. Reset control state; initialize algorithmic memory through normal writes. Coding giant synchronous reset loops is a common way to prevent useful BRAM inference.
6. Build the Poisson stencil as two conceptual layers. First make a tiny arithmetic core that receives
   $$
   p_C,p_L,p_R,p_U,p_D
   $$
   and computes
   $$
   Ap=4p_C-p_L-p_R-p_U-p_D.
   $$
   Verify that independently. Then solve the interesting problem: how to supply those five values from memory.
   I would actually permit two architectures here. A v0 stencil may use time-multiplexed memory accesses and take several cycles per grid point. It is simple and gives you a correct whole-system baseline. A subsequent v1 streaming stencil should use row/line buffering so that, after filling the pipeline, you can produce roughly one stencil value per cycle. Comparing those two implementations in latency/resources is exactly the sort of result that makes the final project technically convincing.
7. Implement scalar division separately, late rather than early. You need it only for
   $$
   \alpha=\frac{r^Tr}{p^TAp}, \qquad
   \beta=\frac{r_{\rm new}^Tr_{\rm new}}{r^Tr}.
   $$
   There is essentially no reason to build a high-throughput divider: each division happens only once per CG iteration and the second depends on results produced later. A single reused fixed-latency iterative divider is architecturally appropriate.
   There is also a useful simplification: for SPD $A$, the exact-arithmetic quantities $r^Tr$ and $p^TAp$ are nonnegative, with $p^TAp>0$ for $p\neq0$, so $\alpha$ and $\beta$ are nonnegative. If your fixed-point range study guarantees no pathological overflow, the scalar divider can therefore be unsigned internally. That is a design consequence of the mathematics, not merely an HDL trick.
8. Only after those blocks work should you implement one CG iteration. At that point the architecture becomes an RTL scheduling problem rather than a coding problem. The course's RTL decomposition is precisely the right mental model: datapaths perform the computations while an FSM generates their control signals.
   Your first architecture should probably be resource-shared, not maximally parallel. Reuse one vector arithmetic lane and one divider. Get a correct deterministic schedule. Then optimize.
The eventual iteration schedule I want you thinking toward is
$$
\boxed{
p
\rightarrow
Ap,\;p^TAp
\rightarrow
\alpha
\rightarrow
x,r,\;r_{\rm new}^Tr_{\rm new}
\rightarrow
\beta
\rightarrow
p_{\rm new}
}
$$
Notice the opportunities there. While producing $Ap$, you can eventually accumulate $p^TAp$ in the same pass. While producing $r_{\rm new}$, you can accumulate $r_{\rm new}^Tr_{\rm new}$. Those are good second-stage optimizations, because they eliminate entire memory traversals. I would not fuse them on day one; first prove each block separately.