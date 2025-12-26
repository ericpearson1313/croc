
module day5_tb();
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
		for( int ii = 0; ii < 4000; ii++ ) begin
			@(negedge clk);
		end
		$finish();
	end

	initial begin
        	$timeformat(-9, 0, "ns", 12); // 1: scale (ns=-9), 2: decimals, 3: suffix, 4: print-field width
        	// configure FST (waveform) dump
        	$dumpfile("day5.fst");
        	$dumpvars(1,i_dut_part1);
        	$dumpvars(1,i_dut_part2);
	end

	// Instantial day5 DUT
	logic [63:0] din;
	logic we_upper;
	logic we_lower;
	logic we_cand;
	logic [15:0] hit_count;
	day5_part1 i_dut_part1 (
		.clk ( clk ),
		.din ( din ),
		.we_upper( we_upper ),
		.we_lower( we_lower ),
		.we_cand(  we_cand ),
		.hit_count( hit_count )
	);
	
	logic [1:0][63:0] wdata;
	logic [63:0] rdata;
	logic wvalid, wlast, wready, rvalid;
	day5_part2 i_dut_part2 (
		.clk ( clk ),
		.reset( reset ),
		.wdata( wdata ),
		.wvalid( wvalid ),
		.wready( wready ),
		.wlast( wlast ),
		.rdata( rdata ),
		.rvalid( rvalid )
	);
		
	// Read day5_puzzle.txt
    	integer file, c;
	logic [63:0] in; // Input word
	logic [63:0] val; 
	logic [7:0] charcode;
	logic [3:0] bcd_digit;
	logic data_phase;
	logic expect_digit;
    	initial begin
        	file = $fopen("day5_puzzle.txt", "r");
		din = 0;
		val = 0;
		wdata = 0;
		data_phase = 0;
		expect_digit = 0;
		while( reset ) @(negedge clk);
		@(negedge clk);
		$display("Read Ranges");
        	if( file ) begin
                	c = $fgetc(file);
                	while( c != -1 ) begin // until eof
				charcode = c;
				case( charcode ) 
				"0","1","2","3","4","5","6","7","8","9": // Shift in a bcd digit
					begin // Shift in a BCD number
						bcd_digit = charcode - "0";
						din[63:0] = { din[63-4:0], bcd_digit[3:0] };
						val = val * 10 + bcd_digit;
						expect_digit = 0;
					end
				"-" : // Lower upper separator
					begin
						$display("Lower %h", din );
						wdata[0] = val;
						we_lower = 1;
						@(negedge clk);
						we_lower = 0;
						din = 0;
						val = 0;
					end
				8'h0A : // Write either data or upper`
					begin
						if( expect_digit ) begin
							$display("end ranges, start candidates");
							data_phase = 1;
							expect_digit = 0;
						end else if( data_phase ) begin
							$display("Cand %h", din );
							@(negedge clk);
							we_cand = 1;
							@(negedge clk);
							we_cand = 0;
							din = 0;
						end else begin // else upper
							$display("Upper %h", din );
							wdata[1] = val;
							wvalid = 1;
							we_upper= 1;
							@(negedge clk);
							wvalid = 0;
							we_upper= 0;
							din = 0;
							val = 0;
							expect_digit = 1; // else end of range phase
						end
					end
				default: 
					$display("unexpected char");
				endcase
                        	c = $fgetc(file);
               		 end
                	$display("end of file puzzle txt");
                	 $fclose(file);
        	end else begin
                	$display("AOC puzzle.txt not found");
        	end

		// Wait for hit_count to update
		wlast = 1; wvalid = 1; // this will send the sum through the pipe to accumulate
		for( int ii = 0; ii < 500; ii++ )
			@(negedge clk);
		$display("Day 5 part 1 = %d", hit_count );
		$display("Day 5 part 2 = %d", rdata );
		$finish();
    	end


endmodule

