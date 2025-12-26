
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
						@(negedge clk);
						wvalid = 1;
						wuser = 7;
						wdata = 0;
						@(negedge clk);
						wuser = 3'b001; // target phase
						wvalid = 0;
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
						//$display( "W Target %d %d %d %b",  wvalid, wuser, wdata, wdata[9:0] );
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
							//$display( "W Joltage %d %d %d",  wvalid, wuser, wdata );
							@(negedge clk);
							wdata = 0;
						end
					end
				")" : 	begin
						wvalid = 1;
						//$display( "W Button %d %d %d %b",  wvalid, wuser, wdata, wdata[9:0] );
						@(negedge clk);
				      	end
				"{" : 	begin
						wuser = 3'b100; // button phase
						wdata = 0;
					end
				"}" : 	begin
						wvalid = 1;
						wlast = 1;
						//$display( "W Joltage %d %d %d",  wvalid, wuser, wdata );
						@(negedge clk);
					end
				8'h0a : begin
						wdata = 0;
						wdata = 0;
						wvalid = 0;
						wlast = 0;
						//$display( "EOL");
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
	always_ff @(posedge clk) begin
		target <= ( reset ||  wvalid && wready && wuser == 7 ) ? 0 : ( wvalid && wready && wuser[0] ) ? wdata[9:0] : target;
	end

	// Button array max at 10
	// Shift in during button writes
	logic [13:0][9:0] button;
	logic [3:0] buttons;
	always_ff @(posedge clk) begin
		button <= ( reset ||  wvalid && wready && wuser == 7 ) ? 0 : ( wvalid && wready && wuser[1] ) ? { button[12:0], wdata[9:0] } : button;
		buttons<= ( reset ||  wvalid && wready && wuser == 7 ) ? 0 : ( wvalid && wready && wuser[1] ) ? buttons + 1 : buttons;
	end

	// Joltage shift in
	logic [9:0][8:0] joltage;
	logic [3:0] jolts; // generator count
	logic [8:0] max_jolt;
	always_ff @(posedge clk) begin
		joltage  <= ( reset ||  wvalid && wready && wuser == 7 ) ? 0 : ( wvalid && wready && wuser[2] ) ? { joltage[8:0], wdata[8:0] } : joltage;
		jolts    <= ( reset ||  wvalid && wready && wuser == 7 ) ? 0 : ( wvalid && wready && wuser[2] ) ? jolts + 1 : jolts;
		max_jolt <= ( reset ||  wvalid && wready && wuser == 7 ) ? 0 : ( wvalid && wready && wuser[2] && wdata[8:0] > max_jolt ) ? wdata[8:0] : max_jolt;
	end


	//////////////////////////////////////////////////////////////////
	// Behavior 10x10+1 Ax=b liner system upper triangular of [A|b]
	//////////////////////////////////////////////////////////////////
	//      Y     X
	logic signed [0:9][0:15][63:0] A;
	logic signed       [63:0] min_A, max_A;
	logic signed [0:15][63:0] temp;
	logic        [0:14][3:0] bclass; // 1-zero, 2-independant, 3-dependant
	logic [3:0] ni, max_ni, min_ni;
	logic [3:0] nd, max_nd, min_nd;
	logic [3:0] nz, max_nz, min_nz;
	integer Y, X;
	integer flag;
	logic signed [14:0][63:0] V;
	logic [2:0][8:0] depc;
	logic [63:0] count, min_count, sum_min_count;
	logic [14:0][3:0] bxpos, bypos;
	logic signed [63:0] dot_div, dot_sum;
	initial begin
	    min_A = 0; max_A = 0;
	    max_ni = 0; max_nd = 0; max_nz = 0;
	    min_ni = 15; min_nd = 15; min_nz = 15;
	    sum_min_count = 0;
   	    for( int count = 0; 1 ; count++ ) begin
		while( !(  wvalid && wready && wuser[2:0]==4 && wlast ) ) @(negedge clk); // wait for end of line
		$display("EQN %d", count );
		@( negedge clk);
		// Copy in buttons and joltage (reverse order of joltage)
		for( int yy = 0; yy < 10; yy++ ) begin
			A[yy][15] = joltage[jolts-1-yy]; // flip jolt order hack
			for( int xx = 0; xx < 15; xx++ ) begin
				A[yy][xx] = button[xx][yy];
			end
		end
		// dump matrix
		for( int yy = 0; yy < 10; yy++ ) 
				$display("%3d %3d %3d %3d %3d | %3d %3d %3d %3d %3d | %3d %3d %3d %3d %3d ||  %5d", 
					A[yy][0], A[yy][1],A[yy][2],A[yy][3],A[yy][4],A[yy][5],A[yy][6],A[yy][7],A[yy][8],A[yy][9],A[yy][10],A[yy][11],A[yy][12],A[yy][13],A[yy][14],A[yy][15] );
		// itterate and reduce
		X=0; Y=0;
		flag = 0;
		while( X<15 && Y<10 ) begin
			//$display("X,Y = [%d,%d]", Y, X );
			if( A[Y][X] == 0 ) begin
				//$display("A[%d][%d] == 0", Y, X );
				// Test if any non zero in COL below Y,X
				flag = Y;
				for( int yy = Y+1; yy < 10; yy++ ) begin
					if( A[yy][X] != 0 ) begin
						flag = yy;
					end
				end
				if( flag == Y ) begin // col Y and below zero
					//$display("All below A[%d][%d] are zero too, next col", Y, X );
					X++; // advance to next col and try again
				end else begin // swap rows
					//$display("Swap rows A[%d] and A[%d]", Y, flag );
					temp = A[flag];
					A[flag] = A[Y];
					A[Y] = temp;
				end
			end else begin
				// Zero out the column below A[X][Y] by reduction
				//$display("Zero column below A[%d][%d]", Y, X);
				for( int yy = Y+1; yy < 10; yy++ ) begin
					if( A[yy][X] != 0 ) begin // reduce to zero
						//$display("reduce rows A[%d]=A[%d]-A[%d]", yy, yy,  Y );
						for( int xx = X+1; xx < 16; xx++ ) begin
							A[yy][xx] = A[Y][X] * A[yy][xx] - A[yy][X] * A[Y][xx];
						end
						A[yy][X] = 0;
					end
				end
				// Step to next row, col
				//$display("Step X++, Y++");
				Y++;  X++;
			end
		end
		// dump matrix
		$display("[%d X %d] Triangular Matrix", buttons, jolts);
		for( int yy = 0; yy < 10; yy++ ) 
				$display("%3d %3d %3d %3d %3d | %3d %3d %3d %3d %3d | %3d %3d %3d %3d %3d ||  %5d", 
					A[yy][0], A[yy][1],A[yy][2],A[yy][3],A[yy][4],A[yy][5],A[yy][6],A[yy][7],A[yy][8],A[yy][9],A[yy][10],A[yy][11],A[yy][12],A[yy][13],A[yy][14],A[yy][15] );

		// Now walk diagonal and classify each variable 
		// 1-zero ,2-indepedant, 3-depeandant
		Y = 0;
		X = 0;
		nd = 0; ni = 0; nz = 0;
		while( X<15 && Y<10 ) begin
			if( A[Y][X] == 0 ) begin
				flag = 0;
				for( int yy = 0; yy < Y; yy++ )
					if( A[yy][X] != 0 ) flag = 1;
				bclass[X] = ( flag ) ? 2 : 1; // indepant or zero 
				nz = ( flag ) ? nz : nz+1;
				ni = ( flag ) ? ni+1: ni;
				X++;
			end else begin
				bclass[X] = 3;
				bxpos[X] = X;
				bypos[X] = Y;
				nd++;
				X++; Y++;
			end
		end
		for( int xx = X; xx < 15; xx++ ) begin
			flag = 0;
			for( int yy = 0; yy < Y; yy++ )
				if( A[yy][xx] != 0 ) flag = 1;
			bclass[xx] = ( flag ) ? 2 : 1; // indepant or zero 
			nz = ( flag ) ? nz : nz+1;
			ni = ( flag ) ? ni+1: ni;
		end
		$display("Bclass %h", bclass );
		
		// Generating indpendant and evaluating dependants
		V[14:0] = 0; // zero all variables at start
		depc = 0; // zero independant varaibles upon which others depend
		min_count = -1;
		// Solve at 
		//$display("NI %d" , ni );
		$display("NI %0d, Max %0d", ni, max_jolt);
		while(  ni == 0 && depc[0] == 0 || // single solution
			ni == 1 && depc[0] <= max_jolt || 
			ni == 2 && depc[0] <= max_jolt && depc[1] <= max_jolt ||
			ni == 3 && depc[0] <= max_jolt && depc[1] <= max_jolt && depc[2] <= max_jolt ) begin
			//$display("NI %0d, Max %0d, DEP[0] = %3d DEP[1] = %3d DEP[2] = %3d", ni, max_jolt, depc[0], depc[1], depc[2] );
			// Zero V
			V = 0;
			// walk the list and insert independant varaibles // firstk
			count = 0;
			for( int idx = 0; idx < 15; idx++ )
				if( bclass[idx] == 2 ) 
					V[idx] = depc[count++];
			//$display("V=[trial] = %0d %0d %0d %0d %0d | %0d %0d %0d %0d %0d | %0d %0d %0d %0d %0d ]",   //////////////////////
			//	V[0],V[1],V[2],V[3],V[4],V[5],V[6],V[7],V[8],V[9],V[10],V[11],V[12],V[13],V[14]); ////////////////
			// evalutate the variables from 14:0
			flag = 0; // set if invalid soln
			for( int idx = 14; idx >= 0; idx-- ) begin
				if( bclass[idx] == 3 ) begin // evaluate
					dot_div = A[bypos[idx]][bxpos[idx]];
					dot_sum = A[bypos[idx]][15]; // =b
					for( int xx = bxpos[idx]+1; xx < 15; xx++ )
						dot_sum -= A[bypos[idx]][xx] * V[xx];
				//if( dot_div == 0 ) $display("Infinite Button");
				//if( dot_sum % dot_div != 0 ) $display("Frac Button");
				//if( dot_sum / dot_div < 0 ) $display("Neg Button");
					if( dot_sum % dot_div != 0 || dot_sum / dot_div < 0 ) 
						flag = 1;
					V[idx] = dot_sum / dot_div;
				end
			//$display("V[%2d] = %0d %0d %0d %0d %0d | %0d %0d %0d %0d %0d | %0d %0d %0d %0d %0d ]",idx,   //////////////////////
			//	V[0],V[1],V[2],V[3],V[4],V[5],V[6],V[7],V[8],V[9],V[10],V[11],V[12],V[13],V[14]); ////////////////
			end
			if( !flag )
			$display("V[solve] = [ %0d %0d %0d %0d %0d | %0d %0d %0d %0d %0d | %0d %0d %0d %0d %0d ] %0d",   //////////////////////
				V[0],V[1],V[2],V[3],V[4],V[5],V[6],V[7],V[8],V[9],V[10],V[11],V[12],V[13],V[14], flag); ////////////////

			// Count Button presses
			if( flag == 0 ) begin
		 		count = 0;
				for( int idx = 0; idx < 15; idx++ )
					count += V[idx];
				//$display("min_count %0d count %0d ",min_count, count );
				min_count = ( count < min_count ) ? count : min_count;
			end
			

			// step to next dependant
			depc[2] = ( ni ==3 && depc[0] == max_jolt && depc[1] == max_jolt ) ? depc[2]+1: depc[2];
			depc[1] = ( ni > 2 && depc[0] == max_jolt && depc[1] == max_jolt ) ? 0 : ( depc[0] == max_jolt ) ? depc[1]+1 : depc[1];
			depc[0] = ( ni > 1 && depc[0] == max_jolt ) ? 0 : depc[0]+1;
		end
		$display("min_count %0d ",min_count);
		sum_min_count += min_count;
		$display("sum_min_count %0d ",sum_min_count);	// Part 2 answer

		// Statistics
		// Update COeff min/max
        	$display("Classificatin: %0h", bclass );
		$display("ND %0d NI %0d, NZ %0d", nd, ni, nz );
		if( nd + ni + nz != 15 )
			$display("ASSERT total [%0d] must be 15", nd + ni + nz );
		// Do some min/maxes so we can see the ranges 
		for( int xx = 0; xx < 16; xx++ ) begin
			for( int yy = 0; yy < 10; yy++ ) begin
				min_A = ( A[yy][xx] < min_A ) ? A[yy][xx] : min_A;
				max_A = ( A[yy][xx] > max_A ) ? A[yy][xx] : max_A;
			end
		end
	    	if( ni > max_ni ) max_ni = ni;
	    	if( nd > max_nd ) max_nd = nd;
	    	if( nz > max_nz ) max_nz = nz;
	    	if( ni < min_ni ) min_ni = ni;
	    	if( nd < min_nd ) min_nd = nd;
	    	if( nz < min_nz ) min_nz = nz;
		$display("MIN/MAX ni %0d/%0d nd %0d/%0d nz %0d/%0d A%0d/%0d", min_ni, max_ni, min_nd, max_nd, min_nz, max_nz, min_A, max_A );
	    end

	    @( negedge clk);
	end

	//////////////////////////////////////////////////////////////////
	// END Behavioral
	//////////////////////////////////////////////////////////////////
	

	// Counter, shifts in 1's with each button, and then count down to
	// zero
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
	                ( ( !count[12] ) ? 0 : button[12] ) ;

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
	//always_ff @(posedge clk) begin
	//	if( !wready && lights == target )
	//		$display( "hit count 0x%x %b", count, count );
	//end
	
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
		//if( wready && !wready_d ) 
		//	$display("Fewest presses %d", min_presses );
	end
	
	// We'll just have sum2 count machines for now
	always_ff @(posedge clk) 
		sum2 <= ( reset ) ? 0 : ( wvalid && wlast ) ? sum2 + 1 : sum2;

