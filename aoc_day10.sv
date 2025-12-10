
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
        	$dumpvars(1,i_dut_part1);
        end
	

	// Read day9_puzzle.txt and calculate answer (behavioral, 
	// DUT Connections
	logic   [9:0] wdata;
	logic 	      wvalid;
	logic         wlast; // starts the processing
	logic   [2:0] wuser; // { joltage, buttons, target }
	logic 	      wready; // done flag
	logic	[31:0] sum1; // part 1 sum 
	logic   [63:0] sum2; // part 2 sum (optimistic!)

    	integer file, c;
	integer vidx;
	integer phase;
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
        	file = $fopen("day10_short_puzzle.txt", "r");
        	if( file ) begin
                	c = $fgetc(file);
                	while( c != -1 ) begin // until eof
				//$display("char %c", c );
				case( c ) 
				"[" : 	begin
						// on start of new puzzle line wait for unit to be ready,
						// up to 8K cycle wait 
						wvalid = 0;
						while( !wready )
							@(negedge clk);
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
						$display( "W Target %d %d %d",  wvalid, wuser, wdata );
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
						$display( "W Button %d %d %d",  wvalid, wuser, wdata );
						@(negedge clk);
				      	end
				"{" : 	begin
						wuser = 3'b100; // button phase
						wdata = 0;
					end
				"}" : 	begin
						wvalid = 1;
						wlast = 1;
						$display( "W button %d %d %d",  wvalid, wuser, wdata );
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
		wvalid = 0;
		wlast = 0;
		@(negedge clk);
		@(negedge clk);
	
		// Wait for processing to be done 100K cycles
		while( !wready ) @(negedge clk);

		// Report result
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
	input logic [9:0] wdata,
	output logic wready,
	output logic [31:0] sum1,
	output logic [63:0] sum2
	);
	//black box simple response
	assign wready = 1;
	always_ff @(posedge clk) begin
		sum1 <= ( reset ) ? 0 : ( wvalid ) ? sum1 + 1 : sum1;
		sum2 <= ( reset ) ? 0 : ( wvalid && wlast ) ? sum2 + 1 : sum2;
	end

/*
	// Lenght
	logic [9:0] length;
	always_ff @(posedge clk)
		length <= ( reset ) ? 0 : ( wvalid ) ? length + 1 : length;
			

	// Write to memories as data arrives (dual read)
	logic [17:0] xa_ram [0:1023] ;
	logic [17:0] xb_ram [0:1023] ;
	logic [17:0] ya_ram [0:1023] ;
	logic [17:0] yb_ram [0:1023] ;
	always_ff @(posedge clk) begin
		if( wvalid ) begin
			xa_ram[length] <= xcoord;
			xb_ram[length] <= xcoord;
			ya_ram[length] <= ycoord;
			yb_ram[length] <= ycoord;
		end
	end

	// run_flag
	logic run;
	logic wvalid_d;
	always_ff @(posedge clk) begin
		wvalid_d <= wvalid;
		run <= ( reset ) ? 0 : ( !wvalid & wvalid_d ) ? 1 : ( last ) ? 0 : run;
	end

	// read address generationA
	logic [9:0] counta;
	logic [9:0] countb;
	always_ff @(posedge clk) begin
		counta <= ( reset                                               ) ?          0 : 
                          ( run && countb == length - 1 && counta == length - 2 ) ?          0 :
                          ( run && countb == length - 1                         ) ? counta + 1 : 
                                                                                    counta     ;
	end
	always_ff @(posedge clk) begin
		countb <= ( reset                                               ) ?          1 : 
                          ( run && countb == length - 1 && counta == length - 2 ) ?          0 :
                          ( run && countb == length - 1                         ) ? counta + 2 : 
			  ( run                                                 ) ? countb + 1 : 
                                                                                    countb     ;
	end

	// Last logic
	logic last;
	assign last = ( run && countb == length - 1 && counta == length - 2 ) ? 1'b1 : 1'b0;

	// Done flag 
	always_ff @(posedge clk) 
		done <= ( reset ) ? 0 : ( last ) ? 1 : done;

	// Read the rams at both addresses A and B 
	logic [17:0] xa, xb, ya, yb;
	always_ff @(posedge clk) begin
		xa <= xa_ram[counta];
		xb <= xb_ram[countb];
		ya <= ya_ram[counta];
		yb <= yb_ram[countb];
	end

	// Absoute differences + 1;
	logic [17:0] absdx, absdy;
	logic [17:0] width, height;
	assign absdx = ( xa > xb ) ? xa - xb : xb - xa;
	assign absdy = ( ya > yb ) ? ya - yb : yb - ya;

	always_ff @(posedge clk) begin
		width <= absdx + 1;
		height<= absdy + 1;
	end

	// Area Calc
	logic [35:0] area;
	always_ff @(posedge clk) 
		area <= width * height;

	// delay run to get acc flag
	logic acc_flag[2:0];
	always_ff @(posedge clk) 
		acc_flag[2:0] <= { acc_flag[1:0], run };
	
	// Maximum Accumulator
	always_ff @(posedge clk) 
		maximum <= ( reset ) ? 0 : ( acc_flag[2] && area > maximum ) ? area : maximum;
*/
endmodule
