
# AoC 2025 Day-12 Part 1 puzzle solution generation in verilog.

This looked to be an incredibly difficult task. It made me wonder about the spirit of the season, so I honestly figured santa would want everyone to have a tree so immediately put in a guess of 1000 (all the tree can fit the presents).

I wasn't sure how to solve this type of puzzle efficiently, but I wanted to eliminate the non-viable cases first, where the area of the required presents was greater in area than the specified region under the tree. After caculating the number of basic viable tree my spritis were raised when it suceeded for part 1. Thanks Santa.

In a familiar structure the behavioral test bench reads in the puzzle file, and write the data to a 9 bit port on the hardware, classifying each
write with a user feild (0-puzzle peice, 1-width/height, 2-presents required). The written data was shifted into appropriate registers and the 1st order viability
calculated (dot product) and declared viable if the total area of the needed puzzle pieces could fit in the region under the tree.

	aoc_day12.sv - Contains a verilog behavioral testbench and sythesizeable compute module
	day12_puzzle.txt - puzzle text
	day12_run.sh  - everything to compile and run the c code to generate verilog and run the verilator simulation

After writing the entire puzzle into the hardare, the sums (#trees and #viable) are read and displayed by the testbench

	...
    - V e r i l a t i o n   R e p o r t: Verilator 5.040 2025-08-30 rev v5.040
    - Verilator: Built from 0.000 MB sources in 0 modules, into 0.000 MB in 0 C++ files needing 0.000 MB
    - Verilator: Walltime 0.008 s (elab=0.000, cvt=0.000, bld=0.007); cpu 0.001 s on 4 threads; alloced 29.340 MB
    Reset done
    Reading puzzle peices
    Read Trees to be checked for present fit
    Total Trees = 1000
    Min Feasible Trees =  524
    - aoc_day12.sv:152: Verilog $finish



