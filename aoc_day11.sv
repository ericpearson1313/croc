
module day11_tb();

	// Let there be clock and reset
        logic clk;
        logic reset;

        // Create clock
        initial begin
                clk = 0;
                for( ;; ) begin
                        #(10ns);
                        clk = !clk;
                end
        end

        // create reset
        initial begin
                reset = 1;
                for( int ii = 0; ii < 10; ii++ ) begin
                        @(negedge clk);
                end
                reset = 0;
                $display("Reset done");
                for( int ii = 0; ii < 2000000; ii++ ) begin
                        @(negedge clk);
                end
                $display("halted dur to clock limit");
                $finish();
        end

	// turn on waveform dump
	initial begin
        	$timeformat(-9, 0, "ns", 12); // 1: scale (ns=-9), 2: decimals, 3: suffix, 4: print-field width
        	$dumpfile("day11.fst");
        	$dumpvars(1,i_day11);
        end
	

	// DUT Connections
	logic [63:0] svr, you, out;

    	initial begin
		// clear dut IO
		out = 0;
		// Wait for reset
		@(negedge clk);
		while( reset ) @(negedge clk);
		for( int ii = 0; ii < 10; ii++ ) @(negedge clk);


		out = 1;
		for( int ii = 0; ii < 10; ii++ ) @(negedge clk);
		$display( "Paths you(%d)->out(%d) %h",  you, out, you);
		$display( "Paths svr(%d)->out(%d) %h",  svr, out, svr);
		for( int ii = 0; ii < 10; ii++ ) @(negedge clk);
		$finish();
	end // initial

	// Instantiate day 10 synthesizable verilog 
	aoc_day11 i_day11 (
		.clk	( clk ),
		.reset	( reset ),
		.out    ( out ),
		.svr    ( svr ),
		.you    ( you )
	);
endmodule




module aoc_day11 (
	input logic clk,
	input logic reset,
	input logic [63:0] out,
	output logic [63:0] svr,
	output logic [63:0] you
	);

`include "day11_declaration.sv"
`include "day11_operation.sv"

endmodule
