
# AoC 2025 Day-10 puzzle solution generation in verilog.

## Part 1

This is a synthesizable verilog module to solve Day 10 part 1. Verilog seemed most straight forward to solve this using a large 16x10 XOR array to do the calculation
of the indicators vs buttons, and a counter to brute force each machines' solution., Eventually found my final typo and out popped the correct day 10 part 1 sum.


    aoc_day10.sv - Contains a verilog behavioral testbench and sythesizeable compute module
	day10_puzzle.txt - puzzle text
	day10_run.sh  - everything to run the verilator simulation

The behvioral code parses the puzzle text and writes the data into a port on the solve hardware with user classification depending upon the data type (lights,buttons,joltage)
The hardware shifts in the button data, and after the final joltage write full search on a range 2^buttons-1 to find cases where the XOR tree matches the desired lights, while keepding track of the lowest button presses for each match and after complation adding the number of presses to the sum.
	...
    Day 10 Part 1 sum =        517
    Day 10 Part 2 ??? =                  199
    - aoc_day10.sv:168: Verilog $finish
    - S i m u l a t i o n   R e p o r t: Verilator 5.040 2025-08-30
    - Verilator: $finish at 3ms; walltime 1.177 s; speed 1.584 ms/s
    - Verilator: cpu 1.706 s on 1 threads; alloced 579 MB


## Part 2

It took a while to get part 1 going, and I had pre-anticipated on what part 2 might bed, and structued the design so I could implement it rapidly if right.
I was thinking that the joltage values would be assigned to each button and the sum of those values matche the value of the lights. I was ready for that.

It was completely different, so I will need to think on this and maybe circle back to this one later.
< insert diagram >

