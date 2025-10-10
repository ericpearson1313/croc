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
`include "config.sv"

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

  // State machine
	localparam S_IDLE 		= 0;
	// enc
	localparam S_ENC_KEY 		= 2;
	localparam S_ENC_KEY_WAIT1 	= 3;
	localparam S_ENC_MODE 		= 4;
	localparam S_ENC_KEY_WAIT2 	= 5;
	localparam S_ENC_NONCE		= 6;
	localparam S_ENC_NONCE_WAIT 	= 7;
	localparam S_ENC_AD 		= 8;
	localparam S_ENC_AD_WAIT 	= 9;
	localparam S_ENC_MSG 		= 10;
	localparam S_ENC_MSG_WAIT	= 11;
	localparam S_ENC_TAG 		= 12;
	localparam S_ENC_TAG_WAIT 	= 13;
	localparam S_ENC_DONE_WAIT 	= 14;
	// dec
	localparam S_DEC_KEY 		= 22;
	localparam S_DEC_KEY_WAIT1 	= 23;
	localparam S_DEC_MODE 		= 24;
	localparam S_DEC_KEY_WAIT2 	= 25;
	localparam S_DEC_NONCE		= 26;
	localparam S_DEC_NONCE_WAIT 	= 27;
	localparam S_DEC_AD 		= 28;
	localparam S_DEC_AD_WAIT 	= 29;
	localparam S_DEC_MSG 		= 30;
	localparam S_DEC_MSG_WAIT	= 31;
	localparam S_DEC_TAG 		= 32;
	localparam S_DEC_TAG_WAIT 	= 33;
	localparam S_DEC_AUTH 		= 34;
	localparam S_DEC_AUTH_WAIT 	= 35;
	localparam S_DEC_DONE_WAIT 	= 36;
	// Hash
	localparam S_HASH_MODE 		= 40;
	localparam S_HASH_MSG 		= 41;
	localparam S_HASH_MSG_WAIT	= 42;
	localparam S_HASH_HASH 		= 43;
	localparam S_HASH_HASH_WAIT 	= 44;
	// dec auth
	localparam S_DEC2_KEY 		= 52;
	localparam S_DEC2_KEY_WAIT1 	= 53;
	localparam S_DEC2_MODE 		= 54;
	localparam S_DEC2_KEY_WAIT2 	= 55;
	localparam S_DEC2_NONCE		= 56;
	localparam S_DEC2_NONCE_WAIT 	= 57;
	localparam S_DEC2_AD 		= 58;
	localparam S_DEC2_AD_WAIT 	= 59;
	localparam S_DEC2_MSG 		= 60;
	localparam S_DEC2_MSG_WAIT	= 61;
	localparam S_DEC2_TAG 		= 62;
	localparam S_DEC2_TAG_WAIT 	= 63;
	localparam S_DEC2_DONE_WAIT 	= 66;
	// Xof hash
	localparam S_XOF_MODE		= 70;
	localparam S_XOF_LEN		= 71;
	localparam S_XOF_MSG 		= 72;
	localparam S_XOF_MSG_WAIT 	= 73;
	localparam S_XOF_HASH 		= 74;
	localparam S_XOF_HASH_WAIT	= 75;
	localparam S_XOF_END1  		= 76;
	localparam S_XOF_END2  		= 77;
	// CXof Hash
	localparam S_CXOF_MODE		= 80;
	localparam S_CXOF_LEN		= 81;
	localparam S_CXOF_AD		= 82;
	localparam S_CXOF_AD_WAIT	= 83;
	localparam S_CXOF_MSG		= 84;
	localparam S_CXOF_MSG_WAIT	= 85;
	localparam S_CXOF_HASH		= 86;
	localparam S_CXOF_HASH_WAIT	= 87;
	localparam S_CXOF_END1  	= 88;
	localparam S_CXOF_END2  	= 89;

  //////////////////////////
  // ASCON Cipher core
  //////////////////////////

	// Ascon core interface signals
	// Mode Control
	mode_e          mode;
	logic 		done; 
	logic 		rst;
	
	// Key input and handshake
	logic [31:0]	key; 
	logic 		key_valid;	
	logic 		key_ready; 
	
	// Block data input to the core and handshake
	logic [31:0]	bdi;	
	logic      	bdi_valid; // whole word valid
	logic 		bdi_ready;	 	
	data_e     	bdi_type; // Inidates type of data
	logic 		bdi_eot; // indicates end of data type	 	
	logic 		bdi_eoi; // Indicates the end of input	 
	// local vars
	logic [3:0]     bdi_be;
	logic           bdi_last;
	
	// Block Data out of the core
	logic [31:0]	bdo; 	
	logic 		bdo_valid; 	
	logic 		bdo_ready; 	
	logic [3:0] 	bdo_type; 
	logic 		bdo_eot; 		
	logic 		bdo_eoo; // Control into core to end the hash output
	
	// authentication output
	logic 		auth; 			
	logic 		auth_ready; // ignored
	logic 		auth_valid; // sample auth pulse

	// ASCON core from github.com/rprimas/ascon-verilog
	// Note: configure Ascon core as V1 or V2 or V3 in order to have 32bit bus
	ascon_core i_ascon_core (
		.clk		( clk_i		),
		.rst		( !rst_ni	),
		// connected to key read dma
		.key		( key[31:0] 	),
		.key_valid	( key_valid 	),
		.key_ready	( key_ready 	),
		// connected to bdi read dma and some controls
		.bdi		( bdi[31:0] 	),
		.bdi_valid	( {4{link&bdi_valid}}&bdi_be[3:0] ),
		.bdi_ready	( bdi_ready 	),
		.bdi_type	( bdi_type      ), 
		.bdi_eot	( link & bdi_valid & bdi_last & bdi_eot ),
		.bdi_eoi	( link & bdi_valid & bdi_last & bdi_eoi ),
		// mode control input
		.mode		( mode ),
		// connect to bdo write dma
		.bdo		( bdo[31:0] 	),
		.bdo_valid	( bdo_valid 	),
		.bdo_ready	( (link&bdo_ready) | cmd_dio | cmd_eoo1 | cmd_eoo2 ),
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

	assign bdi_type = ( ascon_ctrl[5:2] != 0 ) ? data_e'(ascon_ctrl[5:2]) : cmd_type;
	assign bdi_eot  = ascon_ctrl[1]   | cmd_eot;
	assign bdi_eoi  = ascon_ctrl[0]   | cmd_eoi;

	// some hardwired connectoins
	logic lio, link;
	assign link = ( lio ) ? (bdi_valid & bdi_ready & bdo_valid & bdo_ready) : 1'b1;
	assign bdo_eoo   = cmd_eoo2 | ascon_ctrl[12]; // not sure
	assign lio       = ascon_ctrl[8] | cmd_lio; // link bdi/bdo transfers
	

  //////////////////////////
  // OBI DMA Managers (5)
  //////////////////////////

	logic [4:0] status_cmd;
	logic [4:0] status_dma;
	logic [4:0] status_dev;
	// Auth DMA write (5)
  	ascon_write_dma i_auth_w (
    		.clk_i		( clk_i ),
    		.rst_ni         ( rst_ni ),
		.testmode_i	( testmode_i ),
		// OBI bus
    		.mgr_req_o   	( mgr_req_o[0] ),
    		.mgr_rsp_i   	( mgr_rsp_i[0] ),
		// input dma write address, length (bytes)
		.awvalid	( link_cmd[0] | (sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==5) ), 
		.awready	( status_cmd[0] ),
		.awaddr		( link_cmd[0] ? axi_wdata_mux : sbr_req_i.a.wdata ),
		.awlen		( link_cmd[0] ? cmd_len : length ),  // should be hw as 1 or 4
		// axi read word stream input
		.rvalid		(  auth_valid_axi || sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==6 ),
		.rready		(  auth_ready ),
		.rdata		(( auth_valid_axi ) ? ( (auth) ? "ssap" : "laif" ) : sbr_req_i.a.wdata )
	);
	assign status_dma[0] = auth_ready;
	assign status_dev[0] = auth_valid_axi || sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==6;
	// Auth valid handshakeA
	logic auth_valid_del; 
	logic auth_valid_axi;
	always_ff @(posedge clk_i ) begin
		auth_valid_del <= auth_valid;
		auth_valid_axi <= (auth_valid && !auth_valid_del) ? 1'b1 : 
                                  (!auth_valid && auth_valid_del) ? 1'b0 : 
                                                   ( auth_ready ) ? 1'b0 : auth_valid_axi;
	end

	// BDO Write DMA (9)
  	ascon_write_dma i_bdo_w (
    		.clk_i		( clk_i ),
    		.rst_ni         ( rst_ni ),
		.testmode_i	( testmode_i ),
		// OBI bus
    		.mgr_req_o   	( mgr_req_o[1] ),
    		.mgr_rsp_i   	( mgr_rsp_i[1] ),
		// input dma write address, length (bytes)
		.awvalid	( link_cmd[1] | ( sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==9 )), 
		.awready	( status_cmd[1] ),
		.awaddr		( link_cmd[1] ? axi_wdata_mux : sbr_req_i.a.wdata ),
		.awlen		( link_cmd[1] ? cmd_len : length ), 
		// axi read word stream input
		.rvalid		( (link&bdo_valid)  || sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==10),
		.rready		( bdo_ready ),
		.rdata		( bdo       )
	);
	assign status_dma[1] = bdo_ready;
	assign status_dev[1] = bdo_valid || sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==10;
	
	logic [31:0] axi_wdata;
	logic axi_wvalid;
	logic axi_wready;
	// CMD Read DMA (1)
  	ascon_read_dma i_cmd_r (
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
		.arlen		( length ), // read a word TBD 4 or 0xfffffff?
		// axi Write data word stream output 
		.wvalid		( axi_wvalid ),
		.wready		( axi_wready ), // test assumes this 1'b1 ),
		.wdata		( axi_wdata ),
		.wbe		( ),
		.wlast		( )
	);
	assign status_dma[2] = axi_wvalid;
	assign status_dev[2] = axi_wready;


	// CMD fifo save last 6 commands
	always_ff @(posedge clk_i) begin
		dma_read_data[5:0] <= ( !rst_ni ) ? 0 : 
                                      ( axi_wvalid && axi_wready || cmd_fifo ) ? { dma_read_data[4:0], axi_wdata } : dma_read_data;
	end
	logic [31:0] axi_wdata_mux;
	assign axi_wdata_mux = ( cmd_fifo ) ? dma_read_data[5] : axi_wdata;

	// Key read DMA (7)
  	ascon_read_dma i_key_r (
    		.clk_i		( clk_i ),
    		.rst_ni         ( rst_ni ),
		.testmode_i	( testmode_i ),
		// OBI bus
    		.mgr_req_o   	( mgr_req_o[3] ),
    		.mgr_rsp_i   	( mgr_rsp_i[3] ),
		// input dma address, length (bytes)
		.arvalid	( link_cmd[3] | ( sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==7) ), 
		.arready	( status_cmd[3] ),
		.araddr		( link_cmd[3] ? axi_wdata_mux : sbr_req_i.a.wdata ),
		.arlen		( 16 ), 
		// axi Write data word stream output 
		.wvalid		( key_valid ),
		.wready		( key_ready ),
		.wdata		( key ),
		.wbe		( ),
		.wlast		( )
	);
	assign status_dma[3] = key_valid;
	assign status_dev[3] = key_ready;

	// BDI Read DMA (11)
  	ascon_read_dma i_bdi_r (
    		.clk_i		( clk_i ),
    		.rst_ni         ( rst_ni ),
		.testmode_i	( testmode_i ),
		// OBI bus
    		.mgr_req_o   	( mgr_req_o[4] ),
    		.mgr_rsp_i   	( mgr_rsp_i[4] ),
		// input dm a address, length (bytes)
		.arvalid	( link_cmd[4] | (sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==11) ), 
		.arready	( status_cmd[4] ),
		.araddr		( link_cmd[4] ? axi_wdata_mux : sbr_req_i.a.wdata ),
		.arlen		( link_cmd[4] ? cmd_len : length ), 
		// axi Write data word stream output 
		.wvalid		( bdi_valid ),
		.wready		( link&bdi_ready ),
		.wdata		( bdi ),
		.wbe		( bdi_be ),
		.wlast		( bdi_last )
	);
	assign status_dma[4] = bdi_valid;
	assign status_dev[4] = bdi_ready;

	// assemble the read only status word
	logic [31:0] status_word; 
	logic [31:0] status_word_reg;
	always_comb begin
		status_word = 0;
		// assign 1 nibble per dma engine [19:0]
		for( int ii = 0; ii < 5; ii++ ) 
			status_word[ii*4+3-:4] = { 1'b0, status_dev[ii], status_dma[ii], status_cmd[ii] };
		// device status bits packed in msb
		status_word[25] = done;
		status_word[26] = auth;
		status_word[27] = auth_valid;
		status_word[31:28] = bdo_type[3:0]; 
	end
	always_ff @(posedge clk_i) begin
		status_word_reg <= status_word;
	end
	
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

	// Ascon Mode reg (14)
	logic [3:0] mode_reg;
	always_ff @(posedge clk_i) begin
		if( !rst_ni ) begin
			mode_reg <= 0; // NOP
			mode <= M_INVALID;
		end else if( sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==14 ) begin
			mode_reg <= sbr_req_i.a.wdata[3:0]; // for readback
			mode     <= mode_e'(sbr_req_i.a.wdata[3:0]); // single cycle pulse
		end else begin
			mode	<= ( state == S_ENC_MODE  ||
				     state == S_DEC_MODE  ||
				     state == S_DEC2_MODE ||
                                     state == S_HASH_MODE ||
				     state == S_XOF_MODE  ||
				     state == S_CXOF_MODE  ) ? cmd_mode : M_INVALID;
		end;
	end

	// length register (3)
	logic [31:0] length;
	always_ff @(posedge clk_i) begin
		if( !rst_ni )
			length <= 4; // default 1 word
		else if( sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==4 ) 
			length <= sbr_req_i.a.wdata;
	end

	// control engine controls (13)
	logic [31:0] ascon_ctrl;
	always_ff @(posedge clk_i) begin
		if( !rst_ni )
			ascon_ctrl<= 0; 
		else if( sbr_rsp_o.gnt & sbr_req_i.req & sbr_req_i.a.we & sbr_req_i.a.addr[11:2]==13 ) 
			ascon_ctrl <= sbr_req_i.a.wdata;
	end
	
	// formulate the response
	logic [5:0][31:0] dma_read_data;
	always_comb begin
	    	sbr_rsp_o 		= '0;
    		sbr_rsp_o.gnt      	= 1'b1; // non blocking
    		sbr_rsp_o.r.rdata 	= 
					  ( raddr==0 ) ? magic :
					  ( raddr==1 ) ? dma_read_data[0] : 
    		                    	  ( raddr==2 ) ? dma_read_data[1] : 
    		                    	  ( raddr==3 ) ? dma_read_data[2] : 
					  ( raddr==4 ) ? length : ( raddr==6 ) ? status_word_reg :
					  ( raddr==13) ? ascon_ctrl :
					  ( raddr==14) ? {28'h0, mode_reg } :
                                                         32'hdeadbeef;
    		sbr_rsp_o.r.rid   	= rid;
    		sbr_rsp_o.rvalid   	= rvalid; 
    	end

	// Full command execution
	// Fed CMD stream from read DMA engine



	logic [7:0] state, state_nx;
	always_comb begin
		case ( state ) 
		S_IDLE:          begin state_nx = ( axi_wvalid && axi_wready && axi_wdata[31:28]==1 ) ? S_ENC_KEY  : 
                                                  ( axi_wvalid && axi_wready && axi_wdata[31:28]==2 ) ? S_DEC_KEY  : 
                                                  ( axi_wvalid && axi_wready && axi_wdata[31:28]==3 ) ? S_HASH_MODE : 
						  ( axi_wvalid && axi_wready && axi_wdata[31:28]==4 ) ? S_XOF_MODE :
						  ( axi_wvalid && axi_wready && axi_wdata[31:28]==5 ) ? S_CXOF_MODE : S_IDLE ; end
		// Encode
		S_ENC_KEY:       begin state_nx = ( axi_wvalid && axi_wready) ? S_ENC_KEY_WAIT1  : S_ENC_KEY       ; end
		S_ENC_KEY_WAIT1: begin state_nx = ( key_valid               ) ? S_ENC_MODE       : S_ENC_KEY_WAIT1 ; end
		S_ENC_MODE:      begin state_nx =                               S_ENC_KEY_WAIT2                    ; end
		S_ENC_KEY_WAIT2: begin state_nx = ( status_cmd[3]           ) ? S_ENC_NONCE      : S_ENC_KEY_WAIT2 ; end
		S_ENC_NONCE :    begin state_nx = ( axi_wvalid && axi_wready) ? S_ENC_NONCE_WAIT : S_ENC_NONCE     ; end
		S_ENC_NONCE_WAIT:begin state_nx = ( status_cmd[4]           ) ? S_ENC_AD         : S_ENC_NONCE_WAIT; end
		S_ENC_AD :       begin state_nx = ( axi_wvalid && axi_wready) ? S_ENC_AD_WAIT    : S_ENC_AD        ; end
		S_ENC_AD_WAIT :  begin state_nx = ( status_cmd[4]           ) ? S_ENC_MSG        : S_ENC_AD_WAIT   ; end
		S_ENC_MSG :      begin state_nx = ( axi_wvalid && axi_wready) ? S_ENC_MSG_WAIT   : S_ENC_MSG       ; end
		S_ENC_MSG_WAIT : begin state_nx = ( status_cmd[4] && 
                                                    status_cmd[1]            )? S_ENC_TAG        : S_ENC_MSG_WAIT  ; end
		S_ENC_TAG :      begin state_nx = ( axi_wvalid && axi_wready) ? S_ENC_TAG_WAIT   : S_ENC_TAG       ; end
		S_ENC_TAG_WAIT : begin state_nx = ( status_cmd[1]           ) ? S_ENC_DONE_WAIT  : S_ENC_TAG_WAIT  ; end
		S_ENC_DONE_WAIT :begin state_nx = ( done                    ) ? S_IDLE           : S_ENC_DONE_WAIT ; end
		// Decode
		S_DEC_KEY:       begin state_nx = ( axi_wvalid && axi_wready) ? S_DEC_KEY_WAIT1  : S_DEC_KEY       ; end
		S_DEC_KEY_WAIT1: begin state_nx = ( key_valid               ) ? S_DEC_MODE       : S_DEC_KEY_WAIT1 ; end
		S_DEC_MODE:      begin state_nx =                               S_DEC_KEY_WAIT2                    ; end
		S_DEC_KEY_WAIT2: begin state_nx = ( status_cmd[3]           ) ? S_DEC_NONCE      : S_DEC_KEY_WAIT2 ; end
		S_DEC_NONCE :    begin state_nx = ( axi_wvalid && axi_wready) ? S_DEC_NONCE_WAIT : S_DEC_NONCE     ; end
		S_DEC_NONCE_WAIT:begin state_nx = ( status_cmd[4]           ) ? S_DEC_AD         : S_DEC_NONCE_WAIT; end
		S_DEC_AD :       begin state_nx = ( axi_wvalid && axi_wready) ? S_DEC_AD_WAIT    : S_DEC_AD        ; end
		S_DEC_AD_WAIT :  begin state_nx = ( status_cmd[4]           ) ? S_DEC_MSG        : S_DEC_AD_WAIT   ; end
		S_DEC_MSG :      begin state_nx = ( axi_wvalid && axi_wready) ? S_DEC_MSG_WAIT   : S_DEC_MSG       ; end
		S_DEC_MSG_WAIT : begin state_nx = ( status_cmd[4]           ) ? S_DEC_TAG        : S_DEC_MSG_WAIT  ; end // no write first time
		S_DEC_TAG :      begin state_nx = ( axi_wvalid && axi_wready) ? S_DEC_TAG_WAIT   : S_DEC_TAG       ; end
		S_DEC_TAG_WAIT : begin state_nx = ( status_cmd[4]           ) ? S_DEC_AUTH       : S_DEC_TAG_WAIT  ; end
		S_DEC_AUTH :     begin state_nx = ( axi_wvalid && axi_wready) ? S_DEC_AUTH_WAIT  : S_DEC_AUTH      ; end
		S_DEC_AUTH_WAIT :begin state_nx = ( status_cmd[0]           ) ? S_DEC_DONE_WAIT  : S_DEC_AUTH_WAIT ; end
		S_DEC_DONE_WAIT :begin state_nx = ( auth_valid && !auth     ) ? S_IDLE           :
                                                  ( auth_valid &&  auth     ) ? S_DEC2_KEY       : S_DEC_DONE_WAIT ; end
		// Authenticated Decode
		S_DEC2_KEY:       begin state_nx =                               S_DEC2_KEY_WAIT1                     ; end
		S_DEC2_KEY_WAIT1: begin state_nx = ( key_valid               ) ? S_DEC2_MODE       : S_DEC2_KEY_WAIT1 ; end
		S_DEC2_MODE:      begin state_nx =                               S_DEC2_KEY_WAIT2                     ; end
		S_DEC2_KEY_WAIT2: begin state_nx = ( status_cmd[3]           ) ? S_DEC2_NONCE      : S_DEC2_KEY_WAIT2 ; end
		S_DEC2_NONCE :    begin state_nx =                               S_DEC2_NONCE_WAIT                    ; end
		S_DEC2_NONCE_WAIT:begin state_nx = ( status_cmd[4]           ) ? S_DEC2_AD         : S_DEC2_NONCE_WAIT; end
		S_DEC2_AD :       begin state_nx =                               S_DEC2_AD_WAIT                       ; end
		S_DEC2_AD_WAIT :  begin state_nx = ( status_cmd[4]           ) ? S_DEC2_MSG        : S_DEC2_AD_WAIT   ; end
		S_DEC2_MSG :      begin state_nx =                               S_DEC2_MSG_WAIT                      ; end
		S_DEC2_MSG_WAIT : begin state_nx = ( status_cmd[4] && 							    // Write pt
                                                     status_cmd[1]           ) ? S_DEC2_TAG        : S_DEC2_MSG_WAIT  ; end
		S_DEC2_TAG :      begin state_nx =                               S_DEC2_TAG_WAIT                      ; end
		S_DEC2_TAG_WAIT : begin state_nx = ( status_cmd[4]           ) ? S_DEC2_DONE_WAIT  : S_DEC2_TAG_WAIT  ; end
		S_DEC2_DONE_WAIT :begin state_nx = ( done                    ) ? S_IDLE            : S_DEC2_DONE_WAIT ; end
		// Hash
		S_HASH_MODE:     begin state_nx =                               S_HASH_MSG                         ; end
		S_HASH_MSG :     begin state_nx = ( axi_wvalid && axi_wready) ? S_HASH_MSG_WAIT  : S_HASH_MSG      ; end
		S_HASH_MSG_WAIT :begin state_nx = ( status_cmd[4]           ) ? S_HASH_HASH      : S_HASH_MSG_WAIT ; end
		S_HASH_HASH :    begin state_nx = ( axi_wvalid && axi_wready) ? S_HASH_HASH_WAIT : S_HASH_HASH     ; end
		S_HASH_HASH_WAIT:begin state_nx = ( status_cmd[1]           ) ? S_IDLE           : S_HASH_HASH_WAIT; end
		// Xof Hash
		S_XOF_MODE:      begin state_nx =                               S_XOF_LEN                         ; end
		S_XOF_LEN:       begin state_nx = ( axi_wvalid && axi_wready) ? S_XOF_MSG       : S_XOF_LEN       ; end
		S_XOF_MSG :      begin state_nx = ( axi_wvalid && axi_wready) ? S_XOF_MSG_WAIT  : S_XOF_MSG       ; end
		S_XOF_MSG_WAIT : begin state_nx = ( status_cmd[4]           ) ? S_XOF_HASH      : S_XOF_MSG_WAIT  ; end
		S_XOF_HASH :     begin state_nx = ( axi_wvalid && axi_wready) ? S_XOF_HASH_WAIT : S_XOF_HASH      ; end
		S_XOF_HASH_WAIT: begin state_nx = ( status_cmd[1] &&
                                                    status_dev[1]           ) ? S_XOF_END1      : S_XOF_HASH_WAIT ; end
		S_XOF_END1   :   begin state_nx =                               S_XOF_END2                        ; end
		S_XOF_END2   :   begin state_nx =                               S_IDLE                            ; end
		// Xof Hash
		S_CXOF_MODE:      begin state_nx =                               S_CXOF_LEN                          ; end
		S_CXOF_LEN:       begin state_nx = ( axi_wvalid && axi_wready) ? S_CXOF_AD        : S_CXOF_LEN       ; end
		S_CXOF_AD :       begin state_nx = ( axi_wvalid && axi_wready) ? S_CXOF_AD_WAIT   : S_CXOF_AD        ; end
		S_CXOF_AD_WAIT :  begin state_nx = ( status_cmd[4]           ) ? S_CXOF_MSG       : S_CXOF_AD_WAIT   ; end
		S_CXOF_MSG :      begin state_nx = ( axi_wvalid && axi_wready) ? S_CXOF_MSG_WAIT  : S_CXOF_MSG       ; end
		S_CXOF_MSG_WAIT : begin state_nx = ( status_cmd[4]           ) ? S_CXOF_HASH      : S_CXOF_MSG_WAIT  ; end
		S_CXOF_HASH :     begin state_nx = ( axi_wvalid && axi_wready) ? S_CXOF_HASH_WAIT : S_CXOF_HASH      ; end
		S_CXOF_HASH_WAIT: begin state_nx = ( status_cmd[1] &&
                                                     status_dev[1]           ) ? S_CXOF_END1      : S_CXOF_HASH_WAIT ; end
		S_CXOF_END1  :    begin state_nx =                               S_CXOF_END2                         ; end
		S_CXOF_END2  :    begin state_nx =                               S_IDLE                              ; end
		// default
		default : state_nx = 'x;
		endcase
	end

	always_ff @(posedge clk_i ) begin
		if( !rst_ni ) begin
			state <= S_IDLE;	
		end else begin
			state <= state_nx;	
		end
	end

	// Drive axi_wready
	assign axi_wready = ( state == S_IDLE      ||
			      state == S_ENC_KEY   ||
			      state == S_ENC_NONCE ||
			      state == S_ENC_AD    ||
			      state == S_ENC_MSG   ||
			      state == S_ENC_TAG   ||
			      state == S_DEC_KEY   ||
			      state == S_DEC_NONCE ||
			      state == S_DEC_AD    ||
			      state == S_DEC_MSG   ||
			      state == S_DEC_TAG   ||
			      state == S_DEC_AUTH  ||
			      state == S_HASH_MSG  ||
			      state == S_HASH_HASH ||
			      state == S_XOF_LEN   ||
			      state == S_XOF_MSG   ||
			      state == S_XOF_HASH  ||
			      state == S_CXOF_LEN  ||
			      state == S_CXOF_AD   ||
			      state == S_CXOF_MSG  ||
			      state == S_CXOF_HASH ) ? 1'b1 : 1'b0;

	// Incomming Command words linked to write DMA command registers 
	localparam AUTH_DMA = 0;
	localparam BDO_DMA  = 1;
	localparam KEY_DMA  = 3;
	localparam BDI_DMA  = 4;
	logic [4:0] link_cmd;
	always_comb begin
		link_cmd = 0;
		if( axi_wvalid && axi_wready || cmd_fifo ) begin
			link_cmd[BDI_DMA] = ( state == S_ENC_NONCE ||
					      state == S_ENC_AD    ||
					      state == S_ENC_MSG   ||
					      state == S_DEC_NONCE || state == S_DEC2_NONCE ||
					      state == S_DEC_AD    || state == S_DEC2_AD    ||
					      state == S_DEC_MSG   || state == S_DEC2_MSG   ||
					      state == S_DEC_TAG   || state == S_DEC2_TAG   ||
                                              state == S_HASH_MSG  ||
                                              state == S_XOF_MSG   ||
                                              state == S_CXOF_AD   ||
                                              state == S_CXOF_MSG   ) ? 1'b1 : 1'b0;
			link_cmd[KEY_DMA] = ( state == S_ENC_KEY   ||
					      state == S_DEC_KEY   || 
                                              state == S_DEC2_KEY ) ? 1'b1 : 1'b0;
			link_cmd[BDO_DMA] = ( state == S_ENC_MSG   ||
					      state == S_ENC_TAG   ||
					      state == S_DEC2_MSG  ||
					      state == S_HASH_HASH ||
                                              state == S_XOF_HASH  ||
                                              state == S_CXOF_HASH ) ? 1'b1 : 1'b0;
			link_cmd[AUTH_DMA]= ( state == S_DEC_AUTH  ) ? 1'b1 : 1'b0;
		end
	end

	// reg incomming command lengths 
	logic [31:0] hash_len;
	logic [31:0] msg_len;
	logic [31:0] ad_len;
	logic [7:0] command;
	always_ff @(posedge clk_i) begin
		if( state == S_IDLE && axi_wvalid && axi_wready ) begin
			msg_len <= { 20'h0, axi_wdata[11:0] };
			ad_len <= { 20'h0, axi_wdata[23:12] };
			command <= axi_wdata[31:24];
		end
		if( state == S_XOF_LEN && axi_wvalid && axi_wready ) begin
			hash_len <= axi_wdata;
		end
	end

	// Setup other data for cmd
	// Length, BDI_type, LIO, EOI, EOT
	logic cmd_dio; // flag that output discarded, set bdo_ready
	data_e cmd_type;
	logic [31:0] cmd_len;
	logic cmd_lio, cmd_eoi, cmd_eot; 
	logic cmd_eoo1, cmd_eoo2; // need 2 cycles as hashes are mult of 64
	logic cmd_fifo;;
	mode_e cmd_mode;
	always_comb begin
		cmd_fifo =( state == S_DEC2_KEY   ||
                            state == S_DEC2_NONCE ||
                            state == S_DEC2_AD    ||
                            state == S_DEC2_MSG   ||
                            state == S_DEC2_TAG   ) ? 1'b1 : 1'b0;
		cmd_mode =( state == S_ENC_MODE ) ? M_AEAD128_ENC : 
			  ( state == S_DEC_MODE ) ? M_AEAD128_DEC :
			  ( state == S_DEC2_MODE) ? M_AEAD128_DEC :
			  ( state == S_HASH_MODE) ? M_HASH256 :
			  ( state == S_XOF_MODE ) ? M_XOF128 :
			  ( state == S_CXOF_MODE) ? M_CXOF128 : M_INVALID;
		cmd_type =( state == S_ENC_NONCE || state == S_ENC_NONCE_WAIT || 
                            state == S_DEC_NONCE || state == S_DEC_NONCE_WAIT ||
                            state == S_DEC2_NONCE|| state == S_DEC2_NONCE_WAIT) ? D_NONCE :
			  ( state == S_ENC_AD    || state == S_ENC_AD_WAIT    || 
                            state == S_DEC_AD    || state == S_DEC_AD_WAIT    ||
                            state == S_DEC2_AD   || state == S_DEC2_AD_WAIT   ) ? D_AD :
			  ( state == S_ENC_MSG   || state == S_ENC_MSG_WAIT   || 
                            state == S_DEC_MSG   || state == S_DEC_MSG_WAIT   ||
                            state == S_DEC2_MSG  || state == S_DEC2_MSG_WAIT  ) ? D_MSG : 
			  ( state == S_HASH_MSG  || state == S_HASH_MSG_WAIT  ) ? D_MSG : 
			  ( state == S_XOF_MSG   || state == S_XOF_MSG_WAIT   ) ? D_MSG : 
			  ( state == S_CXOF_MSG  || state == S_CXOF_MSG_WAIT  ) ? D_MSG : 
			  ( state == S_CXOF_AD   || state == S_CXOF_AD_WAIT   ) ? D_AD : 
                          ( state == S_DEC_TAG   || state == S_DEC_TAG_WAIT   ||
                            state == S_DEC2_TAG  || state == S_DEC2_TAG_WAIT  ) ? D_TAG : D_INVALID;
		cmd_lio = ( state == S_ENC_MSG   || state == S_ENC_MSG_WAIT   || state == S_DEC2_MSG  || state == S_DEC2_MSG_WAIT  ) ? 1'b1 : 1'b0;
		cmd_dio = ( state == S_DEC_MSG   || state == S_DEC_MSG_WAIT   ) ? 1'b1 : 1'b0;
		cmd_eoi = ( state == S_ENC_MSG   || state == S_ENC_MSG_WAIT   ||
                            state == S_DEC_TAG   || state == S_DEC_TAG_WAIT   ||
                            state == S_HASH_MSG  || state == S_HASH_MSG_WAIT  ||
                            state == S_XOF_MSG   || state == S_XOF_MSG_WAIT   ||
                            state == S_CXOF_MSG  || state == S_CXOF_MSG_WAIT  ||
                          ( state == S_ENC_AD    || state == S_ENC_AD_WAIT    ) && msg_len == 0 && ad_len != 0 || 
                          ( state == S_ENC_NONCE || state == S_ENC_NONCE_WAIT ) && msg_len == 0 && ad_len == 0 ) ? 1'b1 : 1'b0;
		cmd_eot = ( state == S_ENC_NONCE || state == S_ENC_NONCE_WAIT || 
                            state == S_DEC_NONCE || state == S_DEC_NONCE_WAIT ||
                            state == S_DEC2_NONCE|| state == S_DEC2_NONCE_WAIT||
                            state == S_ENC_AD    || state == S_ENC_AD_WAIT    || 
                            state == S_DEC_AD    || state == S_DEC_AD_WAIT    ||
                            state == S_DEC2_AD   || state == S_DEC2_AD_WAIT   ||
			    state == S_ENC_MSG   || state == S_ENC_MSG_WAIT   || 
                            state == S_DEC_MSG   || state == S_DEC_MSG_WAIT   ||
                            state == S_DEC2_MSG  || state == S_DEC2_MSG_WAIT  ||
                            state == S_HASH_MSG  || state == S_HASH_MSG_WAIT  || 
                            state == S_XOF_MSG   || state == S_XOF_MSG_WAIT   || 
                            state == S_CXOF_MSG  || state == S_CXOF_MSG_WAIT  || 
                            state == S_CXOF_AD   || state == S_CXOF_AD_WAIT   || 
                            state == S_DEC_TAG   || state == S_DEC_TAG_WAIT   ||
                            state == S_DEC2_TAG  || state == S_DEC2_TAG_WAIT  ) ? 1'b1 : 1'b0;
		cmd_len = ( state == S_ENC_KEY   || 
                            state == S_DEC_KEY   ||
                            state == S_DEC2_KEY  ) ? 16 :
			  ( state == S_ENC_NONCE || 
                            state == S_DEC_NONCE ||
                            state == S_DEC2_NONCE) ? 16 :
			  ( state == S_ENC_AD    || 
                            state == S_DEC_AD    ||
                            state == S_DEC2_AD   ||
                            state == S_CXOF_AD   ) ? ad_len :
			  ( state == S_ENC_MSG   || 
                            state == S_DEC_MSG   || 
                            state == S_DEC2_MSG  || 
                            state == S_HASH_MSG  ||
                            state == S_XOF_MSG   ||
                            state == S_CXOF_MSG  ) ? msg_len :
			  ( state == S_ENC_TAG   || 
                            state == S_DEC_TAG   ||
                            state == S_DEC2_TAG  ) ? 16 : 
                          ( state == S_DEC_AUTH  ) ? 4  :
                          ( state == S_HASH_HASH ) ? 32 :
                          ( state == S_XOF_HASH  ||
                            state == S_CXOF_HASH ) ? hash_len : 0 ;
		cmd_eoo1= ( state == S_XOF_END1  ||
                            state == S_CXOF_END1 ) ? 1'b1 : 1'b0;
		cmd_eoo2= ( state == S_XOF_END2  ||
                            state == S_CXOF_END2 ) ? 1'b1 : 1'b0;
	end
		



	
		

	
	
endmodule