module day5_part2 (
	input logic clk,
	input logic reset,
	input logic [1:0][63:0] wdata,	// 1 upper, 0 lower
	input logic 		wvalid,
	output logic 		wready,
	input logic 		wlast,
	output logic [63:0] 	rdata, // sum of all ranges
	output logic            rvalid
	);

	localparam MAX = 200;
	// Upper and lower shift regs
	logic [MAX-1:0][1:0][63:0] range;  // buffers to ranges. An ordered non-overlapping list of ranges
	logic [MAX-1:0]      [1:0] rs; 	   // State of range cells
	logic [MAX-1:0][1:0][63:0] process; // Constantly shifting buffer holding a range for insertion
	logic [MAX-1:0]      [1:0] ps;      // state of 

	// Gate the wready to space out active items on process list
	assign wready = 1;


	// Compare assocated process and range limits
	logic [MAX-1:0][3:0] comp;
	logic [MAX-1:0][1:0][63:0] merge;
	logic [63:0] sum;
	always_comb begin
		for (int ii = 0; ii < MAX; ii++ ) begin
			comp[ii][3] = ( process[ii][0] < range[ii][0] ) ? 1'b1 : 1'b0;
			comp[ii][2] = ( process[ii][0] > range[ii][1] ) ? 1'b1 : 1'b0;
			comp[ii][1] = ( process[ii][1] < range[ii][0] ) ? 1'b1 : 1'b0;
			comp[ii][0] = ( process[ii][1] > range[ii][1] ) ? 1'b1 : 1'b0;
			merge[ii][0] = ( comp[ii][3] ) ? process[ii][0] : range[ii][0];
			merge[ii][1] = ( comp[ii][0] ) ? process[ii][1] : range[ii][1];
		end
	end

	localparam PS_EMPTY 	= 2'd0;
	localparam PS_VALID     = 2'd1;
	localparam PS_SUM       = 2'd2;
	localparam PS_ACC       = 2'd3;

	localparam RS_EMPTY	= 2'd0;
	localparam RS_VALID 	= 2'd1;
	localparam RS_VOID  	= 2'd2;

	// Now build arrays
	always_ff @(posedge clk) begin
	    if( reset ) begin
		ps <= 0;
		rs <= 0;
		sum <= 0;
	    end else begin
		ps[0] <= ( wvalid && wready && wlast ) ? PS_SUM : ( wvalid && wready ) ? PS_VALID : PS_EMPTY;
		process[0] <= ( wvalid && wready && !wlast ) ? wdata : 0;
		sum <= ( ps[MAX-1] == PS_ACC ) ? sum + process[MAX-1][1] - process[MAX-1][0] + 1 : sum;;
		for( int ii = 0; ii < MAX-1; ii++ ) begin
			if( ps[ii] == PS_EMPTY ) begin 
				rs[ii]   <= rs[ii]; range[ii]     <= range[ii];	  // hold range
				ps[ii+1] <= ps[ii]; process[ii+1] <= process[ii]; // step process
			end else if( ps[ii] == PS_SUM && rs[ii] == RS_VALID ) begin
				rs[ii] 	 <= RS_VOID; range[ii]     <= 0;           // void range
				ps[ii+1] <= PS_ACC ; process[ii+1] <= range[ii];   // swap process gets range
			end else if( rs[ii] == RS_EMPTY && ps[ii] == PS_VALID) begin // insert range in 1st empty slot (end of list only)
				rs[ii]   <= RS_VALID; range[ii]     <= process[ii];
				ps[ii+1] <= PS_EMPTY; process[ii+1] <= 0;
			end else if( rs[ii] == RS_VALID && ps[ii] == PS_VALID && comp[ii][2]) begin // process fully above range, just step
				rs[ii]   <= rs[ii]; range[ii]     <= range[ii];	  // hold range
				ps[ii+1] <= ps[ii]; process[ii+1] <= process[ii]; // step process
			end else if( rs[ii] == RS_VALID && ps[ii] == PS_VALID && comp[ii][1]) begin // process completely above range, swap
				rs[ii]   <= RS_VALID ; range[ii]     <= process[ii]; // swap range get process
				ps[ii+1] <= PS_VALID ; process[ii+1] <= range[ii];   // swap process gets range
			end else if( rs[ii] == RS_VALID && ps[ii] == PS_VALID && comp[ii] == 4'b0000 ) begin // completely within range, drop
				rs[ii] 	 <= rs[ii]  ; range[ii]     <= range[ii]; // hold range
				ps[ii+1] <= PS_EMPTY; process[ii+1] <= 0;	 // drop process
			end else if( rs[ii] == RS_VALID && ps[ii] == PS_VALID && comp[ii] == 4'b1001 ) begin // process obliterates range
				rs[ii] 	 <= RS_VOID; range[ii]     <= 0;           // void range
				ps[ii+1] <= ps[ii] ; process[ii+1] <= process[ii]; // step process
			end else if( rs[ii] == RS_VALID && ps[ii] == PS_VALID && comp[ii] == 4'b1000 ) begin // merge range into process and drop
				rs[ii]   <= RS_VALID; range[ii]     <= merge[ii]; // range get process
				ps[ii+1] <= PS_EMPTY; process[ii+1] <= 0;	  // drop process
			end else if( rs[ii] == RS_VALID && ps[ii] == PS_VALID && comp[ii] == 4'b0001 ) begin // forward merge and void range
				rs[ii] 	 <= RS_VOID; range[ii]     <= 0;         // void range
				ps[ii+1] <= ps[ii] ; process[ii+1] <= merge[ii]; // step process
			end else begin // otherwise range holds and process advances
				rs[ii]   <= rs[ii]; range[ii]     <= range[ii];	  // hold range
				ps[ii+1] <= ps[ii]; process[ii+1] <= process[ii]; // step process
			end
		end
	    end
	end

	// Setup output
	assign rdata = sum;
	assign rvalid = ( ps[MAX-1] == PS_SUM ) ? 1'b1 : 1'b0;
endmodule


module day5_part1 (
	input logic clk,
	input logic [63:0] din,
	input logic we_upper,	// write upper range
	input logic we_lower,	// write lower range
	input logic we_cand,	// write canadidate data
	output logic [31:0] hit_count // Count of candidates that fall in at least 1 range (Part 1)
	);

	// Upper and lower shift regs
	logic [199:0][63:0] upper;
	logic [199:0][63:0] lower;
	always_ff @(posedge clk) begin
		upper[199:0] <= ( we_upper ) ? { upper[198:0], din } : upper[199:0];
		lower[199:0] <= ( we_lower ) ? { lower[198:0], din } : lower[199:0];
	end


	// Candiate pipeline
	logic [199:0][63:0] cand;
	logic [199:0]       valid;
	logic [199:0]	    hit;
	always_ff @(posedge clk) begin
		cand[199:0] <= { cand[198:0], din }; // always shift
		valid[199:0] <= { valid[198:0], we_cand }; // always shift
		hit[0] <= 0;
		for( int ii = 0; ii < 199; ii++ ) begin
			hit[ii] <= ( (ii==0)?1'b0:hit[ii-1] ) |
				   ( (valid[ii] && cand[ii] >= lower[ii] && cand[ii] <= upper[ii] ) ? 1'b1 : 1'b0 );
		end
	end

	// Sum accumulator
	always_ff @(posedge clk) begin
		hit_count <= ( we_upper ) ? 1'b0 : ( valid[199] && hit[198] ) ? hit_count+1 : hit_count;
	end
endmodule
