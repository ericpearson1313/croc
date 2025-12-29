
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
                for( int ii = 0; ii < 200000000; ii++ ) begin
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
        	$dumpvars(1,i_day10_g);
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
	// includes a beavioral part 2
	
	logic wready1, wready2;
	assign wready = wready1 & wready2;
	aoc_day10 i_day10 (
		.clk	( clk ),
		.reset	( reset ),
		.wvalid	( wvalid & wready ),
		.wready	( wready1 ),
		.wdata 	( wdata  ),
		.wuser 	( wuser  ),
		.wlast 	( wlast  ),
		.sum1   ( sum1 ),
		.sum2   ( )
	);

	// Instantiate fully synthesizable gaussian solver for part 2 (could also do part 1)
	logic [31:0] sum1g;
	logic [63:0] sum2g;
	aoc_day10_gaussian i_day10_g (
		.clk	( clk ),
		.reset	( reset ),
		.wvalid	( wvalid & wready ),
		.wready ( wready2 ),
		.wdata 	( wdata  ),
		.wuser 	( wuser  ),
		.wlast 	( wlast  ),
		.sum2   ( sum2   )
	);
	
endmodule


// Uses a synthesizable 13x10 solver for day10 part 1 and part 2 solutions
module aoc_day10_gaussian (
	input logic clk,
	input logic reset,
	input logic wvalid,
	input logic wlast,
	input logic [2:0] wuser,
	input logic [15:0] wdata,
	output logic wready,
	output logic [63:0] sum2
	);

	//assign wready = 1;
	//assign sum2 = 64'hABCDEF0123456789;

	/////////////////
	// Shift In data
	/////////////////

	// load button data (a_in)
	logic [9: 0][12:0] buttons;
	logic [3:0] bcnt;
	always_ff @(posedge clk) begin
		if( reset || wvalid && wready && wuser == 7 ) begin
			buttons <= 0;
			bcnt <= 0;
		end else if( wvalid && wready && wuser == 2 ) begin
			bcnt <= bcnt + 1;
			for( int yy = 0; yy < 10; yy++ ) begin
				buttons[yy] <= { buttons[yy][11:0], wdata[yy]};
			end
		end
	end

	// load Joltage data
	logic [9:0][8:0] joltage;
	logic [3:0] jcnt;
	logic [8:0] max_jolts;
	always_ff @(posedge clk) begin
		if( reset || wvalid && wready && wuser == 7 ) begin
			joltage <= 0;
			jcnt <= 0;
			max_jolts <= 0;
		end else if ( wvalid && wready && wuser == 4 ) begin
			max_jolts <= ( wdata[8:0] > max_jolts ) ? wdata[8:0] : max_jolts;
			joltage[jcnt] <= wdata[8:0];
			jcnt <= jcnt + 1;
		end
	end

	/////////////////
	// Find best soln
	/////////////////
	
	// Start pulse after last write
	logic start;
	logic start_d; // input regs valid
	assign start = ( wvalid && wready && wlast && wuser == 4 ) ? 1'b1 : 1'b0;
	always @(posedge clk)
		start_d <= start;
	
	// Done when we've itterated any/all indpendant variables
	logic [1:0] num_ind; // number of independant variables (from solver )
	logic [2:0][8:0] ind;
	logic done;
	assign done = ( num_ind == 0 ||
                        num_ind == 1 && ind[0] == max_jolts ||
                        num_ind == 2 && ind[0] == max_jolts && ind[1] == max_jolts ||
                        num_ind == 3 && ind[0] == max_jolts && ind[1] == max_jolts && ind[2] == max_jolts ) ? 1'b1: 1'b0;

	// wready is asserted
	logic wready_d;
	always @(posedge clk) begin
		wready <= ( reset ) ? 1 : ( start ) ? 0 : ( !wready && done ) ? 1 : wready;
		wready_d <= wready;
	end

	// Sweep independanr bariables
	always_ff @(posedge clk) begin
		if( wready ) begin
			ind <= 0;
		end else if( done ) begin
			ind <= 0;
		end else begin
			ind[0] <= ( ind[0] == max_jolts ) ? 0 : ind[0] + 1;
			ind[1] <= ( ind[0] == max_jolts && ind[1] == max_jolts ) ? 0 : 
				  ( ind[0] == max_jolts ) ? ind[1] + 1 : ind[1];
			ind[2] <= ( ind[0] == max_jolts && ind[1] == max_jolts ) ? ind[2] + 1 : ind[2];
		end
	end

	/////////////////
	// Track/Sum Best
	/////////////////
	
	logic [12:0] best;
	logic [12:0] presses; // solution cost in presses
	logic        val_sol; // solution is valid
	always @(posedge clk) begin
		best <= ( wvalid && wready && wuser == 7 ) ? 13'h1FFF : ( !wready && val_sol && presses < best ) ? presses : best;
		sum2 <= ( reset ) ? 0 : ( wready && !wready_d ) ? sum2 + best : sum2;
	end

	/////////////////
	// 13x10 Solver
	/////////////////
	  
	logic signed [9:0][13:0][63:0] E; // Eschelon format array
	gauss_13x10 i_gauss( // Reduce to eschelon format
		.clk    ( clk     ),
		.trig   ( !reset && wready && !wready_d ),
		.a_in	( buttons ),
		.b_in	( joltage ),
		.E      ( E       )
	);

	logic [12:0][8:0] V;
	//logic signed [12:0][63:0] V;
	solve_13x10 i_solve( // Solve for x, in eqn Ax=b, with up to 3 independant inputs
		.S      ( E       ),
		.x_out	( V       ),
		.x_sum	( presses ),
		.posint	( val_sol ),
		.nind	( num_ind ),
		.ind	( ind     ) 
	);

	always @(negedge clk) begin
		if( !wready && val_sol )
		$display("S[solve] = [ %0d %0d %0d %0d %0d | %0d %0d %0d %0d %0d | %0d %0d %0d ] (%b) Presses %0d",
			V[0],V[1],V[2],V[3],V[4],V[5],V[6],V[7],V[8],V[9],V[10],V[11],V[12], val_sol, presses); 
	end
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

