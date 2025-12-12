
module day2_tb();

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
        	$dumpfile("day2.fst");
        	$dumpvars(1,i_day2);
        end
	

	// Read day9_puzzle.txt and calculate answer (behavioral, 
	// DUT Connections
	logic   [31:0] wdata;
	logic 	      wvalid;
	logic         wlast; // starts the processing
	logic 	      wready; // done flag
	logic	[63:0] sum1; // part 1 sum 
	logic   [63:0] sum2; // part 2 sum (optimistic!)

    	integer file, c;
	logic [63:0] word;
    	initial begin
		// clear dut IO
		word = 0;
		wdata = 0;
		wvalid = 0;
		wlast = 0;

		// Wait for reset
		@(negedge clk);
		while( reset ) @(negedge clk);
		for( int ii = 0; ii < 10; ii++ ) @(negedge clk);

		// Read puzzle file and feed the ranges in BCD into the HW
        	file = $fopen("day2_puzzle.txt", "r");
        	if( file ) begin
			$display("Reading puzzle ranges");
                	c = $fgetc(file);
                	while( c != -1 ) begin // until eof
				case( c ) 
				"0","1","2","3","4","5","6","7","8","9" : 
					begin // accumulate BCD
						word = (word<<4) + c - "0"; // BCD
					end
				"-" :	begin // two writes for lower range
						wvalid = 1;
						wdata = word[31:0];
						while( !wready ) @(negedge clk );
						@(negedge clk );
						wdata = word[63:32];
						while( !wready ) @(negedge clk );
						@(negedge clk );
						word = 0;
					end
				",", 8'h0a :
			 		begin // two writes for upper range, and mark last
						wvalid = 1;
						wdata = word[31:0];
						while( !wready ) @(negedge clk );
						@(negedge clk );
						wlast = 1;
						wdata = word[63:32];
						while( !wready ) @(negedge clk );
						@(negedge clk );
						wlast = 0;
						word = 0;
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
		wdata = 0;
		wvalid = 0;
		@(negedge clk);

		// Wait for completion
		while( !wready ) begin
			@(negedge clk);
		end
		for( int ii = 0; ii < 10; ii++ ) @(negedge clk);
		$display( "Part 1 Sum = %h", sum1);
		$display( "Part 2 Sum = %h", sum2);

		// Finish
		$finish();
	end // initial

	// Log data into device
	//always @(posedge clk)
	//	if( wvalid ) 
	//		$display("data %h last %b", wdata, wlast );

	// Instantiate day 10 synthesizable verilog 
	aoc_day2 i_day2 (
		.clk	( clk ),
		.reset	( reset ),
		.wvalid	( wvalid ),
		.wready	( wready ),
		.wdata 	( wdata  ),
		.wlast 	( wlast  ),
		.sum1   ( sum1 ),
		.sum2   ( sum2 )
	);
endmodule

