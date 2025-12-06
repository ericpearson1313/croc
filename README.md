
AoC 2025 Day-5 puzzle solution generation.

A plain system verilog testbench running a synthesizable verilog module.
Only the following files are used:

    aoc_day5.sv - contains both testbench and compute module
	day5_puzzle.txt - puzzle text
	day5_run.sh  - everything to run the verilator simulation

The synthsizable verilog compute module accepts wire rate data of either lower range, upper range or candidate.
I compares all canadidate against all ranges in a systolic pipeline and tracks if a candidate is valid in any of the ranges
and accumlates the puzzle sum. It is large (about 40K registers), but would fit in smallish 100KLE fpga if needed.

    module day5_part1 (
        input logic clk,
        input logic [63:0] din,
        input logic we_upper,   // write upper range
        input logic we_lower,   // write lower range
        input logic we_cand,    // write canadidate data
        output logic [31:0] hit_count // Count of candidates that fall in at least 1 range (Part 1)
        );

when run the puzzle sum is computed based on the puzzle data. The testbench reads the file and writes the 64bit BCD values ( ~200 lower-upper ranges and 1000 candidates) into the hardware pipeline. It gives the following output:

    ...
    Cand 0505254272953678
    end of file puzzle txt
    Day 5 part 1 =   770
    - aoc_day5.sv:116: Verilog $finish
    - S i m u l a t i o n   R e p o r t: Verilator 5.040 2025-08-30
    - Verilator: $finish at 62us; walltime 0.023 s; speed 2.695 ms/s
    - Verilator: cpu 0.023 s on 1 threads; alloced 31 MB

Done for now .... i'll need to think about how to solve part 2. Maybe later

The distributed croc readme follows. I used thsi repo because it had verilator.