// Gausian ellimination of [A|b] a 14x10 array
// Synthesizable, combinatorial
module gauss_13x10 (
	input  logic clk, // debug only
	input  logic trig, // debug only
	input  logic [9:0][12:0] a_in,  // A[10][13] fo binary dayat
	input  logic [9:0][8:0]  b_in,  // b[10] of target data
	output logic signed [9:0][13:0][63:0] E // Eschelon format array
	);

	// Unrolled Gaussian ellimination
	// 0th stage is input
	// Odd - Find 1st significant coeff (step and roll)
	// Even - Reduce non-zero coeff below significnt to zero
	// 20th stage will be in eschelon form (upper triangular)
	//           Stage row  col  signed
	logic signed [10:0][9:0][13:0][63:0] A;
	logic signed [10:0][9:0][13:0][63:0] B;
	logic        [10:0]      [3:0] sig_row;
	logic        [10:0][12:0][9:0] nz;
	logic        [10:0]      [3:0] X, Y;
	logic        [10:0]      [3:0] Xa, Ya;

	always_comb begin // roll/reduce 
	   	A = 0;
	   	B = 0;
	   	Xa = 0; 
	   	Ya = 0;
	   	X = 0; 
	   	Y = 0;
	   	sig_row = 0;
	   	nz = 0;
	
	   	// K == 0 init from inputs
	   	for( int yy = 0; yy < 10; yy++ ) begin
		   	B[0][yy][13] = b_in[yy];
		   	for( int xx = 0; xx < 13; xx++ )
			   	B[0][yy][xx] = a_in[yy][xx];
	   	end

	   	// Start in upper left corner
	   	for( int k = 1; k <= 10; k++ ) begin

			// find 1st significant coeff column
			for( int xx = 0; xx < 13; xx++ ) begin
				for( int yy = 0; yy < 10; yy++ ) // find sig cells and format for col reduction OR
					nz[k][xx][yy] = ( B[k-1][yy][xx] != 0 && xx >= X[k-1] && yy >= Y[k-1] ) ? 1'b1 : 1'b0;
			end
			// Update to next sig working column
			Ya[k] = Y[k-1];
			Xa[k] =  ( |nz[k][ 0] ) ?  0 : ( |nz[k][ 1] ) ?  1 : ( |nz[k][ 2] ) ?  2 : ( |nz[k][ 3] ) ?  3 :
				 ( |nz[k][ 4] ) ?  4 : ( |nz[k][ 5] ) ?  5 : ( |nz[k][ 6] ) ?  6 : ( |nz[k][ 7] ) ?  7 :
				 ( |nz[k][ 8] ) ?  8 : ( |nz[k][ 9] ) ?  9 : ( |nz[k][10] ) ? 10 : ( |nz[k][11] ) ? 11 :
			         ( |nz[k][12] ) ? 12 : 15;
			// find sig row in the sig col
			sig_row[k] = nz[k][Xa[k]][9] ? 9 : nz[k][Xa[k]][8] ? 8 : nz[k][Xa[k]][7] ? 7 :
				     nz[k][Xa[k]][6] ? 6 : nz[k][Xa[k]][5] ? 5 : nz[k][Xa[k]][4] ? 4 :
				     nz[k][Xa[k]][3] ? 3 : nz[k][Xa[k]][2] ? 2 : nz[k][Xa[k]][1] ? 1 : nz[k][Xa[k]][0] ? 0 : 15 ;
			// swap row into place (note upgrade to barrel shift
			if( Xa[k] == 15 || nz[k][Xa[k]][Ya[k]] || sig_row[k] == Ya[k] ) begin
				A[k] = B[k-1]; // done, or alreay sig pivot
			end else for( int yy = 0; yy < 10; yy++ ) begin
				if( yy < Ya[k] ) begin
				  	A[k][yy] = B[k-1][yy]; // not involved, just copy
				end else if( yy == Ya[k] ) begin
					A[k][yy] = B[k-1][sig_row[k]]; // swap
				end else if( yy == sig_row[k] ) begin
					A[k][yy] = B[k-1][Ya[k]]; // swap
				end else begin
					A[k][yy] = B[k-1][yy]; // copy
				end
			end

			// Gausion ellimination 
			for( int yy = 0; yy < 10; yy++ ) begin
				if( yy <= Ya[k] || Xa[k] == 15 || A[k][yy][Xa[k]] == 0 ) begin // above us, or already a zero/reduced
					B[k][yy] = A[k][yy];
				end else for( int xx = 0; xx < 14; xx++ ) begin // reducde
					B[k][yy][xx] = ( xx <= Xa[k] ) ? 0 : 
						       //A[k][yy][Xa[k]] * A[k][Ya[k]][xx] - A[k][Ya[k]][Xa[k]] * A[k][yy][xx];
						       A[k][Ya[k]][Xa[k]] * A[k][yy][xx] - A[k][yy][Xa[k]] * A[k][Ya[k]][xx];
				end
			end
			X[k] = ( Xa[k] == 15 ) ? 15 : Xa[k] + 1;
			Y[k] = Ya[k] + 1;
	    	end // k
	end // always

	// Dump B matrix's
	always @(negedge clk) if( trig ) begin
		for( int k = 10; k <= 10; k++ ) begin
			if( k > 0 && 0 ) begin
				$display("A[%0d]=", k );
				for( int yy = 0; yy < 10; yy++ ) 
					$display("%3d %3d %3d %3d %3d | %3d %3d %3d %3d %3d | %3d %3d %3d  ||  %5d", 
						A[k][yy][0], A[k][yy][1], A[k][yy][2], A[k][yy][3],
						A[k][yy][4], A[k][yy][5], A[k][yy][6], A[k][yy][7],
						A[k][yy][8], A[k][yy][9], A[k][yy][10], A[k][yy][11],
						A[k][yy][12], A[k][yy][13] );
			end
			$display("B[%0d]=", k );
			for( int yy = 0; yy < 10; yy++ ) 
				$display("%3d %3d %3d %3d %3d | %3d %3d %3d %3d %3d | %3d %3d %3d  ||  %5d", 
					B[k][yy][0], B[k][yy][1], B[k][yy][2], B[k][yy][3],
					B[k][yy][4], B[k][yy][5], B[k][yy][6], B[k][yy][7],
					B[k][yy][8], B[k][yy][9], B[k][yy][10], B[k][yy][11],
					B[k][yy][12], B[k][yy][13] );
		end
	end
	

	// Assign output
	always_comb 
		for( int yy = 0; yy < 10; yy++ ) 
		   	for( int xx = 0; xx < 14; xx++ )
			   	E[yy][xx] = ( xx < yy ) ? 0 : B[10][yy][xx];
	
