/*
 * lab5_duty_cycle.asm
 *
 *  Created: 10/4/2014 9:19:25 PM
 *   Author: chaojie wang
 */ 

 .nolist
 .include "m16def.inc"   ;include part specific header file
 .list

 init:
	cbi DDRC, 0			;set up LOAD button on PC0
	sbi PORTC, 0			;enable pull up for PC0
	sbi DDRA, 0			;output PA0 for PWM
	ldi r16, 0x00			;prepare to setup 8 inputs controls
	out DDRD, r16			;set up PORTD as inputs
	ldi r16, 0xff			;prepare to enable pull-up for PIND
	out PORTD, r16			;enable pull-up for PIND
	ldi r16, 0xff			;prepare to setup 7-segment LEDs
	out DDRB, r16			;set 7-segment LEDs as outputs
	ldi r20, 1			;The default duty cycles, which is 10% as now
	;initialize stack pointer
	ldi r16, low(RAMEND)
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16

main_loop:
	;generate waves and display on 7-segment LEDs
	sbis PINC, 0				;check if load button is pushed
	rjmp load_requested			;yes.
	;TODO generate waves based on r20, and display on 7-segment LEDs
	sbi PORTA, 0				;high level of the pulse
	ldi r16, 25				;the multiply factor for getting delay
	mul r16, r20				;get the delay parameter
	mov r16, r0				;get the value
	subi r16, 3				;adjust it because of other instruction time
	rcall delay_by_4N			;delay r20*100 ns
	cbi PORTA, 0				;low level of the pulse
	ldi r17, 10				;prepare to get delay time
	sub r17, r20				
	ldi r16, 25
	mul r16, r17
	mov r16, r0
	subi r16, 9				;adjust it because of other instruction time
	rcall delay_by_4N			;delay (10-r20)*100ns
	mov r16, r20				;prepare to display the duty cycle
	rcall display_7seg			;display the result
	rjmp main_loop



load_requested:
	ldi r17, 10				;outer loop
filter_noise:
	ldi r16, 0xfe				
	rcall delay_by_4N			;roughly 1ms
	dec r17
	brne filter_noise			;10 times of 1ms
	sbic PINC, 0				;check if the button is still being pressed
	rjmp main_loop				;no, it's noise
	in r16, PIND				;read in the value
	andi r16, 0x0f				;mask out higher 4 nipples
	cpi r16, 0x0a				;compare readin with 10
	brsh invalid_input1			;10 or above. invalid input. correct it
	cpi r16, 0x01				;compare readin with 0	
	brlo invalid_input2			;0, invalid. correct it.
	mov r20, r16				;valid input, set the new duty cycle
	rjmp wait_for_btn_release

invalid_input1:
	ldi r20, 9				;correct wrong input with 9, and setthe new duty cycle
	rjmp wait_for_btn_release
	
invalid_input2:
	ldi r20, 1				;correct wrong input with 1, and setthe new duty cycle
	rjmp wait_for_btn_release

wait_for_btn_release:
	sbic PINC, 0				;check the load button
	rjmp main_loop				;it's released, go back to main loop
	rjmp wait_for_btn_release		;otherwise, continue waiting


;generate (N+1)*4-1 ns delay (in 1MHz clock frequency)
;where N is specified by r16
;r16>0
delay_by_4N:
	dec r16
	nop
	brne delay_by_4N
	ret

;display number on 7seg
;uses r16 as the number, r17 is used as tmp variable
;clock: 13
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
