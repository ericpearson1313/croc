// Copyright (c) 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0/
//
// Authors:
// - Philippe Sauter <phsauter@iis.ee.ethz.ch>

#include "uart.h"
#include "print.h"
#include "timer.h"
#include "gpio.h"
#include "util.h"

/// @brief Example integer square root
/// @return integer square root of n
uint32_t isqrt(uint32_t n) {
    uint32_t res = 0;
    uint32_t bit = (uint32_t)1 << 30;

    while (bit > n) bit >>= 2;

    while (bit) {
        if (n >= res + bit) {
            n -= res + bit;
            res = (res >> 1) + bit;
        } else {
            res >>= 1;
        }
        bit >>= 2;
    }
    return res;
}

char receive_buff[16] = {0};

int test_dma_read( char *ptr, int max_len );
int test_dma_write( char *ptr, int max_len, char *buf );
volatile long *hw_reg = ((long *)0x20000000);

// ascon test buffers
char key[16] = { 0x90, 0xE4, 0x15, 0xD6, 0x42, 0xBF, 0xCD, 0x59, 0xF1, 0xFC, 0xCA, 0x19, 0x6B, 0x3B, 0xB3, 0x09 };
char npub[16] = { 0x8C, 0xEE, 0x7C, 0xDD, 0x81, 0x83, 0xCA, 0x6A, 0xA2, 0xDC, 0x9B, 0x8B, 0x20, 0xA1, 0x6E, 0x8E };
char ad[9] = { 0x2B, 0x0A, 0x5B, 0x7A, 0x81, 0xDE, 0x31, 0x73, 0xE2 };
char pt[9] = { 0x32, 0x3B, 0x41, 0xEE, 0x00, 0xAE, 0x8A, 0x14, 0xAA };
char ct[9] = { 0x3C, 0x71, 0xC7, 0xBA, 0xDE, 0x48, 0x01, 0x2E, 0x1D };
char otag[16] = { 0xB2, 0x6E, 0x66, 0xA8, 0xA5, 0x5D, 0x6A, 0x93, 0x28, 0xD8, 0xD0, 0x5B, 0xC1, 0x67, 0x8A, 0x3E };
char tag[16];
char auth[4];
char hash[32];
char ohash[32] = { 0xFB, 0xE3, 0x34, 0x4F, 0xE7, 0x91, 0xB5, 0x29, 0x89, 0xFD, 0x4C, 0x22, 0x05, 0x94, 0xDA, 0xAA, 
                   0x72, 0x51, 0x6F, 0x55, 0x12, 0x2A, 0xBF, 0x75, 0xFC, 0x38, 0xAB, 0xF0, 0xA1, 0xBA, 0xB0, 0x75 };

