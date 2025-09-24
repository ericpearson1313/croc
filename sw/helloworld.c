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
char opt[9] = { 0x32, 0x3B, 0x41, 0xEE, 0x00, 0xAE, 0x8A, 0x14, 0xAA };
char ct[9] = { 0x3C, 0x71, 0xC7, 0xBA, 0xDE, 0x48, 0x01, 0x2E, 0x1D };
char oct[9] = { 0x3C, 0x71, 0xC7, 0xBA, 0xDE, 0x48, 0x01, 0x2E, 0x1D };
char otag[16] = { 0xB2, 0x6E, 0x66, 0xA8, 0xA5, 0x5D, 0x6A, 0x93, 0x28, 0xD8, 0xD0, 0x5B, 0xC1, 0x67, 0x8A, 0x3E };
char tag[16];
char auth[4];
char hash[32];
char ohash[32] = { 0xFB, 0xE3, 0x34, 0x4F, 0xE7, 0x91, 0xB5, 0x29, 0x89, 0xFD, 0x4C, 0x22, 0x05, 0x94, 0xDA, 0xAA, 
                   0x72, 0x51, 0x6F, 0x55, 0x12, 0x2A, 0xBF, 0x75, 0xFC, 0x38, 0xAB, 0xF0, 0xA1, 0xBA, 0xB0, 0x75 };
char oxof[16] = { 0xD6, 0x25, 0x86, 0x5F, 0x2F, 0x05, 0x4C, 0x7C, 0x32, 0xB7, 0x30, 0x42, 0xF5, 0x2B, 0xB8, 0x92 };
char xof[16];

int main() {
    uart_init(); // setup the uart peripheral

    // simple printf support (only prints text and hex numbers)
    printf("Hello World!\n");
    // wait until uart has finished sending
    uart_write_flush();

    // Create ASCON Instructions
    printf("ASCON test\n");
    int  ad_len = 9;
    int  msg_len = 9;
    int  hash_len = 16;

    //////////////////////////////////////
    // Build Cipher Command List
    //////////////////////////////////////
    long cmd[30];
    int  cidx = 0;
    cmd[cidx++] = (1/*ENC*/<<28) + (ad_len<<12) + (msg_len<<0); // { cmd[7:0], ad_len[11:0], msg_len[11:0] }
    cmd[cidx++] = (long)key;
    cmd[cidx++] = (long)npub;
    cmd[cidx++] = (long)ad;
    cmd[cidx++] = (long)pt; // rw
    cmd[cidx++] = (long)tag; // w
    cmd[cidx++] = (2/*DEC*/<<28) + (ad_len<<12) + (msg_len<<0); // { cmd[7:0], ad_len[11:0], msg_len[11:0] }
    cmd[cidx++] = (long)key;
    cmd[cidx++] = (long)npub;
    cmd[cidx++] = (long)ad;
    cmd[cidx++] = (long)ct; // rw
    cmd[cidx++] = (long)tag; 
    cmd[cidx++] = (long)auth; // w
    cmd[cidx++] = (3/*HASH*/<<28) + (msg_len<<0); // { cmd[7:0], ad_len[11:0], msg_len[11:0] }
    cmd[cidx++] = (long)key; // read this as msg
    cmd[cidx++] = (long)hash; // w
    cmd[cidx++] = (4/*XOF*/<<28) + (msg_len<<0); // { cmd[7:0], ad_len[11:0], msg_len[11:0] }
    cmd[cidx++] = hash_len;
    cmd[cidx++] = (long)key; // read this as msg
    cmd[cidx++] = (long)xof; // w

    printf("Go\n");

    //////////////////////////////////////
    // Execute Cipher Engine Command List
    //////////////////////////////////////
    //
    hw_reg[4] = cidx<<2; // command list length
    hw_reg[1] = (long)cmd; // Start execution on command list
    while( (hw_reg[6] & 0x2011111) != 0x2011111 ); // wait for completion (dmas complete and cipher done)
    //
    //////////////////////////////////////

    printf("Done\n");
    printf("Auth %x [", *(long *)auth );
    for( int ii = 0; ii < 4; ii++ ) 
	putchar( auth[ii] );
    printf("]\n");
    	int err;
	err = 0;
	// AUth should be "pass"
        for( int ii = 0; ii < 4; ii++ ) 
		if( auth[ii] != ((ii == 0)?'p':(ii==1)?'a':'s')) {
			err++;
		}
	// pt should = oct
	for( int ii = 0; ii < msg_len; ii++ )
		if( pt[ii] != oct[ii] ) {
			err++;
		}
	// ct should = opt
	for( int ii = 0; ii < msg_len; ii++ )
		if( ct[ii] != opt[ii] ) {
			err++;
		}
	// tag = otag
	for( int ii = 0; ii < 16; ii++ )
		if( tag[ii] != otag[ii] ) {
			err++;
		}
	// hash = ohash
	for( int ii = 0; ii < 32; ii++ )
		if( hash[ii] != ohash[ii] ) {
			err++;
		}
	// xof = oxof 
	for( int ii = 0; ii < hash_len; ii++ )
		if( xof[ii] != oxof[ii] ) {
			err++;
		}
	printf( (err ) ? "\e[31mERROR\e[0m\n" : "\e[42mPASSED\e[0m\n");

    uart_write_flush();
    return(1);

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
