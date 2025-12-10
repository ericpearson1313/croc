
module day10_tb();

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
        	$dumpfile("day10.fst");
        	$dumpvars(1,i_day10);
        end
	

	// Read day9_puzzle.txt and calculate answer (behavioral, 
	// DUT Connections
	logic   [15:0] wdata;
	logic 	      wvalid;
	logic         wlast; // starts the processing
	logic   [2:0] wuser; // { joltage, buttons, target }
	logic 	      wready; // done flag
	logic	[31:0] sum1; // part 1 sum 
	logic   [63:0] sum2; // part 2 sum (optimistic!)

    	integer file, c;
	integer vidx;
	integer waitcount;
    	initial begin
		// clear dut IO
		wdata = 0;
		wvalid = 0;
		wlast = 0;
		wuser = 0;

		// Wait for reset
		@(negedge clk);
		while( reset ) @(negedge clk);
		for( int ii = 0; ii < 10; ii++ ) @(negedge clk);

		// Read file and feed the xy coordinates with valid
        	file = $fopen("day10_puzzle.txt", "r");
        	if( file ) begin
                	c = $fgetc(file);
                	while( c != -1 ) begin // until eof
				//$display("char %c", c );
				case( c ) 
				"[" : 	begin
						// on start of new puzzle line wait for unit to be ready,
						// up to 8K cycle wait 
						wvalid = 0;
						waitcount = 0;
						while( !wready ) begin
							@(negedge clk);
							waitcount = waitcount+1;
						end
						$display( "Wait wready cycles = %d",  waitcount );
						wuser = 3'b001; // target phase
						wdata = 0;
						vidx = 1;
				      	end
				"." : 	begin
						wdata = wdata;
						vidx = vidx << 1;
				      	end
				"#" : 	begin
						wdata = wdata | vidx;
						vidx = vidx << 1;
				      	end
				"]" : 	begin
						wvalid = 1;
						$display( "W Target %d %d %d %b",  wvalid, wuser, wdata, wdata[9:0] );
						@(negedge clk);
				      	end
				"(" : 	begin
						wuser = 3'b010; // button phase
						wdata = 0;
					end

				"0","1","2","3","4","5","6","7","8","9" : 
					begin
						if( wuser == 3'b010 ) begin // button, digit is bit pos
							wdata = wdata | (1<<(c-"0"));
						end else if( wuser == 3'b100 ) begin // joltage is base 10
							wdata = wdata * 10 + c - "0";
						end
					end
				"," : 	begin	
						if( wuser == 3'b010 ) begin
							// ignore
						end else if( wuser == 3'b100) begin
							wvalid = 1;
							$display( "W Joltage %d %d %d",  wvalid, wuser, wdata );
							@(negedge clk);
							wdata = 0;
						end
					end
				")" : 	begin
						wvalid = 1;
						$display( "W Button %d %d %d %b",  wvalid, wuser, wdata, wdata[9:0] );
						@(negedge clk);
				      	end
				"{" : 	begin
						wuser = 3'b100; // button phase
						wdata = 0;
					end
				"}" : 	begin
						wvalid = 1;
						wlast = 1;
						$display( "W Joltage %d %d %d",  wvalid, wuser, wdata );
						@(negedge clk);
					end
				8'h0a : begin
						wdata = 0;
						wvalid = 0;
						wlast = 0;
						wuser = 0;
						$display( "EOL");
					end
				endcase
                        	c = $fgetc(file);
        	        end
        	end else begin
                	$display("AOC puzzle.txt not found");
			$finish();
        	end
		$fclose( file );

		// Wait for completion
		waitcount = 0;
		while( !wready ) begin
			@(negedge clk);
			waitcount = waitcount+1;
		end
		$display( "Wait wready cycles = %d",  waitcount );

		// Report result
		for( int ii = 0; ii < 10; ii++ ) @(negedge clk);
               	$display("Day 10 Part 1 sum = %d", sum1);
               	$display("Day 10 Part 2 ??? = %d", sum2);
		for( int ii = 0; ii < 10; ii++ ) @(negedge clk);

		// Finish
		$finish();
	end // initial

	// Instantiate day 10 synthesizable verilog 
	aoc_day10 i_day10 (
		.clk	( clk ),
		.reset	( reset ),
		.wvalid	( wvalid ),
		.wready	( wready ),
		.wdata 	( wdata  ),
		.wuser 	( wuser  ),
		.wlast 	( wlast  ),
		.sum1   ( sum1 ),
		.sum2   ( sum2 )
	);
endmodule




module aoc_day10 (
	input logic clk,
	input logic reset,
	input logic wvalid,
	input logic wlast,
	input logic [2:0] wuser,
	input logic [15:0] wdata,
	output logic wready,
	output logic [31:0] sum1,
	output logic [63:0] sum2
	);
	//black box simple response
	//assign wready = 1;
	//always_ff @(posedge clk) begin
	//	sum1 <= ( reset ) ? 0 : ( wvalid ) ? sum1 + 1 : sum1;
	//	sum2 <= ( reset ) ? 0 : ( wvalid && wlast ) ? sum2 + 1 : sum2;
	//end

	// Target lights for match condition
	logic [9:0] target;
	always_ff @(posedge clk)
		target <= ( reset ) ? 0 : ( wvalid && wready && wuser[0] ) ? wdata[9:0] : target;

	// Button array allow 16, puzzle seems to max at 13
	// Shift in during button writes
	logic [15:0][9:0] button;
	always_ff @(posedge clk) 
		button <= ( reset ) ? 0 : ( wvalid && wready && wuser[1] ) ? { button[14:0], wdata[9:0] } : button;

	// Joltage shift in
	logic [14:0][15:0] joltage;
	always_ff @(posedge clk) 
		joltage <= ( reset ) ? 0 : ( wvalid && wready && wuser[2] ) ? { joltage[14:0], wdata[15:0] } : joltage;
	

	// Counter, shifts in 1's with each button, and then count down to
	// zero
	logic [15:0] count;
	always_ff @(posedge clk) 
		count <= ( reset ) ? 0 : 
	                 ( ( wvalid && wready && wuser[1] ) ) ? { count[14:0], 1'b1 } :
			 ( !wready && count!=0 ) ? count - 1 : count;
	
	// Wready Logic
	always_ff @(posedge clk) 
		wready <= ( reset ) ? 1 : 
			  ( wvalid && wready && wlast ) ? 0 : // drop ready while we process
			  ( !wready && count == 0 ) ? 1 : wready;
	
	// Count Button presses
	// is the sum of bits set in count
	logic [3:0] presses;
	assign presses = (( count[0] + count[1] ) + ( count[2] + count[3] ) + 
		          ( count[4] + count[5] ) + ( count[6] + count[7] ))+
		         (( count[8] + count[9] ) + ( count[10]+ count[11]) + 
			  ( count[12]+ count[13] )+ ( count[14]+ count[15]));
	
	// Compute lights
	logic [9:0] lights;
	assign lights = ( ( !count[ 0] ) ? 0 : button[ 0] ) ^
	                ( ( !count[ 1] ) ? 0 : button[ 1] ) ^
	                ( ( !count[ 2] ) ? 0 : button[ 2] ) ^
	                ( ( !count[ 3] ) ? 0 : button[ 3] ) ^
	                ( ( !count[ 4] ) ? 0 : button[ 4] ) ^
	                ( ( !count[ 5] ) ? 0 : button[ 5] ) ^
	                ( ( !count[ 6] ) ? 0 : button[ 6] ) ^
	                ( ( !count[ 7] ) ? 0 : button[ 7] ) ^
	                ( ( !count[ 8] ) ? 0 : button[ 8] ) ^
	                ( ( !count[ 9] ) ? 0 : button[ 9] ) ^
	                ( ( !count[10] ) ? 0 : button[10] ) ^
	                ( ( !count[11] ) ? 0 : button[11] ) ^
	                ( ( !count[12] ) ? 0 : button[12] ) ^
	                ( ( !count[13] ) ? 0 : button[13] ) ^
	                ( ( !count[14] ) ? 0 : button[14] ) ^
	                ( ( !count[15] ) ? 0 : button[15] ) ;

	// some monitor registers
	logic [9:0] lights_reg;
	logic [3:0] presses_reg;
	logic hit;
	always_ff @(posedge clk) begin
		hit <= (!wready && lights == target) ? 1'b1 : 1'b0;
		lights_reg <= lights;
		presses_reg <= presses;
	end

	// debug to remove
	always_ff @(posedge clk) begin
		if( !wready && lights == target )
			$display( "hit count 0x%x %b", count, count );
	end
	
	// maintain min presses for matche
	logic [4:0] min_presses;
	always_ff @(posedge clk) 
		min_presses <= ( wvalid && wready && wuser[0] ) ? 16 :
			       ( !wready && lights == target && presses < min_presses ) ? presses : min_presses;

       // Accululate sum1 at end of the run
	logic wready_d;
	always_ff @(posedge clk) begin
		wready_d <= wready;
		sum1 <= ( reset ) ? 0 : 
			( wready && !wready_d ) ? sum1 + min_presses : sum1;
		// debug to remove
		if( wready && !wready_d ) 
			$display("Fewest presses %d", min_presses );
	end
	
	// We'll just have sum2 count machines for now
	always_ff @(posedge clk) 
		sum2 <= ( reset ) ? 0 : ( wvalid && wlast ) ? sum2 + 1 : sum2;

endmodule
