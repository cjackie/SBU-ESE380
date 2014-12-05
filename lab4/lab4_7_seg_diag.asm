/*
 * Simple program to	turn on all 7 segments of the display 
 * when the pushbutton is pressed or held down(logic-0). 
 * All segments will be turn off when the pushbutton is
 * released (logic 1). After the first 1 or 0 is detected,
 * this program will wait a period of time and then perform
 * the second detection of constant 1 or 0 to avoid switch
 * bounces.
 *
 * inputs: PC0
 * outputs: PORTB
 * 
 * assume: nothing
 * alter: r16,r17
 * flash words used: 23
 * lab section 04
 * lab bench 01
 *  Created: 9/26/2014 10:45:18 PM
 *   Author: chaojie wang, Zhaoqi Li
 */ 

.nolist
.include "m16def.inc"   ;include part specific header file
.list

reset:
	ldi r16, 0xff			;prepare to configure PORTB
	out DDRB, r16			;set PORTB as outputs
	cbi DDRC, 0			;set PORTC0 as input
	sbi	PORTC, 0		;enable internal pull-up resistor for PINC0

wait_btn_pressed:
	sbis PINC, 0			;check if button is pressed or not
	rjmp filter_noise		;seems like the button is press, filter to see if it's a noise
	rjmp wait_btn_pressed		;button is not pressed, go back to the loop.

filter_noise:
	;delay for 10 ms to see if it's a noise
	ldi r16, 0xff			;initial variables for filter_noise
	ldi r17, 0x0a
flt_noise0:
	nop
	dec r16				;counting
	brne flt_noise0			;checking if 256 times has pass
	ldi r16, 0xff		
	dec r17				;counting
	brne flt_noise0		
	sbic PINC, 0			;determine if it's a nosie
	rjmp wait_btn_pressed		;it's a noise, go back and wait
	in r16, PORTB			;otherwise, prepare to toggle PORTB
	com r16				;toggle
	out PORTB, r16			;display on LEDs

wait_btn_released:
	sbic PINC, 0			;check if botton is released
	rjmp wait_btn_pressed		;it's released, go back and wait
	rjmp wait_btn_released		;not release, wait for it's released

