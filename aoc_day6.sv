
module day6_tb();

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
        $timeformat(-9, 0, "ns", 12); // 1: scale (ns=-9), 2: decimals, 3: suffix, 4: print-field width
        // configure FST (waveform) dump
        $dumpfile("day6.fst");
        $dumpvars(1,i_dut_part1);
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

	// Instantial day6 DUT
	logic [7:0] charcode;
	logic valid;
	logic go;
	logic done;
	logic [63:0] sum_part1;
	logic [63:0] sum_part2;
	day6_parts i_dut_part1 (
		.clk 	( clk ),
		.reset	( reset ),
		.part2  ( 1'b0 ),
		.data	( charcode ),
		.valid	( valid ),
		.sum	( sum_part1 )
	);
	day6_parts i_dut_part2 (
		.clk 	( clk ),
		.reset	( reset ),
		.part2  ( 1'b1 ),
		.data	( charcode ),
		.valid	( valid ),
		.sum	( sum_part2 )
	);
		
	// Read day6_puzzle.txt and write to HW 
    	integer file, c;
    	initial begin
		while( reset ) @(negedge clk); // wait for reset to finish
        	file = $fopen("day6_puzzle.txt", "r");
        	if( file ) begin
                	c = $fgetc(file);
                	while( c != -1 ) begin // until eof
				charcode = c;
				valid = 1;
				@(negedge clk);
                        	c = $fgetc(file);
        	        end
        	end else begin
                	$display("AOC puzzle.txt not found");
			$finish();
        	end
		valid = 1;
		charcode = 0;
		@(negedge clk);
		valid = 0;

		for( int ii = 0; ii < 10; ii++ ) @(negedge clk);
	
		// Report results
		$display("Day 6 Part 1 sum = 0x%h  (%d)", sum_part1, sum_part1 );
		$display("Day 6 Part 2 sum = 0x%h  (%d)", sum_part2, sum_part2 );
	
		// Done
		for( int ii = 0; ii < 10; ii++ ) @(negedge clk);
		$finish();
        end
endmodule

module day6_parts (
	input logic clk,
	input logic reset,
	input logic part2, 
	input logic [7:0] data,
	input logic valid, // Valid charcode
	output logic [63:0] sum // puzzle sum
	);


	logic [3:0] row;
	logic [11:0] idx;

	always_ff @(posedge clk) begin
		if( reset ) begin
			row <= 0;
			idx <= 0;
		end else begin
			row <= ( valid && data == 8'h0a ) ? row + 1 : row;
			idx <= ( valid && data == 8'h0a ) ? 0 : ( valid ) ? idx+1 : idx;
		end
	end

	// synthesizable RAMs (4Kbyte ea)
	// write the bytes from first 4 rows
	// Allign the rows so I can work with operating on colums of digits
	// Process the data while reading in last (+/*) control row.
	logic [7:0] row1_mem [0:4095];
	logic [7:0] row2_mem [0:4095];
	logic [7:0] row3_mem [0:4095];
	logic [7:0] row4_mem [0:4095];
	always @( posedge clk ) if( valid && row == 0 ) row1_mem[idx] <= data;
	always @( posedge clk ) if( valid && row == 1 ) row2_mem[idx] <= data;
	always @( posedge clk ) if( valid && row == 2 ) row3_mem[idx] <= data;
	always @( posedge clk ) if( valid && row == 3 ) row4_mem[idx] <= data;

	// During the 5th row read the memories in parallel into a window
	logic [4:0][4:0][7:0] win; 
	logic sep; 
	assign sep = ( ( win[0][0] == " " || win[0][0] == 8'h0A ) && // Col 0 contains a separator (or cr)
	               ( win[1][0] == " " || win[1][0] == 8'h0A ) &&
	               ( win[2][0] == " " || win[2][0] == 8'h0A ) &&
	               ( win[3][0] == " " || win[3][0] == 8'h0A ) &&
	               ( win[4][0] == " " || win[4][0] == 8'h0A ) ) ? 1'b1 : 1'b0;
	always @(posedge clk) begin
		if( reset ) begin
			win <= 0;
		end else if( row == 4 && valid ) begin
			win[0][4:0] <= { ( sep ) ? 32'h0 : win[0][3:0], row1_mem[idx] };
			win[1][4:0] <= { ( sep ) ? 32'h0 : win[1][3:0], row2_mem[idx] };
			win[2][4:0] <= { ( sep ) ? 32'h0 : win[2][3:0], row3_mem[idx] };
			win[3][4:0] <= { ( sep ) ? 32'h0 : win[3][3:0], row4_mem[idx] };
			win[4][4:0] <= { ( sep ) ? 32'h0 : win[4][3:0], data          }; // Operator * or |
		end
	end
	
	// Datapath to extract the BCD digits from the window
	//   [row][col][bcd]
	logic [3:0][3:0][3:0] digit;
	always_comb begin
		for( int yy = 0; yy < 4; yy++ ) begin
			for( int xx = 0; xx < 4; xx++ ) begin
				if( !part2 ) begin // horizontal
					digit[yy][xx] = ( win[3-yy][xx+1] <= "9" && win[3-yy][xx+1] >= "1" ) ? win[3-yy][xx+1] - "0" : 4'h0;
				end else begin // part2 vertical
					digit[xx][yy] = ( win[3-yy][xx+1] <= "9" && win[3-yy][xx+1] >= "1" ) ? win[3-yy][xx+1] - "0" : 4'h0;
				end
			end
		end
	end

	// Use Part1(horizontal) or Part2(vertical) BCD numbers
	// Will be 2,3, or 4 numbers with lenth 1,2,3, or 4 digits lkong
	// can be leading and following blanks (coded as zero, since obsered they only use 1-9
	//    [row][col][bcd]  col is indexed by significance
	logic [3:0][3:0][3:0] just;
	logic [3:0][3:0] shift;
	always_comb begin
		for( int yy = 0; yy < 4; yy++ ) begin
			shift[yy] = ( |digit[yy][0]) ? 0 : (|digit[yy][1]) ? 1 : (|digit[yy][2]) ? 2 : 3;
			just[yy]  = { 16'h00,  digit[yy] } >> ( shift[yy] << 2 );
		end
	end

	// Covert BCD to binary (4 digits) if we don't use a BCD multiplierA
	logic [3:0][15:0] value;
	always_comb begin
		for( int yy = 0; yy < 4; yy++ ) begin
			value[yy] = just[yy][0] + 10 * just[yy][1] + 100 * just[yy][2] + 1000 * just[yy][3]; // placeholder?
		end
	end

	// Sum AND multiply the 4 numbers (part1) or 2,3,or4 numbers (part2)
	logic [63:0] add_result;
	logic [63:0] mult_result;
	always_comb begin
		add_result  = ({ 2'b00, value[0]} + { 2'b00, value[1]}) + ({ 2'b00, value[2]} + { 2'b00, value[3]});
		mult_result = ((( |value[0] ) ? value[0] : 1 ) * (( |value[1] ) ? value[1] : 1 )) *
		              ((( |value[2] ) ? value[2] : 1 ) * (( |value[3] ) ? value[3] : 1 ));
	end

	// Determine the current OP
	logic add_flag, mult_flag;
	assign add_flag = ( win[4][4] == "+" || win[4][3] == "+" || win[4][2] == "+" || win[4][1] == "+" ) ? 1'b1 : 1'b0;
	assign mult_flag =( win[4][4] == "*" || win[4][3] == "*" || win[4][2] == "*" || win[4][1] == "*" ) ? 1'b1 : 1'b0;

	// Select and Accumulate the result value based on the + vs * operation.
	always @(posedge clk) begin
		if( reset ) begin
			sum <= 0;
		end else if( valid && sep ) begin
			sum <= sum + (( mult_flag ) ? mult_result :  add_result);
		end
	end
endmodule
