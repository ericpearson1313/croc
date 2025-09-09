// Copyright 2025 Eric Pearson
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Eric Pearson <ericpubd@execulink.ca>

////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
//
//                      OBI WRITE DMA
//
////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
// OBI bus master dma engine.
// valid/ready word stream input DMA to byte address, byte lenght 
module ascon_write_dma import user_pkg::*; import croc_pkg::*; 
  	(
  	input  logic      clk_i,
  	input  logic      rst_ni,
  	input  logic      testmode_i,
	// OBI master write port out
  	output mgr_obi_req_t mgr_req_o, 
  	input  mgr_obi_rsp_t mgr_rsp_i,
	// write address stream input port
	input 		awvalid,
	output 		awready,
	input 	[31:0] 	awaddr,
	input 	[31:0] 	awlen,
	// Write data stream input
	output		rready,
	input		rvalid,
	input 	[31:0]	rdata
  	);

	// Tie off ports
	//assign awready = 0;
	//assign rready = 0;
	//assign mgr_req_o = 0;

	// Command stream input with unaligned write addr, len
	logic [31:0] write_addr;
	logic [1:0] write_addr_lsb;
	logic [31:0] byte_cnt;
	logic [1:0] byte_cnt_lsb;
	logic addr_busy;
	logic full; // cannot issue further requests
	logic first_flag;
	logic last_flag;
	// Generate read transactions needed, work with limit on max oustanding transactions
	always_ff @(posedge clk_i) begin
		if( !rst_ni ) begin
			addr_busy <= 0;
			byte_cnt <= 0;
			byte_cnt_lsb <= 0;
			write_addr <= 0;
			write_addr_lsb <= 0;
			first_flag <= 0;
		end else begin
			if( awvalid && awready ) begin // dma write command start addresss recevied
				write_addr <= awaddr;
				write_addr_lsb <= awaddr[1:0];
				byte_cnt <= awlen;
				byte_cnt_lsb <= awlen[1:0];
				addr_busy <= 1; // we are busy requesgin
				first_flag <= 1'b1; 
			end else if( addr_busy && mgr_req_o.req && mgr_rsp_i.gnt ) begin // addr transfered
				first_flag <= 0;
				if ( byte_cnt + write_addr[1:0]  <= 4 ) begin // our last transfer
					addr_busy <= 0;
					byte_cnt <= 0;
					write_addr <= 0;
				end else begin
					addr_busy <= addr_busy;
					byte_cnt <= byte_cnt - 4;
					write_addr <= write_addr+4;
				end
			end
		end
	end
	// generate first, last, double last and byte enables
	assign last_flag = ( byte_cnt + write_addr[1:0]  <= 4 ) ? 1'b1 : 1'b0; // last read word being sent

	// determine if last flag indicates two output words to flush
	logic [3:0] in_byte_cnt;
	logic [3:0] out_byte_cnt;
	logic double_last_flag;
	assign out_byte_cnt = { 2'b00, write_addr_lsb[1:0]} + {2'b00, byte_cnt_lsb[1:0]} + 4'h3;
	assign in_byte_cnt = { 2'b00, byte_cnt_lsb[1:0]} + 4'h3;
	assign double_last_flag = ( write_addr_lsb != 0 && in_byte_cnt[3:2] != out_byte_cnt[3:2] ) ? 1'b1 : 1'b0;

	// second last flag to indicate not to advance buffer state only in case of double last case
	logic second_last_flag;
	assign second_last_flag = (double_last_flag && ( byte_cnt + write_addr[1:0]  <= 8 ) ) ? 1'b1 : 1'b0;

	// calc be byte enable
	logic [3:0] first_be, last_be;
	logic [3:0] be;
	logic [1:0] awlast;
	assign awlast[1:0] = awaddr[1:0]+awlen[1:0];
	always_ff @(posedge clk_i) begin
		if( awvalid && awready ) begin // dma write command start addresss recevied
			first_be <=( awaddr[1:0] == 0 ) ? 4'b1111 :
		           	   ( awaddr[1:0] == 1 ) ? 4'b1110 :
		           	   ( awaddr[1:0] == 2 ) ? 4'b1100 :
		           	   /*awaddr[1:0] == 3 )*/ 4'b1000 ;
			last_be <= ( awlast[1:0] == 0 ) ? 4'b1111 :
		           	   ( awlast[1:0] == 1 ) ? 4'b0001 :
		           	   ( awlast[1:0] == 2 ) ? 4'b0011 :
		           	   /*awlast[1:0] == 3 )*/ 4'b0111 ;
		end
	end

	assign be = ( first_flag & last_flag ) ? (first_be & last_be) :
		    ( first_flag ) ? first_be : 
                    ( last_flag ) ? last_be : 
                                   4'b1111;
	
	// Receive input aligned read words

	assign rready =  addr_busy && ( !valid_0 || !valid_1 ||  mgr_req_o.req && mgr_rsp_i.gnt ); // take read data if inreg will be available
	logic [6:0][7:0] in_reg;
	always_ff @(posedge clk_i) begin
		if( rready & rvalid ) begin // receive data
			// memory read data
			in_reg[6:3] <= rdata;
			in_reg[2:0] <= in_reg[6:4]; // shift in 3 prev bytes, zero for first
		end
	end

	// Shift read words to write alignment `
	// alighned Output register
	logic [6:0][7:0] out_reg;
	logic out_load;
	always_ff @(posedge clk_i) begin
		if( out_load ) begin
			out_reg <= in_reg;
		end
	end

	logic [31:0] write_data;
	assign write_data = ( valid_2 && write_addr_lsb[1:0]==1 ) ?  { 24'h0, out_reg[6  ] } :
			    ( valid_2 && write_addr_lsb[1:0]==2 ) ?  { 16'h0, out_reg[6:5] } :
			    ( valid_2 && write_addr_lsb[1:0]==3 ) ?  {  8'h0, out_reg[6:4] } :
			               ( write_addr_lsb[1:0]==0 ) ?           out_reg[6:3] :
			               ( write_addr_lsb[1:0]==1 ) ?           out_reg[5:2] :
			               ( write_addr_lsb[1:0]==2 ) ?           out_reg[4:1] :
			               /*write_addr_lsb[1:0]==3 )*/           out_reg[3:0] ;

	// Valid bits tracking input shift/buffering. decouples input/output
	logic valid_0; // shifter input valid 
	logic valid_1; // shifter output valid
	logic valid_2; // double last word
	always_ff @(posedge clk_i) begin
		if( !rst_ni ) begin
			valid_0 <= 0;
			valid_1 <= 0;
			valid_2 <= 0;	// only used for double last
		end else begin
			valid_0 <= (   rready && rvalid ) ? 1'b1 : // axi read data input
				   ( !valid_1 && !valid_2 ) ? 1'b0 : // out regs available
				   (  valid_1 && mgr_req_o.req && mgr_rsp_i.gnt  && !second_last_flag ) ? 1'b0 : // 
				   (  valid_2 && mgr_req_o.req && mgr_rsp_i.gnt ) ? 1'b0 : 
							valid_0; // hold
	   { valid_2, valid_1 }	<= ( !valid_1 && !valid_2 ) ? { 1'b0, valid_0 } : // accept if we're empty
		                   (  valid_1 && mgr_req_o.req && mgr_rsp_i.gnt && second_last_flag ) ? 2'b10 : // we'll need this buffer again
		                   (  valid_1 && mgr_req_o.req && mgr_rsp_i.gnt ) ? { 1'b0, valid_0 } : 
				   (  valid_2 && mgr_req_o.req && mgr_rsp_i.gnt ) ? { 1'b0, valid_0 } : 
									            { valid_2, valid_1 } ; // hold
		end
	end

	// Load strobes
	assign out_load =  ( !valid_1 && !valid_2 ) ||
			   (  valid_1 && mgr_req_o.req && mgr_rsp_i.gnt && !second_last_flag ) ||
			   (  valid_2 && mgr_req_o.req && mgr_rsp_i.gnt );
	
	// OBI write (addr, data, be)
	assign mgr_req_o.req = addr_busy & !full & ( valid_1 | valid_2 ); // throttle and await data
	assign mgr_req_o.a.addr = { write_addr[31:2], 2'b00 }; // word addresses only
	assign mgr_req_o.a.wdata = write_data;
	assign mgr_req_o.a.we = 1'b1;
	assign mgr_req_o.a.be = be[3:0];
	assign mgr_req_o.a.aid = 0;
	

	// track writes in progress for stalling (>=2) and completion (=0)
 	// Outstanding Requests
	logic [3:0] oust;
	always_ff @(posedge clk_i) begin
		if( !rst_ni ) begin
			oust <= 0;
		end else begin
			oust <= ( ( mgr_req_o.req && mgr_rsp_i.gnt ) && !(mgr_rsp_i.rvalid)) ? oust + 1 :
			        ( ( mgr_req_o.req && mgr_rsp_i.gnt ) &&  (mgr_rsp_i.rvalid)) ? oust + 0 :
			        (!( mgr_req_o.req && mgr_rsp_i.gnt ) &&  (mgr_rsp_i.rvalid)) ? oust - 1 : oust;
		end
	end
	assign full = (oust >= 2) ? 1'b1 : 1'b0; // ToDo figure out extra word
	assign awready = ( addr_busy || oust ) ? 1'b0 : 1'b1; // accept next cmd when addr and oustanding are done

endmodule

