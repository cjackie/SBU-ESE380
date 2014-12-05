/*
 * lab4_extra_credits.asm
 *
 *  Created: 10/2/2014 12:00:52 AM
 *   Author: chaojie wang
 */ 


 .nolist
 .include "m16def.inc"   ;include part specific header file
 .list

 reset:
	cbi DDRC, 0				;set PC0 as input(wavesqure button)
	sbi PORTC, 0				;enable pull-up fpr PC0
	cbi DDRC, 6				;same for PC6(10 pulses button)
	sbi PORTC, 6
	sbi DDRA, 0				;set PA0 as output
	cbi PORTA, 0				;default is low
	;legacy..
	cbi DDRC, 7				;same for PC7(reset button)
	sbi PORTC, 7

check_btns:
	;check if any buttons are press. 
	cbi PORTA, 0				;always low when no button pushed
	sbis PINC, 0				;check if squarewave button is pressed
	rjmp check_sqr_button			;jump to subroutine to see if it's a noise
	sbis PINC, 6				;same for 10 pulses button
	rjmp check_pulse_button		
	rjmp check_btns				;no buttons are pressed, go back and wait

check_sqr_button:
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
square_wave:
	sbi PORTA, 0				;high
	sbic PINC, 0				;check if it's held down
	rjmp check_btns
	cbi PORTA, 0				;low
	rjmp square_wave			;wave

check_pulse_button:
	ldi r23, 0xff				;initial variables to make 10ms delay
	ldi r24, 0x0a
wait_for_10ms_inner_1:
	nop
	dec r23					;counting
	brne wait_for_10ms_inner_1		;checking if 256 times has pass
	ldi r23, 0xff					
	dec r24					;counting
	brne wait_for_10ms_inner_1
	sbic PINC, 0
	rjmp check_btns				;it's a noise, go back and wait for buttons

	ldi r16, 10				;prepare for 10 pulse
make_10_pulses:
	dec r16							
	breq wait_for_release
	sbi PORTA, 0
	cbi PORTA, 0
	rjmp make_10_pulses

wait_for_release:
	in r16, PINC				;read in buttons status
	andi r16, 0xc1				;mask out not used pins
	ldi r18, 0x3f				;prepare variable
	add r16, r18				;determine if all bits are 1(buttons are released)
	brcs jmp_to_check_btns			;all buttons are released
	rjmp wait_for_release			;wait for all buttons are released
	
jmp_to_check_btns:
	rjmp check_btns
