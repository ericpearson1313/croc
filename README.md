# AoC 2025 Day-6 & Day-5 puzzle with verilog solution generation.

## Day 5 - Part 1

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

## Day 5 part 2

Added a 2nd synthesiable module to calculate part 2. It had an axi like interface to accept range pairs as write data. I then had 2 large ranks of registers
and did a merge sort by shifting the input ranges along a deep (200) register array which would do a merge sort with each cell as it passes. When done the shift registers would be loaded with a sum command which would cause the range values to be forwarded and summed at the end. So we are doing a O(NxN) merge sort,
but in O(N) time because we have N computational units. This can only be done for bounded N cases.

       day5_part2 i_dut_part2 (
                .clk ( clk ),
                .reset( reset ),
                .wdata( wdata ),
                .wvalid( wvalid ),
                .wready( wready ),
                .wlast( wlast ),
                .rdata( rdata ),
                .rvalid( rvalid )
        );



## Day 6 - Part 1 & 2

A plain system verilog testbench running a synthesizable verilog module. 
Only the following files are used:

    aoc_day6.sv - contains both testbench and compute module
	day6_puzzle.txt - puzzle text
	day6_run.sh  - everything to run the verilator simulation

The synthsizable verilog accept a wire rate byte stream of the puzzle text. It uses 4 memoryies to store each row of digits.
During the final operator row it reads the digit rows in parallel. It searches for the columns of blanks as sepators
converts the text to 4x4 arreay of BCD digits (horizontal for part1 and vertical for part 2). It then LSB justifes the
digits and converts them to integers and calculates the add and mult results. Based on the operator eith the add result or the multiplier result is added to the accumulator.

    module day6_parts (
            input logic clk,
            input logic reset,
            input logic part2,
            input logic [7:0] data,
            input logic valid, // Valid charcode
            output logic [63:0] sum // puzzle sum
        );

Two of these same blocks are instantiated to sove puzzzle 1 and 2 together.


    ...
    - V e r i l a t i o n   R e p o r t: Verilator 5.040 2025-08-30 rev v5.040
    - Verilator: Built from 0.000 MB sources in 0 modules, into 0.000 MB in 0 C++ files needing 0.000 MB
    - Verilator: Walltime 0.010 s (elab=0.000, cvt=0.000, bld=0.009); cpu 0.001 s on 4 threads; alloced 29.266 MB
    Reset done
    Day 6 Part 1 sum = 0x000005c4ee0cd3f4  (       6343365546996)
    Day 6 Part 2 sum = 0x00000a2102ba33c8  (      11136895955912)
    - aoc_day6.sv:88: Verilog $finish






