
;
; inout.asm: a simple program to display the
;			the number of switches is ON. The 
;			displayed will be realized by 7-segment
;			LED
;  
; inputs: DIP 8 switches, PD0 to PD7
; outputs:  7-segment LED, PB0 to PB7.
;
; assume: nothing
; alters: r16, r17, r18, Z, SREG
;
; Author: Chaojie Wang, Zhaoqi Li
; Updated: 9/21/2014 10:34:53 PM
; Version: 1.0

.nolist
.include "m16def.inc"   ;include part specific header file
.list

reset:
	;Configure IO port(1 pass only)
	ldi r16, 0xFF			;prepare bits to configure PortB
	out DDRB, r16			;all bits of PortB are configured to be output

	ldi r16, 0x00			;prepare bits to configure PortD
	out DDRD, r16			;all bits of PortD are configured to be input
	ldi r16, 0xFF			;prepare bit to enable internal pull-up resistors
	out PORTD, r16			;enable internal pull-up for PIND

main_loop:
	in r16, PIND			;read values of switches
	;initialize variables for counting the number of switches is ON
	ldi r17, 8			;the counter
	ldi r18, 0x00			;the output to the bargraph

next_bit:
	lsl r16				;extract one bit from r16
	brcc dec_counter		;don't add one r18 if the bit is 0
	inc r18				;add one to r18 otherwise.

dec_counter:
	dec r17				;decrement counter
	brne next_bit			;go back to next_bit loop to count remaining bits if needed

bcd_7seg:
	;display the result with 7-segment LEDs
	ldi ZH, high(table*2)		;prepare the pointer to the table
	ldi ZL, low(table*2)		;
	ldi r16, 0x00			;clear for later use
	add ZL, r18			;advance the pointer according to number of "on" switches
	adc ZH, r16			;
	lpm r18, Z			;look up the table to get bit pattern for 7-segment display
	;display 7-segment LEDs
	out PORTB, r18			;display the number
	rjmp main_loop			;return to main loop
	
	;bit patterns for displaying numbers on 7-segments LEDs
table: .db 0x40,0x79,0x24,0x30,0x19,0x12,0x03,0x78,0x00
		   ;  0    1    2    3    4    5    6    7    8
