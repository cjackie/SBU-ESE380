/*
 * lab6_cond_tran_select.asm:
 *	A program that accepts input from the users and display
 *	it on the 7-segment display. It can select either higher
 *	nibbles or lower nibbles, which is controlled by SELECT
 *	button. The SELECT value will be indicated by LEDs connected
 *  to PA0, and PA1. The LOAD button tells the program to load
 *	the value and display it.
 *
 *  inputs: PC6, PC0, and PORTD
 *  outputs: PORTB, and PA0, PA1
 *  outputs: 7 segment LEDs(PORTB), PA0
 * 
 *  assume: nothing
 *	alter:	r16, r17, r22, r23: GP register
 *  flash words: 68
 *
 *  Created: 10/11/2014 8:49:29 AM
 *  Author: chaojie wang
 *  Updated by: Zhaoqi Li
 *  Lab Number: 06
 *  Lab Section: 04
 *  Bench Number: 01
 * Version 1.1
 */ 

.nolist
.include "m16def.inc"		;include part specific header file
.list

//initialize
	rjmp reset

//subroutines
;	validate_nibbles: a subroutine to verify the input
;					from portD. A vaild input range between
;					0-9. inputs higher than 9 will be set to
;					10 by default then returned to the program
;
;	input: r16 (BCD unsigned)
;	output: r16
;
;	assum: nothing
;	call: not_valid 
;	program words: 5
;	register altered: r16 
;	Author: CJW/ZQL


validate_nibbles:
	cpi r16, 10				;compare it with  10
	brsh not_valid				;check
	ret					;it's vaild

not_valid:
	ldi r16, 10				;correct it with 10
	ret					;return
	
;delay_by_ms: a self-contained delay subroutine to 
;	generate N ms delay (in 1MHz clock 
;	frequency). N is the time factor for the user
;	specified frequency(the factor is passed by
;	r16 and serves as the count for outer loop).
;	The inner loop is 248 for each count down of	
;	r16.
; 
; input: r16 
; output: none
;
; calls: none
; programm memory word: 7
;
; assum: r16>0
; resiger altered:
;	r16 = outer delay loop count down
;	r17 = inner delay loop count down
;	SREG Z flag
; Author: CJW/ZQL 

delay_by_ms:
	ldi r17, 248				;the varibale for the inner loop
delay_by_ms_inner:
	nop					;total 4 cycles
	dec r17
	brne delay_by_ms_inner
	dec r16					;counting
	brne delay_by_ms			;if not done, go back and continue delay
	ret					;done

;display_7seg: a subroutine to decode the input 
;	BCD digit and determine the correspoding bit
;	pattern on the 7-segment LED based on the look
;	up table. The resulted bit pattern will be 
;   output to portB and displayed on LED.
;
;input: r16 (bcd input)
;output: portB (LED)
;
;calls: table(bit pattern lookup)
;program memory words: 7
;
;register altered: r17(carry-adding)
;				   r16(BCD pattern)
;				   Z pointer(table lookup)
;				   SREG H Flag
;	
;author: CJW/ZQL
		
display_7seg:
	ldi ZH, high(table*2)		;get pointer to the table
	ldi ZL, low(table*2)
	ldi r17, 0x00			;temperate variable for adding carry
	add ZL, r16			;advance the pointer to get bit pattern
	adc ZH, r17					
	lpm r16, Z			;get bit patterns
	out PORTB, r16			;display on 7-segment display
	ret


	;bit patterns for displaying numbers on 7-segments LEDs
table: .db 0x40,0x79,0x24,0x30,0x19,0x12,0x03,0x78,0x00,0x10
		   ;  0    1    2    3    4    5    6    7    8	   9	

//main program
reset:
	ldi r16, low(RAMEND)			;initialize stack pointer
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16
	ldi r16, 0x00				;prepare to configure nibbles
	out DDRD, r16				;setup higher and lower nibbles as inputs
	ldi r16, 0xff				;prepare to enable pull-ups
	out PORTD, r16				;enable pull-ups
	cbi DDRC, 6				;configure the select button
	sbi PORTC, 6				;enable pull up for the sellect button
	cbi DDRC, 0				;configure the load button
	sbi PORTC, 0				;pull up
	ldi r16, 0xff				;prepare to configure the 7-segment LEDs
	out DDRB, r16				;set up 7-segment LEDs
	sbi DDRA, 0				;setup the led for lower nibbles
	sbi DDRA, 1				;setup the led for higher nibbles
	ldi r22, 10				;the default "-" for 7-segment leds
	ldi r23, 0				;the default lower nibbles for select button

main_loop:
	sbis PINC, 6				;check if the select button is pressed
	rjmp select_btn				;yes. the select button might have been pressed
	sbis PINC, 0				;chekc if the load button is pressed
	rjmp load_btn				;yes. the load button might have been pressed

	mov r16, r22				;prepare to show value for 7 segments
	rcall display_7seg			;show the value
	sbrs r23, 0				;check to see which to led should be lit
	rjmp light_led0				;lower nibbles
	cbi PORTA, 0				;higher nibbles led
	sbi PORTA, 1
	rjmp main_loop				

light_led0:
	cbi PORTA, 1				;lower nibbles led
	sbi PORTA, 0
	rjmp main_loop				;continue looping

select_btn:
	ldi r16, 10				;prepare to filter
	rcall delay_by_ms			;filter with 10ms
	sbic PINC, 6				;check select again
	rjmp main_loop				;it was a noise, go back
	com r23					;toggle value of led
	rjmp wait_select_release		

wait_select_release:
	sbic PINC, 6				;check if it's released
	rjmp main_loop				;yea. it is released
	rjmp wait_select_release

load_btn:
	ldi r16, 10				;prepare to filter
	rcall delay_by_ms			;filter with 10ms
	sbis PORTC, 0				;check it's a noise
	rjmp main_loop				;it's a noise
	sbrs r23, 0				;decide which nibbles to read
	rjmp lower_nibbles			;read from lower nibbles
	rjmp higher_nibbles			;read from higher nibbles

lower_nibbles:
	in r16, PIND				;read in
	andi r16, 0x0f				;mask out higher nibbles
	rcall validate_nibbles			;check if inputs are valid. correct it if needed
	mov r22, r16				;update the value for 7seg
	rjmp wait_load_release			;wait for it to be released

higher_nibbles:
	in r16, PIND				;read in
	swap r16				;use higher nibbles
	andi r16, 0x0f				;mask out lower nibbles
	rcall validate_nibbles			;check if inputs are valid. correct it if needed
	mov r22, r16				;update the value for 7seg
	rjmp wait_load_release			;wait for it to be released

wait_load_release:
	sbic PINC, 0				;check if btn released yet?
	rjmp main_loop				;yea. released
	rjmp wait_load_release			;continue waiting

