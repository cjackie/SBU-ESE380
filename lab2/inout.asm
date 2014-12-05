
;
; inout.asm: a simple program to display the position
;     8 SPST switches on 8 LEDs. if the switch is a 
;     logic-1, the corresponding LED is on. if sw is 
;     logic-0, the LED is off
;  
; inputs: DIP 8 switches, PD0 to PD7
; outputs:  Bargraph, 8 LEDs, PB0 to PB7, active low
;
; assume: nothing
; alters: r16, SREG
;
; Author: Chaojie Wang, Zhaoqi Li
; Updated: 9/15/2014 9:47:53 PM
; Version: 1.0

.nolist
.include "m16def.inc"   ;include part specific header file
.list


reset:
	; Configure IO port(1 pass only)
	ldi r16, 0xFF		;prepare bits to configure PortB
	out DDRB, r16		;all bits of PortB are configured to be output
	ldi r16, 0x00		;prep	are bits to configure PortD
	out DDRD, r16		;all bits of PortD are configured to be input

again:
	; infinite loop, read input from switches and show outputs on LEDs.
	in r16, PIND		;read values of switches
	com r16			;invert input bits, because active mode is opposite for outputs.
	out PORTB, r16		;drive the output
	rjmp again		;jump back to the begining of the loop