int main() {
    uart_init(); // setup the uart peripheral

    // simple printf support (only prints text and hex numbers)
    printf("Hello World!\n");
    // wait until uart has finished sending
    uart_write_flush();

    // Create ASCON Instructions
    printf("ASCON test\n");
    long cmd[30];
    int  ad_len = 9;
    int  msg_len = 9;
	// Encode it
    cmd[0] = (1/*ENC*/<<28) + (ad_len<<12) + (msg_len<<0); // { cmd[7:0], ad_len[11:0], msg_len[11:0] }
    cmd[1] = (long)key;
    cmd[2] = (long)npub;
    cmd[3] = (long)ad;
    cmd[4] = (long)pt;
    cmd[5] = (long)tag;
	// Decode and Auth
    cmd[6] = (2/*DEC*/<<28) + (ad_len<<12) + (msg_len<<0); // { cmd[7:0], ad_len[11:0], msg_len[11:0] }
    cmd[7] = (long)key;
    cmd[8] = (long)npub;
    cmd[9] = (long)ad;
    cmd[10]= (long)pt;
    cmd[11]= (long)tag;
    cmd[12]= (long)auth;
	// Encode it again
    cmd[13] = (1/*ENC*/<<28) + (ad_len<<12) + (msg_len<<0); // { cmd[7:0], ad_len[11:0], msg_len[11:0] }
    cmd[14] = (long)key;
    cmd[15] = (long)npub;
    cmd[16] = (long)ad;
    cmd[17] = (long)pt;
    cmd[18] = (long)tag;
	// Hash
    cmd[19] = (3/*HASH*/<<28) + (msg_len<<0); // { cmd[7:0], ad_len[11:0], msg_len[11:0] }
    cmd[20] = (long)key; // use first 9 bytes of it as msg
    cmd[21] = (long)hash;

    printf("Go\n");
    hw_reg[4] = 22<<2; // command length
    hw_reg[1] = (long)cmd; // Start command list
	printf("sts %x\n", hw_reg[6] );
	printf("sts %x\n", hw_reg[6] );
	printf("sts %x\n", hw_reg[6] );
    //while( (hw_reg[6] & (1<<8)) == 0 ); // wait for cmds to be issued
    ////while( (hw_reg[6] & (1<<25)) != 0 ); // wait for cipher dome
    printf("Done\n");
    uart_write_flush();
    return(1); ///////////////////////
    for( int ii = 0; ii < 4; ii++ ) 
	putchar( auth[ii] );
    printf(" Auth %x\n", *(long *)auth );
    	int err;
	err = 0;
	// pt should = ct
	for( int ii = 0; ii < 9; ii++ )
		if( pt[ii] != ct[ii] ) {
			printf("idx %x PT(%x) != CT(%x)\n", ii, pt[ii], ct[ii] );
			err++;
		}
	// tag = otag
	for( int ii = 0; ii < 16; ii++ )
		if( tag[ii] != otag[ii^3] ) {
			printf("idx %x tag(%x) != otag(%x)\n", ii, tag[ii], otag[ii] );
			err++;
		}
	printf( (err ) ? "\e[31mERROR\e[0m\n" : "\e[42mPASSED\e[0m\n");

    uart_write_flush();
    return(1);

    // Print out a string
    printf("\n");
    printf( "CT long = %x\n", ((long *)ct)[0] ); // shows little endian
    printf( "MAGIC = %x\n", *((long *)0x20000000) );

    printf( "PT = " );
    for(uint8_t idx = 0; idx<9; idx++) {
		printf( "%x ", pt[idx] );
    }
    printf( "\n" );
    printf( "tag = " );
   	for(uint8_t idx = 0; idx<9; idx++) {
		printf( "%x ", tag[idx] );
    }
    printf( "\n" );

    /////////////////////////////////////
    // Test Cipher in encode mode
    /////////////////////////////////////


    return(1);

	
    // test DMA writes
    test_dma_write( (char *)cmd[7] , 9, tag );
    // Read dma tests, byte offsets, byte lenghs
    test_dma_read( (char *)cmd[7] , 9 );

    uart_write_flush();
    
// uart loopback
    uart_loopback_enable();
    printf("internal msg\n");
    sleep_ms(1);
    for(uint8_t idx = 0; idx<15; idx++) {
        receive_buff[idx] = uart_read();
        if(receive_buff[idx] == '\n') {
            break;
        }
    }
    uart_loopback_disable();

    printf("Loopback received: ");
    printf(receive_buff);
    uart_write_flush();

    // toggling some GPIOs
    gpio_set_direction(0xFFFF, 0x000F); // lowest four as outputs
    gpio_write(0x0A);  // ready output pattern
    gpio_enable(0xFF); // enable lowest eight
    // wait a few cycles to give GPIO signal time to propagate
    asm volatile ("nop; nop; nop; nop; nop;");
    printf("GPIO (expect 0xA0): 0x%x\n", gpio_read());

    gpio_toggle(0x0F); // toggle lower 8 GPIOs
    asm volatile ("nop; nop; nop; nop; nop;");
    printf("GPIO (expect 0x50): 0x%x\n", gpio_read());
    uart_write_flush();

    // doing some compute
    //uint32_t start = get_mcycle();
    //uint32_t res   = isqrt(1234567890UL);
    //uint32_t end   = get_mcycle();
    //printf("Result: 0x%x, Cycles: 0x%x\n", res, end - start);
    //uart_write_flush();

    // using the timer
    printf("Tick\n");
    sleep_ms(10);
    printf("Tocking\n");
    uart_write_flush();
    return 1;
}

