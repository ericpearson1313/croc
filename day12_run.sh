verilator -Wno-fatal -Wno-style -Wno-BLKANDNBLK -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-WIDTHCONCAT -Wno-ASCRANGE --binary -j 0 --timing --autoflush --trace-fst --trace-threads 2 --trace-structs --trace-depth 10 --unroll-count 1 --unroll-stmts 1 --x-assign fast --x-initial fast -O3 --top day12_tb aoc_day12.sv
obj_dir/Vday12_tb
