
# AoC 2025 Day-11 puzzle solution generation in verilog.

In this case the puzzle text was directly translatable into synthesizable verilog. Each puzzle line was translated 
to a verilog, and the testbench stimilated the 3 inputs and tracked the 4 outputs and was quickly able to solve part1 and part2.

    day11_generate.c - reads puzzle text and generates two verilog source files
	    day11_declaration.sv - declarations for all the uzzle wires
		day11_operation.sv - the puzzle lines 1:1 mapped to verilog statements
	aoc_day11.sv - Contains a verilog behavioral testbench and sythesizeable compute module
	day11_puzzle.txt - puzzle text
	day11_run.sh  - everything to compile and run the c code to generate verilog and run the verilator simulation

The C code parsies the puzzle data and write two verilog source files with a) wire and b) connections. 
The behavioral verilog testbench sets the 3 inputs 1 at atime ( out, dac, fft ) and records the 4 outputs (you, svr, fft, dac ).
The synthesizable verilog includes the generated verilog. When the design is simulated the Day 11 puzzle is solved in 3 cycles.

	...
    - V e r i l a t i o n   R e p o r t: Verilator 5.040 2025-08-30 rev v5.040
    - Verilator: Built from 0.000 MB sources in 0 modules, into 0.000 MB in 0 C++ files needing 0.000 MB
    - Verilator: Walltime 0.012 s (elab=0.000, cvt=0.000, bld=0.011); cpu 0.001 s on 4 threads; alloced 29.340 MB
    000 : you =                    0, dac =                    0, fft =                    0, svr =                    0 
    100 : you =                  674, dac =                 7957, fft =         217172585418, svr =    63170507621624566 
    010 : you =                    0, dac =                    0, fft =                    1, svr =                16656 
    001 : you =                    0, dac =                    1, fft =              3307242, svr =         961947938536 
    all YOU-OUT paths   :                  674
    all YOU-DAC-FFT-OUT :                    0
    all YOU-FFT-DAC-OUT :      438314708837664
    - aoc_day11.sv:62: Verilog $finish
    - S i m u l a t i o n   R e p o r t: Verilator 5.040 2025-08-30
    - Verilator: $finish at 90ns; walltime 0.003 s; speed 28.454 us/s
    - Verilator: cpu 0.003 s on 1 threads; alloced 503 MB