int test_encode_low_level( long *hw_reg, char *key, char *npub, char *ad, char *pt, char *tag, int len_ad, int len_msg )
{
	int err = 0;
#define BDI_EOT	(1<<1)
#define BDI_EOI	(1<<0)
#define BDI_LIO (1<<8)
#define MODE_ENC 1
#define BDI_TYPE_NOP   (0<<2)
#define BDI_TYPE_NONCE (1<<2)
#define BDI_TYPE_AD    (2<<2)
#define BDI_TYPE_MSG   (3<<2)


#define STATUS_BDI_DEV  (4<<16)
#define STATUS_BDI_DMA  (2<<16)
#define STATUS_BDI_CMD  (1<<16)
#define STATUS_KEY_DEV  (4<<12)
#define STATUS_KEY_DMA  (2<<12)
#define STATUS_KEY_CMD  (1<<12)
#define STATUS_CMD_DEV  (4<<8 )
#define STATUS_CMD_DMA  (2<<8 )
#define STATUS_CMD_CMD  (1<<8 )
#define STATUS_BDO_DEV  (4<<4 )
#define STATUS_BDO_DMA  (2<<4 )
#define STATUS_BDO_CMD  (1<<4 )
#define STATUS_AUTH_DEV  (4<<0 )
#define STATUS_AUTH_DMA  (2<<0 )
#define STATUS_AUTH_CMD  (1<<0 )
#define STATUS_AUTH      (1<<26 )
#define STATUS_DONE      (1<<25 )

#define REG_CONTROL	13
#define REG_MODE	14
#define REG_LENGTH	 4
#define REG_STATUS	 6
#define REG_BDO		 9
#define REG_BDI		11
#define REG_KEY		 7

    // This test mimics what the automated commands will perform

    printf("Encode test\n");
    hw_reg[REG_CONTROL] = 0;
    hw_reg[REG_KEY    ] = (long)key; // send a key before starting enc
    while( ( hw_reg[REG_STATUS] & STATUS_KEY_DMA ) == 0  ); // wait for key data to start
    hw_reg[REG_MODE] = MODE_ENC; // put into encode mode
    while( ( hw_reg[REG_STATUS] & STATUS_KEY_CMD ) == 0  ); // wait for key cmd complete
    hw_reg[REG_LENGTH ] = 16 ; // set nonce length
    hw_reg[REG_CONTROL] = BDI_EOT + BDI_TYPE_NONCE;  // set to 1 message nonce
    hw_reg[REG_BDI    ] = (long)npub; // send nonce via bdi
    while( ( hw_reg[REG_STATUS] & STATUS_BDI_CMD ) == 0  ); // wait for nonce bdi to complete
    hw_reg[REG_LENGTH ] = len_ad; // set ad length
    hw_reg[REG_CONTROL] = BDI_EOT + BDI_TYPE_AD; // set to AS
    hw_reg[REG_BDI    ] = (long)ad; // send ad via bdi
    while( ( hw_reg[REG_STATUS] & STATUS_BDI_CMD ) == 0  ); // wait for bdi send
    hw_reg[REG_LENGTH ] = len_msg; // set msg length
    hw_reg[REG_CONTROL] = BDI_LIO + BDI_EOT + BDI_EOI + BDI_TYPE_MSG; // Set to msg type, last input, link in-out
    hw_reg[REG_BDO    ] = (long)pt; // start BDO write
    hw_reg[REG_BDI    ] = (long)pt; // start BDI
    while( ( hw_reg[REG_STATUS] & STATUS_BDI_CMD ) == 0  ); // wait BDI complete
    while( ( hw_reg[REG_STATUS] & STATUS_BDO_CMD ) == 0  ); // wait BDO complete
    hw_reg[REG_CONTROL] = 0; // turn off LIO 
    hw_reg[REG_LENGTH ] = 16; // set tag length (128 bits fixed)
    hw_reg[REG_BDO    ] = (long)tag; // start BDO for tag
    while( ( hw_reg[REG_STATUS] & STATUS_BDO_CMD ) == 0  ); // wait for BDO write complete
    while( ( hw_reg[REG_STATUS] & STATUS_DONE ) == 0  ); // wait/confirm cipher is done
    printf("Done\n");
	// pt should = ct
	for( int ii = 0; ii < 9; ii++ )
		if( pt[ii] != ct[ii] ) {
			printf("idx %x PT(%x) != CT(%x)\n", ii, pt[ii], ct[ii] );
			err++;
		}
	// tag = otag
	for( int ii = 0; ii < 16; ii++ )
		if( tag[ii] != otag[ii^3] ) {
			printf("idx %x tag(%x) != otag(%x)\n", ii, tag[ii], otag[ii] );
			err++;
		}
	printf( (err ) ? "\e[31mERROR\e[0m\n" : "\e[42mPASSED\e[0m\n");
    uart_write_flush();
    uart_write_flush();
    return( err );
}

