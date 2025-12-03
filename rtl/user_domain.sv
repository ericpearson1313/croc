// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Philippe Sauter <phsauter@iis.ee.ethz.ch>

module user_domain import user_pkg::*; import croc_pkg::*; #(
  parameter int unsigned GpioCount = 16
) (
  input  logic      clk_i,
  input  logic      ref_clk_i,
  input  logic      rst_ni,
  input  logic      testmode_i,
  
  input  sbr_obi_req_t user_sbr_obi_req_i, // User Sbr (rsp_o), Croc Mgr (req_i)
  output sbr_obi_rsp_t user_sbr_obi_rsp_o,

  output mgr_obi_req_t user_mgr_obi_req_o, // User Mgr (req_o), Croc Sbr (rsp_i)
  input  mgr_obi_rsp_t user_mgr_obi_rsp_i,

  input  logic [      GpioCount-1:0] gpio_in_sync_i, // synchronized GPIO inputs
  output logic [NumExternalIrqs-1:0] interrupts_o // interrupts to core
);

  assign interrupts_o = '0;  


  //////////////////////
  // User Manager MUX //
  /////////////////////

  // No manager so we don't need a obi_mux module and just terminate the request properly
  assign user_mgr_obi_req_o = '0;


  ////////////////////////////
  // User Subordinate DEMUX //
  ////////////////////////////

  // ----------------------------------------------------------------------------------------------
  // User Subordinate Buses
  // ----------------------------------------------------------------------------------------------
  
  // collection of signals from the demultiplexer
  sbr_obi_req_t [NumDemuxSbr-1:0] all_user_sbr_obi_req;
  sbr_obi_rsp_t [NumDemuxSbr-1:0] all_user_sbr_obi_rsp;

  // Error Subordinate Bus
  sbr_obi_req_t user_error_obi_req;
  sbr_obi_rsp_t user_error_obi_rsp;

  // Fanout into more readable signals
  assign user_error_obi_req              = all_user_sbr_obi_req[UserError];
  assign all_user_sbr_obi_rsp[UserError] = user_error_obi_rsp;


  //-----------------------------------------------------------------------------------------------
  // Demultiplex to User Subordinates according to address map
  //-----------------------------------------------------------------------------------------------

  logic [cf_math_pkg::idx_width(NumDemuxSbr)-1:0] user_idx;

  addr_decode #(
    .NoIndices ( NumDemuxSbr                    ),
    .NoRules   ( NumDemuxSbrRules               ),
    .addr_t    ( logic[SbrObiCfg.DataWidth-1:0] ),
    .rule_t    ( addr_map_rule_t                ),
    .Napot     ( 1'b0                           )
  ) i_addr_decode_periphs (
    .addr_i           ( user_sbr_obi_req_i.a.addr ),
    .addr_map_i       ( user_addr_map             ),
    .idx_o            ( user_idx                  ),
    .dec_valid_o      (),
    .dec_error_o      (),
    .en_default_idx_i ( 1'b1 ),
    .default_idx_i    ( '0   )
  );

  obi_demux #(
    .ObiCfg      ( SbrObiCfg     ),
    .obi_req_t   ( sbr_obi_req_t ),
    .obi_rsp_t   ( sbr_obi_rsp_t ),
    .NumMgrPorts ( NumDemuxSbr   ),
    .NumMaxTrans ( 2             )
  ) i_obi_demux (
    .clk_i,
    .rst_ni,

    .sbr_port_select_i ( user_idx             ),
    .sbr_port_req_i    ( user_sbr_obi_req_i   ),
    .sbr_port_rsp_o    ( user_sbr_obi_rsp_o   ),

    .mgr_ports_req_o   ( all_user_sbr_obi_req ),
    .mgr_ports_rsp_i   ( all_user_sbr_obi_rsp )
  );


//-------------------------------------------------------------------------------------------------
// User Subordinates
//-------------------------------------------------------------------------------------------------

  // Error Subordinate
  obi_err_sbr #(
    .ObiCfg      ( SbrObiCfg     ),
    .obi_req_t   ( sbr_obi_req_t ),
    .obi_rsp_t   ( sbr_obi_rsp_t ),
    .NumMaxTrans ( 1             ),
    .RspData     ( 32'hBADCAB1E  )
  ) i_user_err (
    .clk_i,
    .rst_ni,
    .testmode_i ( testmode_i      ),
    .obi_req_i  ( user_error_obi_req ),
    .obi_rsp_o  ( user_error_obi_rsp )
  );

  // ----------------------------------------------------------------------------------------------
  // AOC Day 2 Hardware
  // ----------------------------------------------------------------------------------------------
  
  // get user OBI subordinate register buss (mapped to 0x2000_0000
  sbr_obi_req_t sbr_req_i;
  sbr_obi_rsp_t sbr_rsp_o;
  assign sbr_req_i = all_user_sbr_obi_req[UserDay1];
  assign all_user_sbr_obi_rsp[UserDay1] = sbr_rsp_o;

	// OBI read Interface

	logic [31:0] magic = 32'habcd1234;
  	logic [SbrObiCfg.IdWidth-1:0] rid;
	logic rvalid; 
	logic [9:0] raddr;
	always @(posedge clk_i) begin
		raddr  <= ( sbr_rsp_o.gnt & sbr_req_i.req ) ? sbr_req_i.a.addr[11:2] : raddr; // word regs addr
		rvalid <= ( sbr_rsp_o.gnt & sbr_req_i.req ) ? 1'b1 : 1'b0;
		rid    <= ( sbr_rsp_o.gnt & sbr_req_i.req ) ? sbr_req_i.a.aid : rid;
	end

	logic [63:0] lower_reg; // BCD of lower limit for day 2 puzzle
	logic [63:0] upper_reg; // BCD of upper limit for day 2 puzzle
	always_comb begin
	    	sbr_rsp_o 		= '0;
    		sbr_rsp_o.gnt      	= 1'b1; // non blocking
    		sbr_rsp_o.r.rdata 	= 
					  ( raddr==0 ) ? magic :	// write here inits
					  ( raddr==1 ) ? { lower_reg[31-:32] } : // input regs
					  ( raddr==2 ) ? { lower_reg[63-:32] } : 
					  ( raddr==3 ) ? { upper_reg[31-:32] } : 
					  ( raddr==4 ) ? { upper_reg[63-:32] } : // last word written triggers
    		                    	  ( raddr==5 ) ? { sum_part1[31-:32] } : // sum Output
    		                    	  ( raddr==6 ) ? { sum_part1[63-:32] } : 
                                                         32'hdeadbeef;
    		sbr_rsp_o.r.rid   	= rid;
    		sbr_rsp_o.rvalid   	= rvalid; 
    	end

	// OBI Write Interface
	// Upper/Lower limit regisers
	always_ff @(posedge clk_i) begin
		lower_reg[31-:32] <= ( sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==1 ) ? sbr_req_i.a.wdata : lower_reg[31-:32];
		lower_reg[63-:32] <= ( sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==2 ) ? sbr_req_i.a.wdata : lower_reg[63-:32];
		upper_reg[31-:32] <= ( sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==3 ) ? sbr_req_i.a.wdata : upper_reg[31-:32];
		upper_reg[63-:32] <= ( sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==4 ) ? sbr_req_i.a.wdata : upper_reg[63-:32];
	end

	// Delay line timing trigger by rot write (in lieu of state machine) TBD
	logic [49:0] tick;
	always_ff @(posedge clk_i) begin
		if( !rst_ni ) begin
			tick <= 0;
		end else if (sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==4 ) begin // write to reg 4 triggers flow TBD
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
				adjust_upper[ii*4+3-:4] = ( ii <= lower_digits ) ? 4'h9 : 4'h0;
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
	always_ff @(posedge clk_i) begin
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

	// Sum register / cleared by init
	logic [63:0] sum_part1; // BCD sum of invalid IDs
	always_ff @(posedge clk_i) begin
		if(  sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==0 ) begin // write reg 0 to clear sum
			sum_part1 <= 0;
		end else if( valid  && in_range ) begin
			sum_part1 <= bcd_sum;
		end else begin
			sum_part1 <= sum_part1;
		end
	end
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
