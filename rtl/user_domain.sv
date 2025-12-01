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
  // AOC Day 1 Hardware
  // ----------------------------------------------------------------------------------------------
  
  // get user OBI subordinate register buss (mapped to 0x2000_0000
  sbr_obi_req_t sbr_req_i;
  sbr_obi_rsp_t sbr_rsp_o;
  assign sbr_req_i = all_user_sbr_obi_req[UserDay1];
  assign all_user_sbr_obi_rsp[UserDay1] = sbr_rsp_o;

  // 3 Register interface
  // Init accumulators, sets start state to N/2 (50)
  // write rotation data, which will increment zero counts and update state
  // Read sums

  // State machine
  // register input rotation
  // divide rot/N -> div, rem
  // accumulate div 
  // calc if zero crossed (rem, state)
  // Accumulate reg + state with optional single wrap
  // zero detect and accumulateA
  // block further read or writes until done
  // day_part1 = sum_zerodetect
  // day1_part2 = sum_zero_det + sum_zero_crossed + sum_div;

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

	always_comb begin
	    	sbr_rsp_o 		= '0;
    		sbr_rsp_o.gnt      	= 1'b1; // non blocking
    		sbr_rsp_o.r.rdata 	= 
					  ( raddr==0 ) ? magic :	// write here inits
					  ( raddr==1 ) ? { rot_sign, rot } : // write here is sign, rot and inits operations
    		                    	  ( raddr==2 ) ? { sum_part1[15:0], sum_part2[15:0] } : // always holds the results
    		                    	  ( raddr==3 ) ? 32'h0000_0003 :
                                                         32'hdeadbeef;
    		sbr_rsp_o.r.rid   	= rid;
    		sbr_rsp_o.rvalid   	= rvalid; 
    	end

	// OBI Write Interface

	// rot_reg (rotation reg)
	// length register (3)
	logic rot_sign;
	logic [30:0] rot;
	logic [15:0] sum_part1;
	logic [15:0] sum_part2;
	always_ff @(posedge clk_i) begin
		if( !rst_ni ) begin
			rot_sign <= 0; // 0 +ve, 1 -ve
			rot      <= 32'h0;
		end else if( sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==1 ) begin
			{ rot_sign, rot[30:0] } <= sbr_req_i.a.wdata;
		end
	end

	// Delay line timing trigger by rot write (in lieu of state machine)
	logic [49:0] tick;
	always_ff @(posedge clk_i) begin
		if( !rst_ni ) begin
			tick <= 0;
		end else if (sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==1 ) begin
			tick <= 50'h1;
		end else begin
			tick <= { tick[48:0], 1'b0 };
		end
	end

	// Set up the final sum adders
	logic [15:0] sum_wrap;
	logic [15:0] sum_cross_zero;
	logic [15:0] sum_eq_zero;
	assign sum_part1 = sum_eq_zero;
	assign sum_part2 = sum_eq_zero + sum_wrap + sum_cross_zero;

	
	// State reg
	localparam N = 32'd100; // Fixed
	logic [31:0] state; // only need to hold 0 ... N-1
	

	// Divider and sum wrap
	// start on tick 0

	logic [31:0] div, rem;
	user_div i_div (
		.clk( clk_i ),
		.go( tick[0] ),
		.numer_in( rot ),
		.denom_in( N ),
		.quotient( div ),
		.rem( rem )
	);

	logic [31:0] rem_reg;
	always_ff @(posedge clk_i) begin
		if(  sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==0 ) begin // write reg 0 to clear sum
			sum_wrap <= 0;
			rem_reg <= 0;
		end else if( tick[16] ) begin
			rem_reg <= rem;
			sum_wrap <= sum_wrap + div;
		end
	end;

	// Zero crossing logic (rem, state) and sum cross
	// detect when zero is crossed when moving state to new state

	logic zero_cross;
	assign zero_cross = ( rot_sign ) ? ( ( rem_reg > state && state != 0  ) ? 1'b1 : 1'b0 ) 
                                         : ( ( rem_reg > ( N - state )        ) ? 1'b1 : 1'b0 );
	always_ff @(posedge clk_i) begin
                if(  sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==0 ) begin // write reg 0 to clear sum
                        sum_cross_zero <= 0;
		end else if( tick[17] && zero_cross ) begin // negative
			sum_cross_zero <= sum_cross_zero + 1;
		end
	end // comb
	

	// State addition rem+state with wrap and sum eq zero

	logic [31:0] next_state;
	assign next_state = ( rot_sign ) ? ( ( rem_reg > state     ) ? state + N - rem_reg : state - rem_reg ) 
                                         : ( ( rem_reg + state > N ) ? state + rem_reg - N : state + rem_reg );
	
	always_ff @(posedge clk_i) begin
                if(  sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==0 ) begin // write reg 0 to clear sum
                        sum_eq_zero <= 0;
			state <= N>>1; // 50
		end else if( tick[17] ) begin // negative
			sum_eq_zero <= ( next_state == 0 ) ? sum_eq_zero + 1 : sum_eq_zero;
			state <= next_state;
		end
	end // comb
endmodule

// Peforms d/n at 2 bits per cycle
module user_div(
	input logic clk,
	input logic go, // start pulse
	input logic [31:0] numer_in,
	input logic [31:0] denom_in,
	output logic [31:0] quotient,
	output logic [31:0] rem
	);
	logic [0:3][31:0] denom;
	logic [63:0] numer;
	logic [0:3][31:0] remd; // remainder per q
	always_ff @(posedge clk) begin
		if( go ) begin
		   	denom[0][31:0] <= 0;
		   	denom[1][31:0] <= denom_in[31:0];
		   	denom[2][31:0] <= { denom_in[30:0], 1'b0 };
			denom[3][31:0] <= { denom_in[30:0], 1'b0 } + denom_in[31:0];				
			numer <= { 32'h0, numer_in[31:0] };
			quotient <= 0;		
		end else begin
			quotient[31:2] <= quotient[29:0];
			quotient[1:0] <= ( !remd[3][31] ) ? 2'b11 :
			                 ( !remd[2][31] ) ? 2'b10 :
			                 ( !remd[1][31] ) ? 2'b01 : 2'b00 ;
			numer[1:0]   <= 2'b00;
			numer[63:2]  <= numer[61:0];
		end
	end
	
	// combinatorial Divide steps and remainder logic
	assign remd[0][31:0] = numer[63-:32] - denom[0][31:0]; // dummy
	assign remd[1][31:0] = numer[63-:32] - denom[1][31:0];
	assign remd[2][31:0] = numer[63-:32] - denom[2][31:0];
	assign remd[3][31:0] = numer[63-:32] - denom[3][31:0];
	assign rem[31:0] = ( !remd[3][31] ) ? remd[3] : ( !remd[2][31] ) ? remd[2] : ( !remd[1][31] ) ? remd[1] : remd[0] ;

endmodule


