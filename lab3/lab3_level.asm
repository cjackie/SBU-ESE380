
;
; inout.asm: a simple program to display the
;			the number of switches is ON. The
;			number will be indicated by number
;			LED is on started from bottom.
;  
; inputs: DIP 8 switches, PD0 to PD7
; outputs:  Bargraph, 8 LEDs, PB0 to PB7.
;
; assume: nothing
; alters: r16, r17, r18, SREG
;
; Author: Chaojie Wang, Zhaoqi Li
; Updated: 9/21/2014 9:47:53 PM
; Version: 1.0

.nolist
.include "m16def.inc"   ;include part specific header file
.list

reset:
	; Configure IO port(1 pass only)
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
	brcc dec_counter		;don't add one LED to r18 if the bit is 0
	ror r18				;add one lED to r18 otherwise.

dec_counter:
	dec r17				;decrement counter
	brne next_bit			;go back to next_bit loop to count remaining bits if needed
	;prepare output and light up LEDs
	com r18				;because LEDs are active low
	out PORTB, r18			;show the result
	rjmp main_loop		
	
