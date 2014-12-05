/*
 * lab6_cond_trans_select_srff.asm:
 *	A program that accepts input from the users and display
 *	it on the 7-segment display. It can select either higher
 *	nipples or lower nipples, which is controlled by the 
 *	service request flip-flop.The SELECT value will be 
 *  indicated by LEDs connected to PA0, and PA1. The LOAD
 *  button tells the program to load the value and display it.
 *
 *  assume: nothing
 *
 *  inputs: PA7, PA5, PC0, and PORTD
 *  outputs: PORTB, and PA0, PA1, PA6
 *
 *  assume: nothing
 *	alter:	r16, r17, r22, r23: GP register
 *  flash words: 80
 *
 *  Created: 10/11/2014 10:31:14 AM
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
;	validate_nipples: a subroutine to verify the input
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


validate_nipples:
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
	ldi ZH, high(table*2)			;get pointer to the table
	ldi ZL, low(table*2)
	ldi r17, 0x00				;temperate variable for adding carry
	add ZL, r16				;advance the pointer to get bit pattern
	adc ZH, r17					
	lpm r16, Z				;get bit patterns
	out PORTB, r16				;display on 7-segment display
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
	ldi r16, 0xff				;prepare to config 7-segment LEDs
	out DDRB, r16				;set 7-segment leds as outputs
	ldi r16, 0x00				;prepare to config nipples
	out DDRD, r16				;set PORTD as inputs for nipples
	ldi r16, 0xff				;prepare to enable pull-ups
	out PORTD, r16				;enable pull ups for nipples
	sbi DDRA, 0				;config LED indicating lower nipples
	sbi DDRA, 1				;config LED indicating higher nipples
	cbi DDRC, 0				;set up LOAD button
	sbi PORTC, 0				;enable the pull-up for LOAD button
	cbi DDRA, 7				;ssfr SELECT request pin
	cbi DDRA, 5				;detect select btn for debouncing.
	sbi DDRA, 6				;set up the clear output fot the flip flop
	cbi PORTA, 6				;set up default for Q'(clear the request)
	sbi PORTA, 6				;
	ldi r22, 10				;the default "-" for 7-segment leds
	ldi r23, 0				;the default lower nipples for select button

main_loop:
	sbis PINC, 0				;check the load button
	rjmp load_btn				;it's pressed, branch
	sbis PINA, 7				;check if SELECT service is requested
	rjmp select_requested			;it's request, branch
	;;TODO diplay 7-segment and the led
	mov r16, r22				;prepare to show value for 7 segments
	rcall display_7seg			;show the value
	sbrs r23, 0				;check to see which to led should be lit
	rjmp light_led0				;lower nipples
	cbi PORTA, 0				;higher nipples led
	sbi PORTA, 1
	rjmp main_loop				

light_led0:
	cbi PORTA, 1				;lower nipples led
	sbi PORTA, 0
	rjmp main_loop				;continue looping


load_btn:
	ldi r16, 10				;prepare to filter
	rcall delay_by_ms			;filter with 10ms
	sbic PINC, 0				;check it's a noise
	rjmp main_loop				;it's a noise
	sbrs r23, 0				;decide which nipples to read
	rjmp lower_nipples			;read from lower nipples
	rjmp higher_nipples			;read from higher nipples

lower_nipples:
	in r16, PIND				;read in
	andi r16, 0x0f				;mask out higher nipples
	rcall validate_nipples			;check if inputs are valid. correct it if needed
	mov r22, r16				;update the value for 7seg
	rjmp wait_load_release			;wait for it to be released

higher_nipples:
	in r16, PIND				;read in
	swap r16				;use higher nipples
	andi r16, 0x0f				;mask out lower nipples
	rcall validate_nipples			;check if inputs are valid. correct it if needed
	mov r22, r16				;update the value for 7seg
	rjmp wait_load_release			;wait for it to be released

wait_load_release:
	sbic PINC, 0				;check if btn released yet?
	rjmp main_loop				;yea. released
	rjmp wait_load_release			;continue waiting

select_requested:
	ldi r16, 10				;prepare for debouncing
	rcall delay_by_ms			;delay 10ms to debounce.
	com r23					;toggle the led value
select_req_wait:
	sbic PINA, 5				;check if button is released
	rjmp select_req_wait			;it's pressed, wait for releasing
	ldi r16, 10				;released, prepare debouncing
	rcall delay_by_ms			;debouncing
	cbi PORTA, 6				;clear the request
	sbi PORTA, 6				;
	rjmp main_loop				;return to main loop