endmodule

// synthesizable, combinatorial, solver
// targets day 10 part 2
module solve_13x10( // Solve for x, in eqn Ax=b, with up to 3 independant inputs
	input  logic [9: 0][12:0] a_in,	  // A[10][13] fo binary dayat
	input  logic [9: 0][8: 0] b_in,   // b[10] of target data
	output logic [12:0][8: 0] x_out,  // x[13] soluion outputs
	output logic [12:0]       x_sum,  // sum of the x[] array
	output logic              posint, // flag if x_out are all positive integers
	output logic [1: 0]   	  nind,	  // num independant variables ranges from 0 to 3
	input  logic [2: 0][8: 0] ind  	  // Three independant x inputs using [nind:0] 
	);

	// format input data into arrays


	// Unrolled Gaussian ellimination
	// 0th stage is input
	// Odd - Find 1st significant coeff (step and roll)
	// Even - Reduce non-zero coeff below significnt to zero
	// 20th stage will be in eschelon form (upper triangular)
	//           Stage row  col  signed
	logic signed [0:20][0:9][0:13][63:0] A;
	logic [20:0][3:0] sig_row, sig_col;
	logic [20:0][0:12][9:0] nz;
	logic [20:0][3:0] X, Y;
	always_comb begin // Flag significant columns
	   // K == 0 init from inputs
	   for( yy = 0; yy < 10; yy++ ) begin
		   A[0][yy][13] = b_in[yy];
		   for( int xx = 0; xx < 13; xx++ )
			   A[0][yy][xx] = a_in[yy][xx];
	   end
	   // Start in upper left corner
	   X[0] = 0; Y[0] = 0;
	   for( int k = 1; k <= 20; k++ ) begin

		if( k & 1 ) begin // Odd K:

			// find 1st significant coeff column
			for( int xx = 0; xx < 13; xx++ ) begin
				for( int yy = 0; yy < 10; yy++ ) // find sig cells and format for col reduction OR
					nz[k][xx][yy] = ( A[k-1][yy][xx] != 0 && xx >= X[k-1] && yy >= Y[k-1] ) ? 1'b1 : 1'b0;
			end
			// Update to next sig working column
			Y[k] = Y[k-1];
			X[k] =  ( |nz[k][ 0] ) ?  0 : ( |nz[k][ 1] ) ?  1 : ( |nz[k][ 2] ) ?  2 : ( |nz[k][ 3] ) ?  3 :
				( |nz[k][ 4] ) ?  4 : ( |nz[k][ 5] ) ?  5 : ( |nz[k][ 6] ) ?  6 : ( |nz[k][ 7] ) ?  7 :
				( |nz[k][ 8] ) ?  8 : ( |nz[k][ 9] ) ?  9 : ( |nz[k][10] ) ? 10 : ( |nz[k][11] ) ? 11 :
			( |nz[k][12] ) ? 12 : 15;
			// find sig row in the sig col
			sig_row[k] = nz[k][X[k]][0] ? 0 : nz[k][X[k]][1] ? 1 : nz[k][X[k]][2] ? 2 :
				     nz[k][X[k]][3] ? 3 : nz[k][X[k]][4] ? 4 : nz[k][X[k]][5] ? 5 :
				     nz[k][X[k]][6] ? 6 : nz[k][X[k]][7] ? 7 : nz[k][X[k]][8] ? 8 : 15 ;
			// barrel shift row into place
			for( int yy = 0; yy < 10; yy++ ) begin
				if( yy < Y[k] ) begin
				  	A[k][yy] = A[k-1][yy]; // not involved, just copy
				end else if( yy >= Y[k] && yy-Y[k]+sig_row < 10 ) begin
					A[k][yy] = A[k-1][yy-Y[k]+sig_row[k]];
				end else begin
					A[k][yy] = A[k-1][yy+sig_row[k]-10];
				end
			end

		end else begin // Even K
			
			// Gausion ellimination on even k
			for( int yy = 0; yy < 9; yy++ ) begin
				if( yy < Y[k-1] || A[k-1][yy][X[k-1]] == 0 ) begin // above us, or already a zero/reduced
					A[k][yy] = A[k-1][yy];
				end else for( int xx = 0; xx < 14; xx++ ) begin // reducde
					A[k][yy][xx] = ( xx <= X[k-1] ) ? 0 : A[k-1][yy][X[k-1]] * A[k-1][0][xx] - A[k-1][0][X[k-1]] * A[k-1][yy][xx];
				end
			end
			X[k] = X[k-1] + 1;
			Y[k] = X[k-1] + 1;
	        end // Even
	    end // k
	    // A[20] is in eschelon order
	    // x[2*k
	end // always
	
	// Build Solve array & Map out the non-zero rows and columns
	logic [9:0][13:0][63:0] S; 
	logic [9:0][12:0] map_r;
	logic [12:0][9:0] map_c;
	logic [9:0][12:0] mul_r; // Flags all cells after 1st sig in a row
	logic [9:0][12:0] piv_r; // Flags flags first non-zero in a row
	logic [12:0][9:0] piv_c; 
	always_comb begin
		for( int yy = 0; yy < 9; yy++ ) begin
			for( int xx = 0; xx < 12; xx++ ) begin
				S[yy][xx] = ( xx < yy ) ? 0 : A[20][yy][xx];
				map_c[xx][yy] = ( S[yy][xx] != 0 ) ? 1'b1 : 1'b0;
				map_r[yy][xx] = map_c[xx][yy];
				mul_r[yy][xx] = ( xx == 0 ) ? 0 : map_r[yy][xx-1] | mul_r[yy][xx-1];
				piv_r[yy][xx] = piv_c[xx][yy];
				piv_c[xx][yy] = map_r[yy][cc] & !mul_r[yy][xx];
			end
		end
	end

	// calculate right hand side per row (b - sum of products);
	logic [9:0][63:0] sum_prod;
	logic [9:0][63:0] pivot;
	always_comb begin
		for( int yy = 9; yy >= 0; yy-- ) begin // bot up loop
			sum_prod[yy] = S[yy][13] -
				      ((( mul_r[yy][ 1] ) ? S[yy][ 1] * V[ 1] : 0 ) +
			               (( mul_r[yy][ 2] ) ? S[yy][ 2] * V[ 2] : 0 ) +
			               (( mul_r[yy][ 3] ) ? S[yy][ 3] * V[ 3] : 0 ) +
			               (( mul_r[yy][ 4] ) ? S[yy][ 4] * V[ 4] : 0 ) +
			               (( mul_r[yy][ 5] ) ? S[yy][ 5] * V[ 5] : 0 ) +
			               (( mul_r[yy][ 6] ) ? S[yy][ 6] * V[ 6] : 0 ) +
			               (( mul_r[yy][ 7] ) ? S[yy][ 7] * V[ 7] : 0 ) +
			               (( mul_r[yy][ 8] ) ? S[yy][ 8] * V[ 8] : 0 ) +
			               (( mul_r[yy][ 9] ) ? S[yy][ 9] * V[ 9] : 0 ) +
			               (( mul_r[yy][10] ) ? S[yy][10] * V[10] : 0 ) +
			               (( mul_r[yy][11] ) ? S[yy][11] * V[11] : 0 ) +
			               (( mul_r[yy][12] ) ? S[yy][12] * V[12] : 0 ));
			pivot[yy] =    (( piv_r[yy][ 0] ) ? S[yy][ 0] : 0 ) | // Select mux
			               (( piv_r[yy][ 1] ) ? S[yy][ 1] : 0 ) |
			               (( piv_r[yy][ 2] ) ? S[yy][ 2] : 0 ) |
			               (( piv_r[yy][ 3] ) ? S[yy][ 3] : 0 ) |
			               (( piv_r[yy][ 4] ) ? S[yy][ 4] : 0 ) |
			               (( piv_r[yy][ 5] ) ? S[yy][ 5] : 0 ) |
			               (( piv_r[yy][ 6] ) ? S[yy][ 6] : 0 ) |
			               (( piv_r[yy][ 7] ) ? S[yy][ 7] : 0 ) |
			               (( piv_r[yy][ 8] ) ? S[yy][ 8] : 0 ) |
			               (( piv_r[yy][ 9] ) ? S[yy][ 9] : 0 ) |
			               (( piv_r[yy][10] ) ? S[yy][10] : 0 ) |
			               (( piv_r[yy][11] ) ? S[yy][11] : 0 ) |
			               (( piv_r[yy][12] ) ? S[yy][12] : 0 ) ;
		end
	end
			
	// do row divides Vrow = sum_prod / pivot, and check all for neg_frac
	logic [9:0][8:0] row_result; // output is unsigned 9 bit pos int unless flagged
	logic [9:0]       neg_frac;	
	day10_div i_div0( .num( sum_prod[0]), .denom( pivot[0] ), .out( row_result[0] ), .neg_frac( neg_frac[0] ) );
	day10_div i_div1( .num( sum_prod[1]), .denom( pivot[1] ), .out( row_result[1] ), .neg_frac( neg_frac[1] ) );
	day10_div i_div2( .num( sum_prod[2]), .denom( pivot[2] ), .out( row_result[2] ), .neg_frac( neg_frac[2] ) );
	day10_div i_div3( .num( sum_prod[3]), .denom( pivot[3] ), .out( row_result[3] ), .neg_frac( neg_frac[3] ) );
	day10_div i_div4( .num( sum_prod[4]), .denom( pivot[4] ), .out( row_result[4] ), .neg_frac( neg_frac[4] ) );
	day10_div i_div5( .num( sum_prod[5]), .denom( pivot[5] ), .out( row_result[5] ), .neg_frac( neg_frac[5] ) );
	day10_div i_div6( .num( sum_prod[6]), .denom( pivot[6] ), .out( row_result[6] ), .neg_frac( neg_frac[6] ) );
	day10_div i_div7( .num( sum_prod[7]), .denom( pivot[7] ), .out( row_result[7] ), .neg_frac( neg_frac[7] ) );
	day10_div i_div8( .num( sum_prod[8]), .denom( pivot[8] ), .out( row_result[8] ), .neg_frac( neg_frac[8] ) );
	day10_div i_div9( .num( sum_prod[9]), .denom( pivot[9] ), .out( row_result[9] ), .neg_frac( neg_frac[9] ) );
	assign posint = !|neg_frac; // flag if solution will be positive integers
	
	// Pivot Row results into columns

	// Build V with each element = mux14(  row[0..9], zero, dep[0..2] );
	// for column xx, 
	// if col[xx] contains a pivot |piv_c[xx] then v[xx] is reflected result
	// if col[xx] is all zero, then v[xx] = 0
	// else V is an its a independant input
	


	logic signed [0:12][8:0] V; // solution X
	// Prepart to solve by
	// - inserting known zero's into x
	// - signalling how many independant variables are needed
	// - inserting independants into x
	

	// Output data and flag
	assign sum_x = v[0]+v[1]+v[2]+v[3]+v[4]+v[5]+v[6]+v[7]+v[8]+v[9]+v[10]+v[11]+v[12];
	assign x_out = V;
	assign posint = !|neg_frac; 


	
	
endmodule

module day10_div (
	input logic [63:0] num,
	input logic [63:0] denom,
	output logic [8:0] out,
	output logic neg_frac
	);
	// Out = num / denom. Assert neg_frac if result is neg has remainder 
endmodule


	