// ----------------------------------------------------------------------------------------------
// AOC Day 2 Hardware
// ----------------------------------------------------------------------------------------------
//
module aoc_day2 (
	input logic clk,
	input logic reset,
	input logic wvalid,
	input logic wlast,
	input logic [31:0] wdata,
	output logic wready,
	output logic [63:0] sum1,
	output logic [63:0] sum2
	);
	//black box simple response
	//assign wready = 1;
	always_ff @(posedge clk) begin
	//	sum1 <= ( reset ) ? 0 : ( wvalid && wlast ) ? sum1 + 1 : sum1;
		sum2 <= ( reset ) ? 0 : ( wvalid && wlast ) ? sum2 + 1 : sum2;
	end

	// shift in upper/lower ranges each as 64-bit BCD number
	// write order lower lsb, lower msb, upper lsb, upper msb(last)
	logic [63:0] lower_reg;
	logic [63:0] upper_reg;
	always_ff @(posedge clk)
		if( wvalid && wready ) begin
			upper_reg[63:32] <= wdata[31:0];
			upper_reg[31: 0] <= upper_reg[63:32];
			lower_reg[63:32] <= upper_reg[31:0];
			lower_reg[31: 0] <= lower_reg[63:32];
		end


	// Delay line timing trigger by rot write (in lieu of state machine) TBD
	logic [49:0] tick;
	always_ff @(posedge clk) begin
		if( reset ) begin
			tick <= 0;
		end else if ( wvalid && wready && wlast) begin // write to reg 4 triggers flow TBD
			tick <= 50'h1;
		end else begin
			tick <= { tick[48:0], 1'b0 };
		end
	end

	//////////////////////////
	// Day 2 Puzzle logic
	//////////////////////////

	// Examine the registers to determine number of BCD digits in lower and upper (assume equal or +1 for upper)
	logic [15:0] uflag,lflag; // presence of non zero digit
	logic [4:0] upper_digits, lower_digits, digits;
	always_comb begin
		for( int ii = 0; ii < 16; ii++ ) begin
			uflag[ii] = |upper_reg[ii*4+3-:4];
			lflag[ii] = |lower_reg[ii*4+3-:4];
		end
		upper_digits = ( uflag[15] ) ? 5'd16 : ( uflag[14] ) ? 5'd15 : ( uflag[13] ) ? 5'd14 : ( uflag[12] ) ? 5'd13 :
                               ( uflag[11] ) ? 5'd12 : ( uflag[10] ) ? 5'd11 : ( uflag[ 9] ) ? 5'd10 : ( uflag[ 8] ) ? 5'd9  :
                               ( uflag[ 7] ) ? 5'd8  : ( uflag[ 6] ) ? 5'd7  : ( uflag[ 5] ) ? 5'd6  : ( uflag[ 4] ) ? 5'd5  :
                               ( uflag[ 3] ) ? 5'd4  : ( uflag[ 2] ) ? 5'd3  : ( uflag[ 1] ) ? 5'd2  : ( uflag[ 0] ) ? 5'd1  : 5'd0;
		lower_digits = ( lflag[15] ) ? 5'd16 : ( lflag[14] ) ? 5'd15 : ( lflag[13] ) ? 5'd14 : ( lflag[12] ) ? 5'd13 :
                               ( lflag[11] ) ? 5'd12 : ( lflag[10] ) ? 5'd11 : ( lflag[ 9] ) ? 5'd10 : ( lflag[ 8] ) ? 5'd9  :
                               ( lflag[ 7] ) ? 5'd8  : ( lflag[ 6] ) ? 5'd7  : ( lflag[ 5] ) ? 5'd6  : ( lflag[ 4] ) ? 5'd5  :
                               ( lflag[ 3] ) ? 5'd4  : ( lflag[ 2] ) ? 5'd3  : ( lflag[ 1] ) ? 5'd2  : ( lflag[ 0] ) ? 5'd1  : 5'd0;
		digits <= (!upper_digits[0] && !lower_digits[0]) ?  upper_digits : // E-E
		          ( upper_digits[0] && !lower_digits[0]) ?  lower_digits : // O-E
		          (!upper_digits[0] &&  lower_digits[0]) ?  upper_digits : // E-O
								    5'h0; // O-O no answer
	end // always

	// Assert (part1?) upper_digits == lower_digits || upper_digits == lower_digits + 1

	// Create adjusted upper and lower, occurs when upper_digits > lower_digits
	logic [63:0] adjust_upper;
	logic [63:0] adjust_lower;
	always_comb begin
		if( lower_digits < upper_digits && lower_digits[0] ) begin // lower odd, upper even
			// increase lower unit it becomes even in length
			adjust_upper = upper_reg;
			adjust_lower = 4'h1 << { lower_digits << 2 }; // create 10_00_00 if lower length was 5
		end else if ( lower_digits < upper_digits && !lower_digits[0] ) begin // lower even, upper odd
			// set upper to 99_99
			for( int ii = 15; ii >= 0; ii-- ) begin
				adjust_upper[ii*4+3-:4] = ( ii < lower_digits ) ? 4'h9 : 4'h0;
			end
			adjust_lower = lower_reg;
		end else if ( lower_digits == upper_digits && !lower_digits[0] ) begin // lower=upper, both  even
			// untouched
			adjust_upper = upper_reg;
			adjust_lower = lower_reg;
		end else begin // both are odd, error case
			// lower > upper so it will be ignored
			adjust_upper = 64'h0;
			adjust_lower = {16{4'h1}};
		end
	end // always

	// Snapshot registers
	logic [63:0] hold_upper;
	logic [63:0] hold_lower;
	logic [31:0] test_upper;  // we will use this as a bcd counter, starting at lower upper-half
	logic [5:0] hold_digits;
	logic valid; // Hold data valid for at least 1 cycle
	always_ff @(posedge clk) begin
		if( tick[0] ) begin
			valid <= 1;
			hold_upper <= adjust_upper;
			hold_lower <= adjust_lower;
			hold_digits <= digits;
			test_upper <= adjust_lower >> ( digits << 1 ); // shift down to right justify counter
		end else begin
			hold_upper <= hold_upper;
			hold_lower <= hold_lower;
			hold_digits <= hold_digits;
			test_upper <= ( trial <= hold_upper ) ? inc_sum : test_upper; // auto inc until limit reached
			valid <= ( trial <= hold_upper ) ? 1'b1 : 1'b0;
		end
	end

	// create a trial candiate, and test if in range
	logic [63:0] trial;
	logic in_range;
	assign trial = test_upper | test_upper << ( hold_digits << 1 ); // candidate error sequence repeated eg 13541354
	assign in_range = ( trial <= hold_upper && trial >= hold_lower ) ? 1'b1 : 1'b0; // comparison of bcd works here

	// BCD +1 adder, to increment test_upper[31:0]
	logic [31:0] inc_sum;
	bcd_inc32 i_bcd_inc ( .in( test_upper ), .out( inc_sum ) );

	// BCD adder of trial + sum_part1;
	logic [63:0] bcd_sum;
	bcd_add64 i_bcd_add( .ina( trial ), .inb( sum_part1 ), .sum( bcd_sum ));

	// Sum register / cleared reset
	logic [63:0] sum_part1; // BCD sum of invalid IDs
	always_ff @(posedge clk) begin
		if(  reset ) begin 
			sum_part1 <= 0;
		end else if( valid  && in_range ) begin
			sum_part1 <= bcd_sum;
		end else begin
			sum_part1 <= sum_part1;
		end
	end
	assign sum1 = sum_part1;
	assign wready = !valid; // wready will drop on last write of range, and finish when ready for anoth
endmodule

module bcd_inc32 (
	input logic [7:0][3:0] in,
	output logic [7:0][3:0] out
	);
	logic [8:0] c;
	always_comb begin // should be a loop, but ... verilator?
		c[0] = 1;
		out[0] = (in[0]==4'h9&&c[0])?4'h0:in[0]+c[0]; c[1]=(in[0]==4'h9&&c[0])?1'b1:1'b0;
		out[1] = (in[1]==4'h9&&c[1])?4'h0:in[1]+c[1]; c[2]=(in[1]==4'h9&&c[1])?1'b1:1'b0;
		out[2] = (in[2]==4'h9&&c[2])?4'h0:in[2]+c[2]; c[3]=(in[2]==4'h9&&c[2])?1'b1:1'b0;
		out[3] = (in[3]==4'h9&&c[3])?4'h0:in[3]+c[3]; c[4]=(in[3]==4'h9&&c[3])?1'b1:1'b0;
		out[4] = (in[4]==4'h9&&c[4])?4'h0:in[4]+c[4]; c[5]=(in[4]==4'h9&&c[4])?1'b1:1'b0;
		out[5] = (in[5]==4'h9&&c[5])?4'h0:in[5]+c[5]; c[6]=(in[5]==4'h9&&c[5])?1'b1:1'b0;
		out[6] = (in[6]==4'h9&&c[6])?4'h0:in[6]+c[6]; c[7]=(in[6]==4'h9&&c[6])?1'b1:1'b0;
		out[7] = (in[7]==4'h9&&c[7])?4'h0:in[7]+c[7];
	end
endmodule

module bcd_add64 (
	input logic [15:0][3:0] ina,
	input logic [15:0][3:0] inb,
	output logic [15:0][3:0] sum
	);
	logic [16:0] c;
	always_comb begin // should be a loop, but ...
		c[0] = 0;
		for( int ii = 0; ii < 16; ii++ ) begin
		sum[ii] = ( {1'b0,ina[ii]} + {1'b0,inb[ii]} + {4'b0000,c[ii]} > 5'd9  ) ?
 			  ( {1'b0,ina[ii]} + {1'b0,inb[ii]} + {4'b0000,c[ii]} - 5'd10 ) :
 			  ( {1'b0,ina[ii]} + {1'b0,inb[ii]} + {4'b0000,c[ii]}         ) ;
		c[ii+1]=  ( {1'b0,ina[ii]} + {1'b0,inb[ii]} + {4'b0000,c[ii]} > 5'd9  ) ? 1'b1 : 1'b0;
		end
	end
endmodule
