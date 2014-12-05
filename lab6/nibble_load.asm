/*
 * nibble_load.asm: a simple program to display the 
 *			BCD value from the low nibble of switches
 *
 *
 * Created: 10/16/2014 6:46:49 PM
 *
 * Description: a simple program to read inputs from low
 *			nibbles of switches when the PBSW is pressed 
 *			(go low). The MCU will decode the BCD inputs 
 *			inputs and display it on the 7-seg. The 
 *			displayed values range from 0-9. Any value
 *			larger than 9 will be reset to 9 and displayed.
 *			The program will only load the inputs once for 
 *			each PBSW press.
 *
 * Inputs: PortD(0-8): BCD inputs 
 *				(Software mask out high nibbles)
 *		   PC0: PBSW(activated when low)
 * 
 * Outputs: PortB(0-8): 7-seg LED display
 *
 * assume: nothing;
 * alter: r16: GP register
 *		  r17: debounce inner delay loop countdown
 *
 * subroutine: delay_by_ms
 *			   display_7seg
 * 
 *	Author: ZQL/CJW
 *	Lab Number: 06
 *	Lab Section: 04
 *	Bench Number: 01
 *	Version 1.1
 */ 


.nolist
.include "m16def.inc"
.list

//run program initialization
init:
	rjmp reset

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
	ret		=			;done


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
;register altered: r17(masking)
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

// intialize I/O and stack
reset:
	ldi r16, 0xFF				;setup portB as output
	out DDRB, r16				;
	ldi r16, 0x00				;setup portd as inputs
	out DDRD, r16				;
	ldi r16, 0xFF				;enable internal pull-up 
	out PORTD, r16				;of portD
	cbi DDRC, 0				;set PC0 as input for PBSW1
	sbi PORTC, 0				;enable pull-up for PC0

//initialize stack pointer
	ldi r16, low(RAMEND)		
	out SPL, r16				
	ldi r16, high(RAMEND)				
	out SPH, r16				

main_loop:
	sbic PINC, 0				; Check PC0
	rjmp main_loop				; if goes low, fall through
	ldi r16, 10				; prepare 10ms delay for 
	rcall delay_by_ms			; PBSW dobounce		
	sbic PINC, 0				; Check PC0 again to verify
	rjmp main_loop				; if still low, fall through
	in r16, PIND				; read inputs from PortD
	andi r16, 0x0F				; mask out high nibbles
	cpi r16, 10				; check if input is higher 
	brsh invalid_input			; than 9, if not ,fall through
//convert and display input 
display:
	rcall display_7seg			; call display subroutine
wait_for_release:
	sbic PINC, 0				; check PC0, if high, prepare for
	rjmp main_loop				; next load; if low, wait for 
	rjmp wait_for_release			; PBSW to be released

//for input higher than 9, reset to 9 by default
invalid_input:
	ldi r16, 9				; set inputs to be 9
	rjmp display				; go back and display 9

