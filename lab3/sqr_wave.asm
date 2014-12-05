
;
; sqr_wave: a program to generate square wave
;
; inputs: None
; outputs:  PORTA, DDRA
;
; Author: Chaojie Wang, Zhaoqi Li
; Updated: 9/22/2014 9:47:53 PM
; Version: 1.0

.nolist
.include "m16def.inc"   ;include part specific header file
.list

reset:
	ldi r16, 0xff		;prepare bits to set portA as outputs
	out DDRA, r16		;set portA as outputs
	cbi PortA, 0		;init value for PA0 to 0

main_loop:
	cbi PortA, 0		;signal 0
	nop					;add some delay
	nop
	sbi PortA, 0		;signal 1
	rjmp main_loop		;repeat the wave