endmodule




// synthesizable, combinatorial, solver
// targets day 10 part 2
module solve_13x10( // Solve for x, in eqn Ax=b, with up to 3 independant inputs
	input logic signed [9:0][13:0][63:0] S, // Eschelon format array to bw solved
	output logic [12:0][8: 0] x_out,  // x[13] soluion outputs (clipped ints)
	//output logic signed [12:0][63: 0] x_out,  // x[13] soluion outputs (clipped ints)
	output logic [12:0]       x_sum,  // sum of the x[] array
	output logic              posint, // flag if x_out are all positive integers
	output logic [1: 0]   	  nind,	  // num independant variables ranges from 0 to 3
	input  logic [2: 0][8: 0] ind  	  // Three independant x inputs using [nind:0] 
	);

	// Build Solve array & Map out the non-zero rows and columns
	logic [9:0][12:0] map_r;
	logic [12:0][9:0] map_c;
	logic [9:0][12:0] mul_r; // Flags all cells after 1st sig in a row
	logic [9:0][12:0] piv_r; // Flags flags first non-zero in a row
	logic [12:0][9:0] piv_c; 
	always_comb begin
		mul_r = 0;
		for( int yy = 0; yy < 10; yy++ ) begin
			for( int xx = 0; xx < 13; xx++ ) begin
				map_c[xx][yy] = ( S[yy][xx] != 0 ) ? 1'b1 : 1'b0;
				map_r[yy][xx] = map_c[xx][yy];
				mul_r[yy][xx] = (xx==0) ? 0 : map_r[yy][xx-1] | mul_r[yy][xx-1];
				piv_r[yy][xx] = (xx==0) ? map_r[yy][xx] : map_r[yy][xx] & !(map_r[yy][xx-1] | mul_r[yy][xx-1]);
				piv_c[xx][yy] = piv_r[yy][xx];
			end
		end
	end

	// calculate right hand side per row (b - sum of products);
	logic signed [12:0][63:0] sum_prod;
	logic signed [9:0][12:0][63:0] R; // right hand side
	logic [12:0][63:0] pivot;
	always_comb begin
		R = 0;
		for( int yy = 9; yy >= 0; yy-- ) begin // bot up loop
			for( int xx = 12; xx >= 0; xx-- ) begin // right to left
				if( xx == 12 ) begin
					R[yy][xx] = S[yy][13];
				end else if ( xx < yy ) begin // never pivot
					R[yy][xx] = 0;
				end else begin // accumulate RHS
					R[yy][xx] = R[yy][xx+1] - S[yy][xx+1] * V[xx+1];
				end
			end
		end
		for( int xx = 12; xx >= 0; xx-- ) begin // bot up loop
			sum_prod[xx] = (( piv_r[ 0][xx] ) ? R[ 0][xx] : 0 ) | // Select mux
			               (( piv_r[ 1][xx] ) ? R[ 1][xx] : 0 ) |
			               (( piv_r[ 2][xx] ) ? R[ 2][xx] : 0 ) |
			               (( piv_r[ 3][xx] ) ? R[ 3][xx] : 0 ) |
			               (( piv_r[ 4][xx] ) ? R[ 4][xx] : 0 ) |
			               (( piv_r[ 5][xx] ) ? R[ 5][xx] : 0 ) |
			               (( piv_r[ 6][xx] ) ? R[ 6][xx] : 0 ) |
			               (( piv_r[ 7][xx] ) ? R[ 7][xx] : 0 ) |
			               (( piv_r[ 8][xx] ) ? R[ 8][xx] : 0 ) |
			               (( piv_r[ 9][xx] ) ? R[ 9][xx] : 0 ) ;
			pivot[xx] =    (( piv_r[ 0][xx] ) ? S[ 0][xx] : 0 ) | // Select mux
			               (( piv_r[ 1][xx] ) ? S[ 1][xx] : 0 ) |
			               (( piv_r[ 2][xx] ) ? S[ 2][xx] : 0 ) |
			               (( piv_r[ 3][xx] ) ? S[ 3][xx] : 0 ) |
			               (( piv_r[ 4][xx] ) ? S[ 4][xx] : 0 ) |
			               (( piv_r[ 5][xx] ) ? S[ 5][xx] : 0 ) |
			               (( piv_r[ 6][xx] ) ? S[ 6][xx] : 0 ) |
			               (( piv_r[ 7][xx] ) ? S[ 7][xx] : 0 ) |
			               (( piv_r[ 8][xx] ) ? S[ 8][xx] : 0 ) |
			               (( piv_r[ 9][xx] ) ? S[ 9][xx] : 0 ) ;
		end
	end
			
	// do col divides Vrow = sum_prod / pivot, and check all for neg_frac
	logic [12:0][8:0] col_result; // output is unsigned 9 bit pos int unless flagged
	logic [12:0]      neg_frac; // to be masked 
	day10_div i_div0( .num( sum_prod[0]), .denom( pivot[0] ), .out( col_result[0] ), .neg_frac( neg_frac[0] ) );
	day10_div i_div1( .num( sum_prod[1]), .denom( pivot[1] ), .out( col_result[1] ), .neg_frac( neg_frac[1] ) );
	day10_div i_div2( .num( sum_prod[2]), .denom( pivot[2] ), .out( col_result[2] ), .neg_frac( neg_frac[2] ) );
	day10_div i_div3( .num( sum_prod[3]), .denom( pivot[3] ), .out( col_result[3] ), .neg_frac( neg_frac[3] ) );
	day10_div i_div4( .num( sum_prod[4]), .denom( pivot[4] ), .out( col_result[4] ), .neg_frac( neg_frac[4] ) );
	day10_div i_div5( .num( sum_prod[5]), .denom( pivot[5] ), .out( col_result[5] ), .neg_frac( neg_frac[5] ) );
	day10_div i_div6( .num( sum_prod[6]), .denom( pivot[6] ), .out( col_result[6] ), .neg_frac( neg_frac[6] ) );
	day10_div i_div7( .num( sum_prod[7]), .denom( pivot[7] ), .out( col_result[7] ), .neg_frac( neg_frac[7] ) );
	day10_div i_div8( .num( sum_prod[8]), .denom( pivot[8] ), .out( col_result[8] ), .neg_frac( neg_frac[8] ) );
	day10_div i_div9( .num( sum_prod[9]), .denom( pivot[9] ), .out( col_result[9] ), .neg_frac( neg_frac[9] ) );
	day10_div i_diva( .num( sum_prod[10]),.denom( pivot[10]), .out( col_result[10]), .neg_frac( neg_frac[10]) );
	day10_div i_divb( .num( sum_prod[11]),.denom( pivot[11]), .out( col_result[11]), .neg_frac( neg_frac[11]) );
	day10_div i_divc( .num( sum_prod[12]),.denom( pivot[12]), .out( col_result[12]), .neg_frac( neg_frac[12]) );
	
	// Create column counters for independant and dependant variables
	logic [13:0][3:0] ind_count; // counts betwen cols should max at 10
	logic [13:0][3:0] dep_count; // day10 constrains this to max at 3
	always_comb begin
		ind_count = 0;
		dep_count = 0;
		for( int xx = 0; xx < 13; xx++ ) begin
			dep_count[xx+1] = ( |piv_c[xx] ) ? dep_count[xx] + 1 : dep_count[xx];
			ind_count[xx+1] = ( !|piv_c[xx] && |map_c[xx] ) ? ind_count[xx] + 1 : ind_count[xx];
		end
	end

	// Prepart to solve by
	// - inserting known zero's into x
	// - signalling how many independant variables are needed
	// - inserting independants into x
	logic signed [12:0][63:0] V; // solution X
	logic [12:0] oflag;
	always_comb begin
		for( int xx = 12; xx >= 0; xx-- ) begin
			V[xx] = ( !|map_c[xx] ) ? 0 :   // zero coeff
				(  |piv_c[xx] ) ? col_result[xx] : // row result
				               	  ind[ind_count[xx]];  // indpendant input
			x_out[xx][8:0] = V[xx][8:0]; // all valid solns are pos ints 0 to 511
			oflag[xx] = ( |piv_c[xx] ) ? neg_frac[xx] : 0; // flag only valid for pivot cols
			//x_out[xx] = V[xx]; // Debug
		end
	end

	// Output data and flag
	assign x_sum = x_out[0]+x_out[1]+x_out[2]+x_out[3]+x_out[4]+x_out[5]+x_out[6]+x_out[7]+x_out[8]+x_out[9]+x_out[10]+x_out[11]+x_out[12];
	assign posint = !|oflag;
	assign nind = ind_count[13][1:0]; // max 3
