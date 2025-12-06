
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

	// Instantial day5 DUT
	logic [63:0] din;
	logic we_upper;
	logic we_lower;
	logic we_cand;
	logic [15:0] hit_count;
	day5_part1 i_dut (
		.clk ( clk ),
		.din ( din ),
		.we_upper( we_upper ),
		.we_lower( we_lower ),
		.we_cand(  we_cand ),
		.hit_count( hit_count )
	);
	
		
	// Read day5_puzzle.txt
    	integer file, c;
	logic [63:0] in; // Input word
	logic [7:0] charcode;
	logic [3:0] bcd_digit;
	logic data_phase;
	logic expect_digit;
    	initial begin
        	file = $fopen("day5_puzzle.txt", "r");
		din = 0;
		data_phase = 0;
		expect_digit = 0;
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
						expect_digit = 0;
					end
				"-" : // Lower upper separator
					begin
						$display("Lower %h", din );
						@(negedge clk);
						we_lower = 1;
						@(negedge clk);
						we_lower = 0;
						din = 0;
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
							@(negedge clk);
							we_upper= 1;
							@(negedge clk);
							we_upper= 0;
							din = 0;
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
		for( int ii = 0; ii < 300; ii++ )
			@(negedge clk);
		$display("Day 5 part 1 = %d", hit_count );
		$finish();
    	end


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
