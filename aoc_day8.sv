
module day8_tb();

	localparam MAX_BOX = 2000;
	// Read day6_puzzle.txt and calculate answer (behavioral, 
	// I need to think further for sytensizable code, but verilog is my minimum goal 
    	integer file, c;
	integer box[0:2][0:MAX_BOX-1];
	integer num_box, bphase, value;
	integer color[0:MAX_BOX-1];
	integer flag;
	logic [63:0] last_candidate;
	logic [63:0] cost;
	logic [63:0] distance;
	logic [63:0] thresh;
	integer best_a;
	integer best_b;
	integer lo_color, hi_color;
    	initial begin
		
		// Read file and count entried
        	file = $fopen("day8_full_puzzle.txt", "r");
        	if( file ) begin
			num_box = 0;
			bphase = 0;
			value = 0;
                	c = $fgetc(file);
                	while( c != -1 ) begin // until eof
				case( c ) 
				"0","1","2","3","4","5","6","7","8","9" : begin
					value = value * 10 + c - "0";
				end
				"," : begin
					box[bphase++][num_box] = value;
					value = 0;
				end
				8'h0a : begin
					box[bphase][num_box++] = value;
					value = 0;
					bphase = 0;
				end
				endcase
                        	c = $fgetc(file);
        	        end
        	end else begin
                	$display("AOC puzzle.txt not found");
			$finish();
        	end
                $display("Num Boxes = %d", num_box );
		//for( int ii = 0; ii < num_box; ii++ )
                //	$display("%d : %d,%d,%d", ii , box[0][ii], box[1][ii], box[2][ii] );

		// Start the itterative process 
		// 0) assign incrementing colors to each box
		// 1) loop the 'triangle' of box pairs and find the next shortest arc
		// 2) check in the color table about arc enc box colors (A, B). if different
		//     2a) walk the color table and replace all colors of max(A,B) with min(A,B)
		// 3) finished if all boxes are color 0, else next arc
		// 4) report product of x coors of boxes in the last arc.
		
		// Set initial coloring for each box. with lower color numbers having priority
		for( int ii = 0; ii < num_box; ii++ )
			color[ii] = ii;

		flag = 1;
		thresh = 0; // starting mid threshold
		while( flag ) begin
			// loop the triangle for the next best min
                	cost = (10000*10000)*3;
                	for( int ii = 0; ii < num_box-1; ii++ ) begin
                       		for( int jj = ii+1; jj < num_box; jj++ ) begin
					distance = (box[0][ii]-box[0][jj]) * (box[0][ii]-box[0][jj]) +
					           (box[1][ii]-box[1][jj]) * (box[1][ii]-box[1][jj]) +
					           (box[2][ii]-box[2][jj]) * (box[2][ii]-box[2][jj]);
                               		if( distance > thresh && distance < cost) begin
                               		       	cost = distance;
					 	best_a = ii;
					 	best_b = jj;
						last_candidate = box[0][ii] * box[0][jj];
                                	end
                        	end
                	end
			//$display("Arc %d - %d color %d - %d cost %d ( %d,%d,%d ) - ( %d, %d, %d )", best_a, best_b, color[best_a], color[best_b],
                        //                      cost, box[0][best_a], box[1][best_a], box[2][best_a],  box[0][best_b], box[1][best_b], box[2][best_b]);
                	thresh = cost; // for next search

			// Walk the color list and update with the arc
			lo_color = (( color[best_a] < color[best_b]  ) ? color[best_a] : color[best_b] );
			hi_color = (( color[best_a] >= color[best_b] ) ? color[best_a] : color[best_b] );
			//$display("map color %d-->%d", hi_color, lo_color );
			for( int ii = 0; ii < num_box; ii++ ) begin
				if( color[ii] == hi_color ) begin // color match largest of arc
					color[ii] = lo_color;
				end
			end
			
			//for( int ii = 0; ii < num_box; ii++ ) 
			//	$display("color[%d] = %d", ii, color[ii] );

			// Check if colors all zero
			flag = 0;
			for( int ii = 0; ii < num_box; ii++ )
				if( color[ii] != 0 ) 
					flag = 1;
			if( flag == 0 )
				$display("All color=0, --> Fully Connected");
		end
		$display("Part2 answer = %d", last_candidate );
		$finish();
        end
endmodule