int test_dma_read( char *ptr, int max_len ) {
    volatile long *hw_reg = ((long *)0x20000000);
    int err = 0;
    long word[4];
    word[3] = 0;
    printf( "DMA READ Test len %d\n", max_len );
    for( int len = 1; len <= max_len; len++ ) {
        hw_reg[4] = len; // set byte lenght of transfers
    	printf( "length %x\n",  hw_reg[4] );
    	for( int ii = 0 ; ii <= 3; ii++ ) { // 4 differnt start byte alignments
		printf("len %x ofs %x\n", len, ii ); // delay to make sure its done
    		hw_reg[1] = (long)(ptr+ii); // Issue DMA read  at this offset
		while( (hw_reg[6] & (1<<8)) == 0 ); // wait for command to finish
		if( len <= 4 ){
			word[0] = hw_reg[1];
			word[1] = 0;
			word[2] = 0;
    			printf( "RDATA = %x\n", word[0] ); 
		} else if ( len <= 8 ) {
			word[0] = hw_reg[2];
			word[1] = hw_reg[1];
			word[2] = 0;
    			printf( "RDATA = %x %x\n", word[1], word[0] ); 
		} else {
			word[0] = hw_reg[3];
			word[1] = hw_reg[2];
			word[2] = hw_reg[1];
    			printf( "RDATA = %x %x %x\n", word[2], word[1], word[0] ); 
		}
		// check data
		err = 0;
		for( int jj = 0; jj < len; jj++ ) {
			char ref, test;
			ref = ptr[ii+jj];
			test = ((char*)word)[jj]; // always aligned
			if( ref != test ) { 
				err++;
			}
		}
		printf( (err ) ? "\e[31mERROR\e[0m\n" : "\e[42mPASSED\e[0m\n");
		if( err ) printf("len %x ofs %x status %x\n", len, ii, hw_reg[6] );
    	}
    }
    uart_write_flush();
    return( err );
}

// using test data, use the dma writes of various byte offsets and lengths into
// the buffer
int test_dma_write( char *test_data, int max_len, char *buf ) 
{
	int err;
	volatile long *cmd_reg = ((long *)0x20000014);
	volatile long *len_reg = ((long *)0x20000010);

    	printf( "DMA write test\n" );
    	for( int len = 1; len <= max_len; len++ ) {
        	*((long *)0x20000010) = len; // set byte lenght of transfers
    		printf( "length %x\n", *len_reg);
    		uart_write_flush();
		//*len_reg = len;
    		for( int ii = 0 ; ii <= 3; ii++ ) { // 4 differnt start byte alignments
    			printf( "len %x ofs %x\n ", len, ii );
			*((long *)(buf+8))=0;
			*((long *)(buf+4))=0;
			*((long *)(buf+0))=0;
    			cmd_reg[0]  = (long)(buf+ii); // Issue DMA read  at this offset
    			uart_write_flush();
			for( int jj = 0; jj < len; jj+= 4) { // feed data input
				while( cmd_reg[1] & 2 == 0 ); // wait until ready for data
				cmd_reg[1] = *((long *)(test_data+jj));
			}
			while( cmd_reg[1] & 1 == 0 ); // wait till done;
			err = 0;
			for( int jj = 0; jj < len; jj++ ) 
				if( test_data[jj] != buf[ii+jj] ) 
					err++;
			printf("%x %x %x\n",*((long *)(buf+8)),*((long *)(buf+4)),*((long *)(buf+0)));
			printf( (err ) ? "\e[31mERROR\e[0m\n" : "\e[42mPASSED\e[0m\n");
			if( err ) printf("len %x ofs %x status %x\n", len, ii, *((long *)0x20000018));
    			uart_write_flush();
		}
	}
    uart_write_flush();
	return( err );
}
