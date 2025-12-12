
module day12_tb();

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
        	$dumpfile("day12.fst");
        	$dumpvars(1,i_day12);
        end
	

	// Read day9_puzzle.txt and calculate answer (behavioral, 
	// DUT Connections
	logic   [8:0] wdata;
	logic 	      wvalid;
	logic         wlast; // starts the processing
	logic   [1:0] wuser; // flag data type: 0-puzzle, 1-W/H, 2-Presents
	logic 	      wready; // done flag
	logic	[9:0] sum1; // part 1 sum 
	logic   [9:0] sum2; // part 2 sum (optimistic!)

    	integer file, c;
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
        	file = $fopen("day12_puzzle.txt", "r");
        	if( file ) begin
			// first read the 6 puzzle peices and write them to hw
			// packed as raster big endian into [8:0]
			$display("Reading puzzle peices");
                	c = $fgetc(file);
			for (int piece = 0; piece < 6; piece++ ) begin
				wdata = 0;
				for( int count = 0; count < 9; ) begin
					//$display("char %c", c );
					case( c ) 
					"." : 	begin
							wdata = wdata << 1;
							count++;
				      		end
					"#" : 	begin
							wdata = (wdata << 1) + 1;
							count++;
				      		end
					endcase
                			c = $fgetc(file);
				end
				wvalid = 1;
				@(negedge clk);
                		c = $fgetc(file); // read sep line
			end

			// Read Size/Count Tree rows
			$display("Read Trees to be checked for present fit");
                	c = $fgetc(file);
			wdata = 0;
                	while( c != -1 ) begin // until eof
				case( c ) 
				"0","1","2","3","4","5","6","7","8","9" : 
					begin
						wdata = wdata * 10 + c - "0";
					end
				"x" :	begin
						wuser = 1;
						wvalid = 1;
						@(negedge clk );
						wdata = 0;
					end
				":" : 	begin
						wuser = 1;
						wvalid = 1;
						@(negedge clk );
						wdata = 0;
					end
				" " : 	begin
						if( wdata != 0 ) begin
							wuser = 2;  
							wvalid = 1;
							@(negedge clk);
							wdata = 0;
						end
					end
				8'h0a :	begin
						wuser = 2;  
						wlast = 1;
						wvalid = 1;
						@(negedge clk);
						wdata = 0;
						wlast = 0;
					end
				endcase
                        	c = $fgetc(file);
        	        end
        	end else begin
                	$display("AOC puzzle.txt not found");
			$finish();
        	end
		$fclose( file );
		wlast = 0;
		wuser = 0;
		wdata = 0;
		wvalid = 0;
		@(negedge clk);

		// Wait for completion
		while( !wready ) begin
			@(negedge clk);
		end
		for( int ii = 0; ii < 10; ii++ ) @(negedge clk);
		$display( "Total Trees = %d",  	sum1);
		$display( "Min Feasible Trees = %d",  sum2);

		// Finish
		$finish();
	end // initial

	// Log data into device
	//always @(posedge clk)
	//	if( wvalid ) 
	//		$display("user %d data %d(0x%b) last %d", wuser, wdata, wdata, wlast );

	// Instantiate day 10 synthesizable verilog 
	aoc_day12 i_day12 (
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



module aoc_day12 (
	input logic clk,
	input logic reset,
	input logic wvalid,
	input logic wlast,
	input logic [1:0] wuser,
	input logic [8:0] wdata,
	output logic wready,
	output logic [9:0] sum1,
	output logic [9:0] sum2
	);
	//black box simple response
	assign wready = 1;
	//always_ff @(posedge clk) begin
	//	sum1 <= ( reset ) ? 0 : ( wvalid && wlast ) ? sum1 + 1 : sum1;
	//	sum2 <= ( reset ) ? 0 : ( wvalid          ) ? sum2 + 1 : sum2;
	//end

	// Sum1 acculates the numbers of trees
	always_ff @(posedge clk) 
		sum1 <= ( reset ) ? 0 : ( wvalid && wlast ) ? sum1 + 1 : sum1;

	// Puzzle Pieces shift input
	logic [5:0][8:0] puzzle;
	always @(posedge clk) 
		puzzle <= ( wvalid && wuser == 2'h0 ) ? { puzzle[4:0], wdata[8:0] } : puzzle;

	// Width Heigth area;
	logic [5:0] width, height;
	logic [15:0] area;
	always_ff @(posedge clk) 
		{ width, height } <= ( wvalid && wuser == 2'h1 ) ? { height, wdata[5:0] } : { width, height };
	assign area = width * height;

	// Shift in present counts
	logic [5:0][6:0] presents;
	always_ff @(posedge clk) 
		presents <= ( wvalid && wuser == 2'h2 ) ? { presents[4:0], wdata[6:0] } : presents;

	// Determine pzzle piece sizes
	logic [5:0][3:0] size;
	always_comb 
		for( int ii = 0; ii < 6; ii++ ) 
			size[ii] = ((puzzle[ii][0] + puzzle[ii][1]) + (puzzle[ii][2] + puzzle[ii][3])) +
		                   ((puzzle[ii][4] + puzzle[ii][5]) + (puzzle[ii][6] + puzzle[ii][7])) + puzzle[ii][8];

	// First filter determine area is large enough to even be considered viable
	logic [15:0] required_area;
	logic viable;
	assign required_area = size[0] * presents[0] +
		               size[1] * presents[1] +
		               size[2] * presents[2] +
		               size[3] * presents[3] +
		               size[4] * presents[4] +
		               size[5] * presents[5] ;
	assign viable = ( required_area <= area ) ? 1'b1 : 1'b0;

	// Sum2 Counts the number of viable trees 
	// done 1 cycle after last present count for a given tree
	logic wlast_d;
	always_ff @(posedge clk) begin
		wlast_d <= ( wvalid && wlast && wuser == 2'h2 ) ? 1'b1 : 1'b0;
		sum2 <= ( reset ) ? 0 : ( wlast_d ) ? sum2 + viable : sum2;
	end
endmodule
