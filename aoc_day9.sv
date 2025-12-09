
module day9_tb();

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
                for( int ii = 0; ii < 50000; ii++ ) begin
                        @(negedge clk);
                end
                $finish();
        end

	// turn on waveform dump
	initial begin
        	$timeformat(-9, 0, "ns", 12); // 1: scale (ns=-9), 2: decimals, 3: suffix, 4: print-field width
        	$dumpfile("day6.fst");
        	$dumpvars(1,i_dut_part1);
        end
	

	// Read day9_puzzle.txt and calculate answer (behavioral, 
	logic 	wvalid;
	logic 	[17:0] xcoord, ycoord;
	logic   [35:0] maximum;
	logic   done;
    	integer file, c;
	integer value;
    	initial begin
		wvalid = 0;
		xcoord = 0;
		ycoord = 0;
		// Wait for reset
		@(negedge clk);
		while( reset ) @(negedge clk);
		for( int ii = 0; ii < 10; ii++ ) @(negedge clk);

		// Read file and feed the xy coordinates with valid
        	file = $fopen("day9_puzzle.txt", "r");
        	if( file ) begin
			value = 0;
                	c = $fgetc(file);
                	while( c != -1 ) begin // until eof
				case( c ) 
				"0","1","2","3","4","5","6","7","8","9" : begin
					value = value * 10 + c - "0";
				end
				"," : begin
					xcoord = value;
					value  = 0;
				end
				8'h0a : begin
					@(negedge clk);
					ycoord = value;
					value  = 0;
					wvalid = 1;
					$display("%d,%d", xcoord,ycoord);
				end
				endcase
                        	c = $fgetc(file);
        	        end
        	end else begin
                	$display("AOC puzzle.txt not found");
			$finish();
        	end
		$fclose( file );
		@(negedge clk);
		value = 0;
	
		// Wait for processing to be done 100K cycles
		while( !done ) @(negedge clk);

		// Report result
               	$display("Day 9 Part 1 Max Area = %d", maximum );
		for( int ii = 0; ii < 10; ii++ ) @(negedge clk);

		// Finish
		$finish();
	end // initial

	// Instantiate day 9 synthesizable verilog
	aoc_day9 i_day9 (
		.clk	( clk ),
		.reset	( reset ),
		.wvalid	( wvalid ),
		.xcoord	( xcoord ),
		.ycoord ( ycoord ),
		.done   ( done ),
		.maximum( maximum )
	);
endmodule




module aoc_day9 (
	input logic clk,
	input logic reset,
	input logic wvalid,
	input logic [17:0] xcoord,
	input logic [17:0] ycoord,
	output logic done,
	output logic [35:0] maximum
	);
	// black box simple response
	assign done = 1;
	always_ff @(posedge clk)
		maximum <= ( reset ) ? 0 : ( wvalid ) ? maximum + 1 : maximum;
endmodule
