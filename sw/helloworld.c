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


volatile long *hw_reg = ((long *)0x20000000); // address of aoc HW

int main() {
    // init uart, gpio
    gpio_set_direction(0xFFFF, 0x000F); // 4 lsb's are output bits
    gpio_enable(0xFF); 
    gpio_write(0x00);
    uart_init(); // setup the uart peripheral
    printf("Hello Advent of Code 2025, Day 1!\n");
    uart_write_flush();

    // Handshake bytes in via serial
    char c = 0;
    unsigned count = 0;
    int status;
    int sign;
    int value;


    //printf("Magic = %x\n", hw_reg[0] );
    //printf("Read 1= %x\n", hw_reg[1] );
    hw_reg[0] = 0; // Init the aoc hardware
    while(1) {
	status = gpio_read()&0xf0;
	while( status != 0xA0 && status != 0xE0 ) { // wait for RTS or EOF
		status = gpio_read() & 0xf0;
        }
	if( status == 0xE0 ) // EOF
		break;
    	gpio_write(0x0A); // set CTS
    	c = uart_read(); // read char and comppute
	switch( c ) {
	  case 'L' : sign =  1; value = 0; break;
	  case 'R' : sign =  0; value = 0; break;
	  case '0' : case '1' : case '2' : case '3' : case '4' : case '5' : case '6' : case '7' : case '8' : case '9' :
		// printf("char %x value %x\n", c, value);
		value = (value*10) + (c-'0'); 
		break;
	  case 0xA : // cr
		//printf(((sign)?"-0x%x\n":"+0x%x\n" ), value );
		hw_reg[1] = (sign << 31) | value; // Give data to hw
		count++;
		break;
	  default: 
		break;
	}
	status = gpio_read()&0xf0;
	//printf("status %x\n", status ); uart_write_flush();
    	while( status == 0xA0 ){ // wait !RTS
		status = gpio_read() & 0xf0;
		//printf("status %x\n", status ); uart_write_flush();
	}
    	gpio_write(0x00); // clear CTS
    }

    // Print summary
    printf("\e[32mNum Rotations = 0x%x, Day 1 Part 1 = 0x%x, Part 2 = 0x%x\e[0m\n", count, hw_reg[2]>>16,  hw_reg[2]&0xffff );
    uart_write_flush();

    return 1;
}
