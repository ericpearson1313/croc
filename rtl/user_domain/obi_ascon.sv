// Copyright 2025 Eric Pearson
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Eric Pearson <ericpubd@execulink.ca>

//////////////////////////////////////////////////
//////////////////////////////////////////////////
//
//  User ASCON Code with OBI interfaces
//
//////////////////////////////////////////////////
//////////////////////////////////////////////////


module obi_ascon import user_pkg::*; import croc_pkg::*; #(
  parameter int unsigned magic = 32'h69434017
) (
  input  logic      clk_i,
  input  logic      rst_ni,
  input  logic      testmode_i,
  
  input  sbr_obi_req_t sbr_req_i, // User Sbr (rsp_o), Croc Mgr (req_i)
  output sbr_obi_rsp_t sbr_rsp_o,

  output mgr_obi_req_t [4:0] mgr_req_o, // User Mgr (req_o), Croc Sbr (rsp_i)
  input  mgr_obi_rsp_t [4:0] mgr_rsp_i
  );

  // SBR response always with magic number
  // have gnt take a cycle

  	logic [SbrObiCfg.IdWidth-1:0] rid;
	logic rvalid; 
	logic [9:0] raddr;
	always @(posedge clk_i) begin
		raddr  <= (sbr_rsp_o.gnt & sbr_req_i.req ) ? sbr_req_i.a.addr[11:2] : raddr; // word regs addr
		rvalid <= ( sbr_rsp_o.gnt & sbr_req_i.req ) ? 1'b1 : 1'b0;
		rid    <= ( sbr_rsp_o.gnt & sbr_req_i.req ) ? sbr_req_i.a.aid : rid;
	end

	// length register (3)
	logic [31:0] length;
	always_ff @(posedge clk_i) begin
		if( !rst_ni )
			length <= 4; // default 1 word
		else if( sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==4 ) 
			length <= sbr_req_i.a.wdata;
	end
	
	// formulate the response
	logic [2:0][31:0] dma_read_data;
	always_comb begin
	    	sbr_rsp_o 		= '0;
    		sbr_rsp_o.gnt      	= 1'b1; // non blocking
    		sbr_rsp_o.r.rdata 	= 
					  ( raddr==0 ) ? magic :
					  ( raddr==1 ) ? dma_read_data[0] : 
    		                    	  ( raddr==2 ) ? dma_read_data[1] : 
    		                    	  ( raddr==3 ) ? dma_read_data[2] : 
					  ( raddr==4 ) ? length :
					  ( raddr==6 ) ? { 30'h0, status_data[0], status_cmd[0] } :
                                                         32'hdeadbeef;
    		sbr_rsp_o.r.rid   	= rid;
    		sbr_rsp_o.rvalid   	= rvalid; 
    	end

  // connect MGR ports to dma engines

	logic [4:0] status_cmd;
	logic [4:0] status_data;
  	ascon_write_dma _auth_w (
    		.clk_i		( clk_i ),
    		.rst_ni         ( rst_ni ),
		.testmode_i	( testmode_i ),
		// OBI bus
    		.mgr_req_o   	( mgr_req_o[0] ),
    		.mgr_rsp_i   	( mgr_rsp_i[0] ),
		// input dma write address, length (bytes)
		.awvalid	( sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==5 ), 
		.awready	( status_cmd[0] ),
		.awaddr		( sbr_req_i.a.wdata ),
		.awlen		( length ), 
		// axi read word stream input
		.rvalid		( sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==6 ),
		.rready		( status_data[0] ),
		.rdata		( sbr_req_i.a.wdata )
	);

  	ascon_write_dma _bdo_w (
    		.clk_i		( clk_i ),
    		.rst_ni         ( rst_ni ),
		.testmode_i	( testmode_i ),
		// OBI bus
    		.mgr_req_o   	( mgr_req_o[1] ),
    		.mgr_rsp_i   	( mgr_rsp_i[1] ),
		// input dma write address, length (bytes)
		.awvalid	( 1'b0 ), 
		.awready	( ),
		.awaddr		( 0 ),
		.awlen		( 4 ), 
		// axi read word stream input
		.rvalid		( 1'b0 ),
		.rready		( ),
		.rdata		( 32'h0 )
	);

	
	logic [31:0] axi_wdata;
	logic axi_wvalid;
  	ascon_read_dma _cmd_r (
    		.clk_i		( clk_i ),
    		.rst_ni         ( rst_ni ),
		.testmode_i	( testmode_i ),
		// OBI bus
    		.mgr_req_o   	( mgr_req_o[2] ),
    		.mgr_rsp_i   	( mgr_rsp_i[2] ),
		// input dma address, length (bytes)
		.arvalid	( sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==1 ), // wr addr 0x4
		.arready	( ),
		.araddr		( sbr_req_i.a.wdata ),
		.arlen		( length ), // read a word
		// axi Write data word stream output 
		.wvalid		( axi_wvalid ),
		.wready		( 1'b1 ),
		.wdata		( axi_wdata ),
		.wbe		( ),
		.wlast		( )
	);

	// latch the stream output to get the read data word
	always_ff @(posedge clk_i) begin
		dma_read_data[0] <= ( !rst_ni ) ? 0 : ( axi_wvalid ) ? axi_wdata : dma_read_data[0];
		dma_read_data[1] <= ( !rst_ni ) ? 0 : ( axi_wvalid ) ? dma_read_data[0] : dma_read_data[1];
		dma_read_data[2] <= ( !rst_ni ) ? 0 : ( axi_wvalid ) ? dma_read_data[1] : dma_read_data[2];
	end
	

  	ascon_read_dma _key_r (
    		.clk_i		( clk_i ),
    		.rst_ni         ( rst_ni ),
		.testmode_i	( testmode_i ),
		// OBI bus
    		.mgr_req_o   	( mgr_req_o[3] ),
    		.mgr_rsp_i   	( mgr_rsp_i[3] ),
		// input dma address, length (bytes)
		.arvalid	( 1'b0 ), 
		.arready	( ),
		.araddr		( 0 ),
		.arlen		( 4 ), 
		// axi Write data word stream output 
		.wvalid		( ),
		.wready		( 1'b0 ),
		.wdata		( ),
		.wbe		( ),
		.wlast		( )
	);

  	ascon_read_dma _bdi_r (
    		.clk_i		( clk_i ),
    		.rst_ni         ( rst_ni ),
		.testmode_i	( testmode_i ),
		// OBI bus
    		.mgr_req_o   	( mgr_req_o[4] ),
    		.mgr_rsp_i   	( mgr_rsp_i[4] ),
		// input dma address, length (bytes)
		.arvalid	( 1'b0 ), 
		.arready	( ),
		.araddr		( 0 ),
		.arlen		( 4 ), 
		// axi Write data word stream output 
		.wvalid		( ),
		.wready		( 1'b0 ),
		.wdata		( ),
		.wbe		( ),
		.wlast		( )
	);
endmodule
