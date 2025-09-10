// Copyright 2025 Eric Pearson
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Eric Pearson <ericpubd@execulink.ca>

////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
//
//                      OBI READ DMA
//
////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
// OBI bus master dma READ engine.
// OBI 32-bit read unaligned byte input to write valid/ready word word aligned little endian stream output 
module ascon_read_dma import user_pkg::*; import croc_pkg::*; 
  	(
	// system
  	input  logic      clk_i,
  	input  logic      rst_ni,
  	input  logic      testmode_i,
	// OBI Mgr port
  	output mgr_obi_req_t mgr_req_o, 
  	input  mgr_obi_rsp_t mgr_rsp_i,
	// Read address stream input port / starts dma
	input  logic 		arvalid,
	output logic 		arready,
	input  logic 	[31:0] 	araddr,
	input  logic 	[31:0] 	arlen,
	input  logic 	[5:0] 	aruser,
	// Write data stream output 
	output logic 		wvalid,
	input  logic 		wready,
	output logic [31:0]	wdata,
	output logic [5 :0]	wuser,
	output logic [ 3:0]  	wbe,
	output logic         	wlast
  	);

	// Read Address generation

	logic [31:0] read_addr;
	logic [1:0] read_addr_lsb;
	logic [31:0] byte_cnt;
	logic [1:0] byte_cnt_lsb;
	logic [5:0] user_in;
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
			read_addr <= 0;
			read_addr_lsb <= 0;
			first_flag <= 0;
			user_in <= 0;
		end else begin
			if( arvalid && arready ) begin // dma command start addresss recevied
				read_addr <= araddr;
				read_addr_lsb <= araddr[1:0];
				user_in <= aruser;
				byte_cnt <= arlen;
				byte_cnt_lsb <= arlen[1:0];
				addr_busy <= 1; // we are busy requesgin
				first_flag <= 1'b1; 
			end else if( addr_busy && mgr_req_o.req && mgr_rsp_i.gnt ) begin // addr transfer
				first_flag <= 0;
				if ( byte_cnt + read_addr[1:0]  <= 4 ) begin // our last transfer
					addr_busy <= 0;
					byte_cnt <= 0;
					read_addr <= 0;
					user_in <= 0;
				end else begin
					addr_busy <= 1'b1;
					byte_cnt <= byte_cnt - 4;
					read_addr <= read_addr+4;
				end
			end
		end
	end
	assign last_flag = ( byte_cnt + read_addr[1:0]  <= 4 ) ? 1'b1 : 1'b0; // last read word being sent

	// determine if last flag indicates two output words to flush
	logic [3:0] in_byte_cnt;
	logic [3:0] out_byte_cnt;
	logic double_last_flag;
	assign in_byte_cnt = { 2'b00, read_addr_lsb[1:0]} + {2'b00, byte_cnt_lsb[1:0]} + 4'h3;
	assign out_byte_cnt = { 2'b00, byte_cnt_lsb[1:0]} + 4'h3;
	assign double_last_flag = ( read_addr_lsb != 0 && in_byte_cnt[3:2] == out_byte_cnt[3:2] ) ? 1'b1 : 1'b0;

	// OBI req outputs
	assign mgr_req_o.req = addr_busy & !full; // Throttling
	assign mgr_req_o.a.addr = { read_addr[31:2], 2'b00 }; // word addresses only
	assign mgr_req_o.a.wdata = 0;
	assign mgr_req_o.a.we = 0;
	assign mgr_req_o.a.be = 0;
	assign mgr_req_o.a.aid = 0;

 	// Outstanding Requests
	// datapath cannot block read data 
	// measure between req/rnt thru to axi read data output
	// don't count the first_flag skipped read as it is not output
	logic [3:0] oust;
	always_ff @(posedge clk_i) begin
		if( !rst_ni ) begin
			oust <= 0;
		end else begin
			oust <= ( ( mgr_req_o.req && mgr_rsp_i.gnt && last_flag && double_last_flag ) && !( (wvalid && wready) || skip_first_flag )  ) ? oust + 2 :
			        ( ( mgr_req_o.req && mgr_rsp_i.gnt && last_flag && double_last_flag ) &&  ( (wvalid && wready) || skip_first_flag )  ) ? oust + 1 :
			        ( ( mgr_req_o.req && mgr_rsp_i.gnt                                  ) && !( (wvalid && wready) || skip_first_flag )  ) ? oust + 1 :
			        ( ( mgr_req_o.req && mgr_rsp_i.gnt                                  ) &&  ( (wvalid && wready) || skip_first_flag )  ) ? oust + 0 :
			        (!( mgr_req_o.req && mgr_rsp_i.gnt                                  ) &&  ( (wvalid && wready) || skip_first_flag )  ) ? oust - 1 : oust;
		end
	end
 
	assign full = (oust >= 2) ? 1'b1 : 1'b0; // ToDo figure out extra word
	
	// AXI RA bus outputs
	assign arready = ( addr_busy || oust ) ? 1'b0 : 1'b1;;
	// Fifo to match until read data received
		// not clear what data we need yet
		// look into home rolled.
	logic first_read, last_read;
	fifo_v3 #(
    		.DEPTH        ( 3 ),
    		.FALL_THROUGH ( 1'b0 ),
    		.DATA_WIDTH   ( 2 )
  	) _rd_trans_fifo (
    		.clk_i	   ( clk_i ),
    		.rst_ni    ( rst_ni ),
    		.testmode_i( testmode_i ),
    		.flush_i   ( '0 ),
    		.full_o    (    ),
    		.empty_o   (    ),
    		.usage_o   (    ),
		// push at transaction
    		.data_i    ( { first_flag, last_flag } ), // first = last for streams 3 bytes and less.
    		.push_i    (  mgr_req_o.req & mgr_rsp_i.gnt ),
		// pop at read reply
    		.data_o    ( { first_read, last_read } ),
    		.pop_i     ( mgr_rsp_i.rvalid )
  	);

	// generated (rbe) byte enables for output? 
	// Since data is output aligned, only the last word has non-zero byte enables, depends on length only.
	// latched at cycle start.
	logic [3:0] last_be;
	always_ff @(posedge clk_i ) begin
		if( arvalid && arready ) // command
			last_be <= 
				( arlen[1:0] == 0 ) ? 4'b1111 :
		          	( arlen[1:0] == 1 ) ? 4'b0001 :
		          	( arlen[1:0] == 2 ) ? 4'b0011 :
		          	/*arlen[1:0] == 3 )*/ 4'b0111 ;
	end
	

	// OBI read data rvalid
	// Input register 
	logic [6:0][7:0] in_reg;
	always_ff @(posedge clk_i) begin
		if( mgr_rsp_i.rvalid ) begin // receive data
			// memory read data
			in_reg[6:3] <= mgr_rsp_i.r.rdata;
			in_reg[2:0] <= in_reg[6:4]; // shift in 3 prev bytes
		end
	end

	// alighned Output register
	logic [31:0] out_reg;
	logic [31:0] out_reg2;
	logic out_load;
	logic out_load2;  // for last double
	always_ff @(posedge clk_i) begin
		if ( out_load2 ) begin // special case of doubled last
			out_reg[31:0] <= ( read_addr_lsb[1:0]==1 ) ? {  8'h0, in_reg[6:4] } :
			                 ( read_addr_lsb[1:0]==2 ) ? { 16'h0, in_reg[6:5] } :
			                 /*read_addr_lsb[1:0]==3 )*/ { 24'h0, in_reg[6] } ;
		end else if( out_load ) begin
			out_reg[31:0] <= ( read_addr_lsb[1:0]==0 ) ? in_reg[6:3] :
			                 ( read_addr_lsb[1:0]==1 ) ? in_reg[3:0] :
			                 ( read_addr_lsb[1:0]==2 ) ? in_reg[4:1] :
			                 /*read_addr_lsb[1:0]==3 )*/ in_reg[5:2] ;
		end
	end

	// Output control
	// track valid signals and shift data path forward
	// allow simul input, shift and output or any subset.
	// maintain flags, control discard loads, and handshake wvalid wready.
	// flags are valid,first,last

	logic skip_first_flag;
	assign skip_first_flag = ( valid_1 && first_1 && !last_1 && read_addr_lsb[1:0] != 0 ) ? 1'b1 : 1'b0;
	logic valid_0, valid_1, valid_2;
	always_ff @(posedge clk_i) begin
		if( !rst_ni ) begin
			valid_0 <= 0;
			valid_1 <= 0;
			valid_2 <= 0;	// only used for double last
		end else begin
			valid_0 <= ( mgr_rsp_i.rvalid ) ? 1'b1 : // always accepts data
				   ( !valid_1 ) ? 1'b0 : // will pass on data, but still always accepts
				   ( wready ) ? 1'b0 : // output is ready to accept data
				   ( skip_first_flag ) ? 1'b0 : // output is discarded
				                       valid_0; // hold valid
			valid_1 <= ( !valid_1 ) ? valid_0 : // accept if we're empty
				   (  wready ) ? valid_0 : // accept if data out can occur
				   ( skip_first_flag ) ? valid_0 : // output is discarded
							valid_1; // else hold
			valid_2 <= ( valid_1 && last_1 && wready && double_last_flag ) ? 1'b1 : // next will be double last
				   ( wready ) ? 1'b0 : // real last transmitted
						valid_2;
				   
		end
	end

	// logic to load the output regs
	assign out_load = !valid_1 | (valid_1 & wready) | skip_first_flag; // load output regs when empty or to be empty
	assign out_load2 = ( valid_1 && last_1 && wready && double_last_flag ) ? 1'b1 : 1'b0;

	// track the flags
	logic first_0, first_1;
	logic last_0, last_1;
	always @(posedge clk_i) begin
		// inreg is loaded with mem read
		first_0 <= ( mgr_rsp_i.rvalid ) ? first_read : first_0; 
		 last_0 <= ( mgr_rsp_i.rvalid ) ?  last_read :  last_0; 
		// outputs are loaded with output dat
		first_1 <= ( out_load ) ? first_0 : first_1;
		 last_1 <= ( out_load ) ?  last_0 :  last_1;
	end

	// axi write stream output port
	assign wuser = user_in;
	assign wlast = ( double_last_flag ) ? valid_2 : last_1;
	assign wbe = ( wlast ) ? last_be : 4'b1111;
	assign wvalid = valid_1 && !skip_first_flag || valid_2;
	assign wdata = { ( wbe[3] ) ? out_reg[31:24] : 8'h00,
			 ( wbe[2] ) ? out_reg[23:16] : 8'h00,
		  	 ( wbe[1] ) ? out_reg[15:08] : 8'h00,
			 ( wbe[0] ) ? out_reg[07:00] : 8'h00 };
endmodule

