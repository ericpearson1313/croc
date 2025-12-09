
# AoC 2025 Day-9 puzzle solution generation in verilog.

## Part 1

This is a synthesizable verilog module to solve Day 9 part 1
It was quite straight forward solve with a full search of red point-pairs maintaing max area.
Leads itself to straight forward HW. ts quite small and takes 500 cycles to load the data but over 100K cycles to solve. 

    aoc_day9.sv - Contains a verilog behavioral testbench and sythesizeable compute module
	day9part1.c - quick solve of part 1 to get too part 2
	day9_puzzle.txt - puzzle text
	day9_run.sh  - everything to run the verilator simulation

The behvioral code a) reads the red cell X,Y corrds and send to DUT each cycle sequenctially, 
The hardware verilog writes 2 copies of the XY pairs to rams, and then using a pair of counter does the full scan of all possible pairs 
of coordinates, calculates the area and accumulates the maximum area and when complete asserts done, for reporting the max.

	...
    - V e r i l a t i o n   R e p o r t: Verilator 5.040 2025-08-30 rev v5.040
    - Verilator: Built from 0.000 MB sources in 0 modules, into 0.000 MB in 0 C++ files needing 0.000 MB
    - Verilator: Walltime 0.009 s (elab=0.000, cvt=0.000, bld=0.009); cpu 0.001 s on 4 threads; alloced 29.270 MB
    Reset done
    Day 9 Part 1 Max Area =  4735268538
    - aoc_day9.sv:97: Verilog $finish
    - S i m u l a t i o n   R e p o r t: Verilator 5.040 2025-08-30
    - Verilator: $finish at 2ms; walltime 0.201 s; speed 6.303 ms/s
    - Verilator: cpu 0.391 s on 1 threads; alloced 503 MB

## Part 2

Part 2 was a bit different and appeared daunting (especially compated to part1).
On this one I scatter plotted the data and was able to work out the solution. Due to the shape of the outline, one of two red cells had to be the
corner of the solution, and by zooming in of the scatter plot with a bit of paper and pencil, the opposite corner for these cases could be determined
by projecting and manually intersecting the boundary. It was just the matter of picking the larger of the two.

< insert diagram >