endmodule

// Combinatorial divider Out = num / denom. 
// output will be a non negative integer less than 500
// 0 / 0 = 0 and not invalid
module day10_div (
	input logic signed [63:0] num,
	input logic signed [63:0] denom,
	output logic [8:0] out,
	output logic neg_frac   // flag if invalid: -ve, fractional, too large
	);

	logic [63:0] unum, udenom;
	logic [8:0][63:0] val, rem;
	assign unum   = ( num[63]   ) ? -num   : num;
	assign udenom = ( denom[63] ) ? -denom : denom;
	always_comb begin
		neg_frac = 0;
		val = 0;
		rem = 0;
		out = 0;
		if( denom == 0 ) begin // divide by zero
			out = 0;
			neg_frac = 0; // not invalid, just a side effect of zero rows
		end else if( num == 0 ) begin // result is zero no error
			out = 0;
			neg_frac = 0; // not invalid even if -ve denom
		end else if( num[63] && !denom[63] || !num[63] && denom[63] ) begin // negative output
			out = 0;
			neg_frac = 1;
		end else if( { 9'h000, unum[63:9] } >= udenom ) begin // too large > 512
			out = 0;
			neg_frac = 1;
		end else begin // only need 9 rounds max
			val[8] = { 8'h0, unum[63:8] };
			out[8] = ( val[8] >= udenom ) ? 1'b1 : 1'b0;
			rem[8] = ( val[8] >= udenom ) ? val[8] - udenom : val[8];
			for( int ii = 7; ii >= 0; ii-- ) begin
				val[ii] = { rem[ii+1][62:0], unum[ii] };
				out[ii] = ( val[ii] >= udenom ) ? 1'b1 : 1'b0;
				rem[ii] = ( val[ii] >= udenom ) ? val[ii] - udenom : val[ii];
			end
			neg_frac = ( rem[0] != 0 ) ? 1'b1 : 1'b0;
		end
	end
endmodule


	
