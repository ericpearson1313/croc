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

  //////////////////////////
  // ASCON Cipher core
  //////////////////////////

	// Ascon core interface signals
	// Mode Control
	logic [3:0]     mode;
	logic 		done; 
	logic 		rst;
	
	// Key input and handshake
	logic [31:0]	key; 
	logic 		key_valid;	
	logic 		key_ready; 
	
	// Block data input to the core and handshake
	logic [31:0]	bdi;	
	logic [3:0]	bdi_valid; // bytes can be marked invalid
	logic 		bdi_ready;	 	
	logic [3:0]	bdi_type; // Inidates type of data
	logic 		bdi_eot; // indicates end of data type	 	
	logic 		bdi_eoi; // Indicates the end of input	 
	// local vars
	logic [3:0]     bdi_be;
	logic           bdi_last;
	logic 	        bdi_valid_word;
	assign bdi_valid = {4{bdi_valid_word}}&bdi_be[3:0];
	
	// Block Data out of the core
	logic [31:0]	bdo; 	
	logic 		bdo_valid; 	
	logic 		bdo_ready; 	
	logic [3:0] 	bdo_type; 
	logic 		bdo_eot; 		
	logic 		bdo_eoo; // Control into core to end the hash output
	
	// authentication output
	logic 		auth; 			
	logic 		auth_valid;	// sample auth pulse

	// ASCON core from github.com/rprimas/ascon-verilog
	// Note: configure Ascon core as V1 or V2 or V3 in order to have 32bit bus
	ascon_core _wrapped(
		.clk		( clk_i		),
		.rst		( !rst_ni	),
		// connected to key read dma
		.key		( key[31:0] 	),
		.key_valid	( key_valid 	),
		.key_ready	( key_ready 	),
		// connected to bdi read dma and some controls
		.bdi		( bdi[31:0] 	),
		.bdi_valid	( bdi_valid[3:0]),
		.bdi_ready	( bdi_ready 	),
		.bdi_type	( bdi_type[3:0]	), 
		.bdi_eot	( bdi_last & bdi_eot ),
		.bdi_eoi	( bdi_last & bdi_eoi ),
		// mode control input
		.mode		( mode[3:0]	),
		// connect to bdo write dma
		.bdo		( bdo[31:0] 	),
		.bdo_valid	( bdo_valid 	),
		.bdo_ready	( bdo_ready 	),
		.bdo_type	( bdo_type[3:0] ),
		.bdo_eot	( bdo_eot 	),
		// Control input to finish hash?
		.bdo_eoo	( bdo_eoo 	),
		// connect to auth write DMA
		.auth		( auth 		),
		.auth_valid	( auth_valid 	),
		// status flag
		.done       	( done 		)
	);

  //////////////////////////
  // OBI DMA Managers (5)
  //////////////////////////

	logic [4:0] status_cmd;
	logic [4:0] status_data;
	// Auth DMA write (5)
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
		.awlen		( length ),  // 
		// axi read word stream input
		.rvalid		(   auth_valid || sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==6 ),
		.rready		( status_data[0] ),
		.rdata		( ( auth_valid ) ? ( (auth) ? "Pass" : "Fail" ) : sbr_req_i.a.wdata )
	);

	// BDO Write DMA (9)
  	ascon_write_dma _bdo_w (
    		.clk_i		( clk_i ),
    		.rst_ni         ( rst_ni ),
		.testmode_i	( testmode_i ),
		// OBI bus
    		.mgr_req_o   	( mgr_req_o[1] ),
    		.mgr_rsp_i   	( mgr_rsp_i[1] ),
		// input dma write address, length (bytes)
		.awvalid	( sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==9 ), 
		.awready	( status_cmd[1] ),
		.awaddr		( sbr_req_i.a.wdata ),
		.awlen		( length ), 
		// axi read word stream input
		.rvalid		( bdo_valid ),
		.rready		( bdo_ready ),
		.rdata		( bdo_data )
	);
	
	logic [31:0] axi_wdata;
	logic axi_wvalid;
	// CMD Read DMA (1)
  	ascon_read_dma _cmd_r (
    		.clk_i		( clk_i ),
    		.rst_ni         ( rst_ni ),
		.testmode_i	( testmode_i ),
		// OBI bus
    		.mgr_req_o   	( mgr_req_o[2] ),
    		.mgr_rsp_i   	( mgr_rsp_i[2] ),
		// input dma address, length (bytes)
		.arvalid	( sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==1 ), // wr addr 0x4
		.arready	( status_cmd[2] ),
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

	// Key read DMA (7)
  	ascon_read_dma _key_r (
    		.clk_i		( clk_i ),
    		.rst_ni         ( rst_ni ),
		.testmode_i	( testmode_i ),
		// OBI bus
    		.mgr_req_o   	( mgr_req_o[3] ),
    		.mgr_rsp_i   	( mgr_rsp_i[3] ),
		// input dma address, length (bytes)
		.arvalid	( sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==7 ), 
		.arready	( status_cmd[3] ),
		.araddr		( sbr_req_i.a.wdata ),
		.arlen		( 4 ), 
		// axi Write data word stream output 
		.wvalid		( key_valid ),
		.wready		( key_ready ),
		.wdata		( key ),
		.wbe		( ),
		.wlast		( )
	);

	// BDI Read DMA (11)
  	ascon_read_dma _bdi_r (
    		.clk_i		( clk_i ),
    		.rst_ni         ( rst_ni ),
		.testmode_i	( testmode_i ),
		// OBI bus
    		.mgr_req_o   	( mgr_req_o[4] ),
    		.mgr_rsp_i   	( mgr_rsp_i[4] ),
		// input dm a address, length (bytes)
		.arvalid	( sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==11), 
		.arready	( status_cmd[4] ),
		.araddr		( sbr_req_i.a.wdata ),
		.arlen		( length ), 
		// axi Write data word stream output 
		.wvalid		( bdi_valid_word ),
		.wready		( bdi_ready ),
		.wdata		( bdi_data ),
		.wbe		( bdi_be ),
		.wlast		( bdi_last )
	);

  //////////////////////////
  // OBI Sub Interface
  //////////////////////////

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

endmodule
