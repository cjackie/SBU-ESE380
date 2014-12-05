/*
 * dec_inc_counter.asm: a program to increment and 
 *			decrement counter and display on the 7-segment
 *			display
 *
 * inputs: PC0, PC6, and PC7
 * outputs: 7 segment LEDs(PORTB), denouciator(PA7) for overflow
 *
 * assume: buttons are not pressed simultanously
 *
 *  Created: 9/27/2014 5:38:57 PM
 *  Author: chaojie wang
 *  Lab section 04
 *  Lab station 01
 */ 

 .nolist
 .include "m16def.inc"   ;include part specific header file
 .list

 reset:
	ldi r16, 0xff				;prepare to configure PORTB
	out DDRB, r16				;set PORTB as outputs
	ldi ZH, high(table*2)			;prepare the pointer to the table 
	ldi ZL, low(table*2)			;to display default value "0"
	lpm r16, Z				;get "0" bit pattern
	out PORTB, r16				;display "0"
	ldi r17, 0				;number should be displayed.

	cbi DDRC, 0				;set PC0 as input(inc button)
	sbi PORTC, 0				;enable pull-up fpr PC0
	cbi DDRC, 6				;same for PC6(dec button)
	sbi PORTC, 6
	cbi DDRC, 7				;same for PC7(reset button)
	sbi PORTC, 7
	sbi DDRA, 0				;set PA0 as output(denounciator)
	sbi PORTA, 0				;default is 1(Off) for denounciator

check_btns:
	;check if any buttons are press. 
	sbis PINC, 0				;check if inc button is pressed
	rjmp check_inc_button			;jump to subroutine to see if it's a noise
	sbis PINC, 6				;same for dec button
	rjmp check_dec_button		
	sbis PINC, 7				;same for reset button
	rjmp check_reset_button
	rjmp check_btns				;no buttons are pressed, go back and wait

check_inc_button:
	ldi r23, 0xff				;initial variables to make 10ms delay
	ldi r24, 0x0a
wait_for_10ms_inner_0:
	nop
	dec r23					;counting
	brne wait_for_10ms_inner_0		;checking if 256 times has pass
	ldi r23, 0xff					
	dec r24					;counting
	brne wait_for_10ms_inner_0
	sbic PINC, 0
	rjmp check_btns				;it's a noise, go back and wait for buttons
	cpi r17, 9				;see if need to rollover
	brsh inc_rollover			;yea, rollover
	inc r17					;no, add one
	ldi ZH, high(table*2)			;prepare to look up table
	ldi ZL, low(table*2)
	ldi r18, 0x00				;prepare to advance cursor
	add ZL, r17
	adc ZH, r18				;advance cursor
	lpm r16, Z				;read in bit pattern with value r17
	out PORTB, r16				;display
	rjmp wait_for_release			;done. wait for button release

inc_rollover:
	;increment when number is 9
	ldi r17, 0				;rollover
	ldi ZH, high(table*2)			;prepare to look up table
	ldi ZL, low(table*2)
	lpm r16, Z				;read in bit pattern for "0"
	out PORTB, r16				;display
	sbic PORTA, 0				;check if PA0 is 0 or 1
	cbi PORTA, 0				;it's 1, so turn it to 0(toggle)
	sbi PORTA, 0				;toggle
	rjmp wait_for_release			;done, wait for button release

check_dec_button:
	ldi r23, 0xff				;initial variables to make 10ms delay
	ldi r24, 0x0a
wait_for_10ms_inner_1:
	nop
	dec r23					;counting
	brne wait_for_10ms_inner_1		;checking if 256 times has pass
	ldi r23, 0xff					
	dec r24					;counting
	brne wait_for_10ms_inner_1
	sbic PINC, 6				;check the button again
	rjmp check_btns				;it's a noise, go back and wait
	cpi r17, 0				;see if the display is already 0
	breq check_btns				;disregard the button press if it's 0
	dec r17					;otherwise, decrement
	ldi ZH, high(table*2)			;prepare to look up table
	ldi ZL, low(table*2)
	ldi r18, 0x00				;prepare to advance cursor
	add ZL, r17
	adc ZH, r18				;advance cursor
	lpm r16, Z				;read in bit pattern with value r17
	out PORTB, r16				;display
	rjmp wait_for_release			;done. wait for button release

check_reset_button:
	ldi r23, 0xff				;initial variables to make 10 ms delay
	ldi r24, 0x0a
wait_for_10ms_inner_2:
	nop
	dec r23					;counting
	brne wait_for_10ms_inner_2		;checking if 256 times has pass
	ldi r23, 0xff					
	dec r24					;counting
	brne wait_for_10ms_inner_2
	sbic PINC, 7				;check the button again
	rjmp check_btns				;it's a noise, go back and wait
wait_reset_btn_release:
	sbis PINC, 7				;check if it's released					
	rjmp wait_reset_btn_release
	rjmp reset				;otherwise, reset


;TODO, before go back, call this function to wait for button to release
wait_for_release:
	in r16, PINC				;read in buttons status
	andi r16, 0xc1				;mask out not used pins
	ldi r18, 0x3f				;prepare variable
	add r16, r18				;determine if all bits are 1(buttons are released)
	brcs jmp_to_check_btns			;all buttons are released
	rjmp wait_for_release			;wait for all buttons are released
	
jmp_to_check_btns:
	rjmp check_btns


	;bit patterns for displaying numbers on 7-segments LEDs
table: .db 0x40,0x79,0x24,0x30,0x19,0x12,0x03,0x78,0x00,0x10
		   ;  0    1    2    3    4    5    6    7    8	   9
