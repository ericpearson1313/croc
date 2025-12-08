
# AoC 2025 Day-8 Part 2 puzzle solution generation in verilog.

Had some dfficulty with part-1, so relaxed my synthesizable verilog requirement.
This is a behavioral verilog module to solve Day 8 part2

    aoc_day8.sv - Contains a behavioral compute module
	day8_full_puzzle.txt - puzzle text
	day8_run.sh  - everything to run the verilator simulation

The behvioral code a) reads in all the box coordiate, and b) applies an initial color to each. A itterative process is run
where c) the next shortest connecition is found, and then d) if that cable connects two color regions, the lower color replaces
the higher color for all boxes. e) test if all boxes are color 0 then we are done. The algorithm was clear after solving the part 1 mess.

    ...
    - V e r i l a t i o n   R e p o r t: Verilator 5.040 2025-08-30 rev v5.040
    - Verilator: Built from 0.000 MB sources in 0 modules, into 0.000 MB in 0 C++ files needing 0.000 MB
    - Verilator: Walltime 0.009 s (elab=0.000, cvt=0.000, bld=0.008); cpu 0.001 s on 4 threads; alloced 29.270 MB
    Num Boxes =        1000
    All color=0, --> Fully Connected
    Part2 answer =           6934702555
    - aoc_day8.sv:109: Verilog $finish
    - S i m u l a t i o n   R e p o r t: Verilator 5.040 2025-08-30
    - Verilator: $finish at 0s; walltime 16.029 s; speed 0.000 s/s
    - Verilator: cpu 16.028 s on 1 threads; alloced 31 MB

Done for now .... i'll need to think about how to best make a hardware design (synthesizable) for this.
Maybe later

