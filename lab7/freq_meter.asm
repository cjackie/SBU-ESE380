/*
 * lab7_freq_meas.asm: a program that measures the
 *    frequency of a wave square. 
 *
 *  Created: 10/22/2014 3:01:28 PM	
 *
 *	Description: The square wave will be input into 
 *		the MCU through PA7. The program will detect
 *		all edges of the square wave and count only 
 *		positive edges in 1s. The result of frequency 
 *		counting will be encoded and output to portB	
 *		to be displayed in LCD.The outer loop counter
 *		will be constantly adjusted to obtain a 1s
 *		counting period. 
 *
 *  Inputs: PA7(sqaure wave)
 *  Outputs: PORTB(LCD display), PA6(gated signal)
 *
 *  Assume: input wave's frequency is in the range of 
 *          10Hz to 10KHz
 *  Alters: r3,r2,r1,r0,r16,r17,r18,r19,r25,Z,Y
 *
 *	included: "lcd_dog_asm_driver_m16A.inc"
 *	subroutine: init_lcd_dog
 *				wait_for_start_edge
 *				tweak
 *				unpack_hex_val_to_bcd
 *				less_than
 *				load_msg
 *	table:	freq_message
 *			line2_message
 *			line3_message
 *
 *   Author: Chaojie Wang, Zhaoqi Li
 *	lab 07-Freq Counter I with Improved User Interface
 *	lab section 04
 *	lab bench 01
 *  Version: 1.3.0
 */ 

.nolist
.include "m16def.inc"
.list

//go to the main setup
	rjmp reset

;---------------------------- SUBROUTINES ----------------------------

;====================================
.include "lcd_dog_asm_driver_m16A.inc"  ; LCD DOG init/update procedures.
;====================================

;*******************
;NAME:      tweak
;FUNCTION: A tweaking delay count to provide in-line delay for calibration
;		r16 will be loaded with the count down value(value can be modified)
;		one nop will be used in the loop.
;ASSUME: the reasonable tweak dealy for 16 will range from 1 to 0x10.
;RETURN: Nothing
;MODIFIED: r16
;CALLS: Nothing
;*****************************************************************
tweak:
	ldi r16, 10				/*can be modify to calibrate*/
tweak_inner_loop:
	nop					;add little delay
	dec r16					;decrement counter
	brne tweak_inner_loop			;still counting
	ret					;done tweaking


;*******************
;NAME:      unpack_hex_val_to_bcd
;FUNCTION:  unpack value in r17 and r16 into BCD and store them on r3,
;           r2,r1 and r0. The order is from r3 to r0, where r3 is the 
;           most significant digit.
;ASSUME:    r17:r16 is less than 10000. otherwise r3 will be 0x0f, which
;           is invalid BCD number.
;RETURNS:   r3,r2,r1,r0
;MODIFIES:  r19,r18,r17,r16,r3,r2,r1,r0
;CALLS:     less_than
;*****************************************************************
unpack_hex_val_to_bcd:
	push r17					;save inputs
	push r16					;
	mov r19, r17					;prepare to compare
	mov r18, r16					;
	ldi r17, 0x27					;compare with 10K
	ldi r16, 0x10					;
	rcall less_than					;call subroutine
	pop r16						;restore inputs
	pop r17
	brts less_than_10K				;determine if less than 10K
	ldi r18, 0x0f					;greater than 10K
	mov r3, r18					;make r3 a invalid bcd
	ret						;ended

less_than_10K:
	ldi r18, 0
	mov r3, r18					;4th digit
less_than_10K_loop:
	push r17					;save inputs
	push r16					;
	mov r19, r17					;prepare to compare
	mov r18, r16					;
	ldi r17, 0x03					;compare with 1K
	ldi r16, 0xe8					;
	rcall less_than
	pop r16						;restore inputs
	pop r17
	brts less_than_1K				;determine if it's less than 1K
	ldi r18, 0xe8					;prepare to substract lower bits of 1K
	sub r16, r18					;execute substraction
	ldi r18, 0x03					;prepare to substract higher bits of 1K
	sbc r17, r18					;execute it with carry from lower bits
	inc r3						;increment 4th digit 
	rjmp less_than_10K_loop				;continue doing substration

less_than_1K:
	ldi r18, 0
	mov r2, r18					;3th digit
less_than_1K_loop:
	push r17					;save inputs
	push r16					;
	mov r19, r17					;prepare to compare
	mov r18, r16					;
	ldi r17, 0x00					;compare with 100
	ldi r16, 0x64					;
	rcall less_than
	pop r16						;restore inputs
	pop r17
	brts less_than_100				;determine if it's less than 100
	ldi r18, 0x64					;prepare to substract lower bits of 100
	sub r16, r18					;execute substraction
	ldi r18, 0x00					;prepare to substract higher bits of 100
	sbc r17, r18					;execute it with carry from lower bits
	inc r2						;increment 3th digit 
	rjmp less_than_1K_loop				;continue doing substration

less_than_100:
	ldi r18, 0
	mov r1, r18					;2th digit
less_than_100_loop:
	push r17					;save inputs
	push r16					;
	mov r19, r17					;prepare to compare
	mov r18, r16					;
	ldi r17, 0x00					;compare with 100
	ldi r16, 0x0a					;
	rcall less_than
	pop r16						;restore inputs
	pop r17
	brts less_than_10				;determine if it's less than 10
	ldi r18, 0x0a					;prepare to substract lower bits of 10
	sub r16, r18					;execute substraction
	inc r1						;increment 2nd digit 
	rjmp less_than_100_loop				;continue doing substration

less_than_10:
	mov r0, r16					;last digit
	ret


;*******************
;NAME:      less_than
;FUNCTION:  compare r19:r18 with r17:r16. determine if r19:r18 is
;           less than r17:r16. T flag will indicate the result: 
;           1 means it's true that r19:r18 is less than r17:r16
;           0 means otherwise
;RETURNS:   T-flag
;MODIFIES:  nothing
;CALLS:     nothing
;CALLED BY: unpack_hex_val_to_bcd
;*****************************************************************
less_than:
	cp r19, r17						;check if less than
	brlo less_than_true					;yep, 
	cp r19, r17						;check if the same
	brne less_than_false					;no, so it's greater than
	cp r18, r16						;check if lower less than
	brlo less_than_true					;yep, return false otherwise
less_than_false:
	clt
	ret
less_than_true:
	set
	ret

;*******************
;NAME:      wait_for_start_edge
;FUNCTION:  wait until 0->1 edge happens
;ASSUME:    PA7 is configure as input and a wave is fed into the
;           PA7. if constant is the input. this will be a infinite
;           loop until wave is fed.
;RETURNS:   nothing
;MODIFIES:  nothing
;CALLS:     nothing
;*****************************************************************
wait_for_start_edge:
wait_for_low:
	sbic PORTA, 7				;wait for the 0
	rjmp wait_for_low
wait_for_high:			
	sbis PORTA, 7				;now wait for 1. it will indicate 0->1
	rjmp wait_for_high
	ret					;done first rising edge just occured

;*******************
;NAME:      load_msg
;FUNCTION:  Loads a predefined string msg into a specified diplay
;           buffer.
;ASSUMES:   Z = offset of message to be loaded. Msg format is 
;           defined below.
;RETURNS:   nothing.
;MODIFIES:  r16, Y, Z
;CALLS:     nothing
;CALLED BY:  
;********************************************************************
; Message structure:
;   label:  .db <buff num>, <text string/message>, <end of string>
;
; Message examples (also see Messages at the end of this file/module):
;   msg_1: .db 1,"First Message ", 0   ; loads msg into buff 1, eom=0
;   msg_2: .db 1,"Another message ", 0 ; loads msg into buff 1, eom=0
;
; Notes: 
;   a) The 1st number indicates which buffer to load (either 1, 2, or 3).
;   b) The last number (zero) is an 'end of string' indicator.
;   c) Y = ptr to disp_buffer
;      Z = ptr to message (passed to subroutine)
;********************************************************************
load_msg:
     ldi YH, high (dsp_buff_1) ; Load YH and YL as a pointer to 1st
     ldi YL, low (dsp_buff_1)  ; byte of dsp_buff_1 (Note - assuming 
                               ; (dsp_buff_1 for now).
     lpm R16, Z+               ; get dsply buff number (1st byte of msg).
     cpi r16, 1                ; if equal to '1', ptr already setup.
     breq get_msg_byte         ; jump and start message load.
     adiw YH:YL, 16            ; else set ptr to dsp buff 2.
     cpi r16, 2                ; if equal to '2', ptr now setup.
     breq get_msg_byte         ; jump and start message load.
     adiw YH:YL, 16            ; else set ptr to dsp buff 2.
        
get_msg_byte:
     lpm R16, Z+               ; get next byte of msg and see if '0'.        
     cpi R16, 0                ; if equal to '0', end of message reached.
     breq msg_loaded           ; jump and stop message loading operation.
     st Y+, R16                ; else, store next byte of msg in buffer.
     rjmp get_msg_byte         ; jump back and continue...
msg_loaded:
     ret


;**********************************************************************
;************* M A I N   A P P L I C A T I O N   C O D E  *************
;**********************************************************************

reset:
	ldi r16, low(RAMEND)		; init stack/pointer
    out SPL, r16			;
    ldi r16, high(RAMEND)		;
    out SPH, r16

    ldi r16, 0xff			; set portB = output.
    out DDRB, r16			; 
    sbi PORTB, 4			; set /SS of DOG LCD = 1 (Deselected)

	cbi DDRA, 7			;set the input for wave
	sbi DDRA, 6			;gate start and stop indicator
	cbi PORTA, 6			;gate initially 0

	rcall init_lcd_dog		;init display, using SPI serial interface


main_loop:
	rcall wait_for_start_edge			;wait for start point for counting(rising edge)
	sbi PORTA, 6					;start the counting.
	ldi r25, 0x80					;represents the previous signal(high initially)
	ldi r19, 0xb0					;outer loop counter
	ldi r18, 0x01					;			
	ldi r16, 0x00					;prepare to setup edges counter
	mov r9, r16					;0 initially
	mov r8, r16					;
count_edges:
	in r16, PINA					;read in the input
	andi r16, 0x80					;only PA7 is relevant
	cp r16, r25					;test if there is a signal change
	breq dec_and_tweak				;no edge detected, dec
	cpi r25, 0x00					;see if change is from 0 -> 1
	brne change_prev				;no, modify previous value
	ldi r16, 1					;increment r9,r8 by 1
	add r8, r16
	ldi r16, 0
	adc r9, r16
change_prev:
	in r25, PINA					;current value
	andi r25, 0x80					;change the previous value		
dec_and_tweak:
	dec r18						;outer loop counting
	brne skip_dec_r19				;check if need to dec higher bits
	dec r19						;
skip_dec_r19:
	cpi r19, 0x00					;check if outer loop has ended
	breq display_result				;loop has ended, display result
	rcall tweak
	rjmp count_edges

;modify the message being display, save it into the buffer
;then display it.
display_result:
	cbi PORTA, 6					;counting finished, 1s passed. 
	mov r16, r8					;prepare to unpack hex value
	mov	r17, r9					;
	rcall unpack_hex_val_to_bcd			;unpack to r3:r2:r1:r0
	ldi r16, 30
	add r3, r16					;convert it to ascii
	add r2, r16					;
	add r1, r16					;
	add r0, r16					;
	ldi ZH, high(freq_message*2)			;get the pointer to the msg
	ldi ZL, low(freq_message*2)			;
	adiw ZH:ZL, 9					;get index of first number
	st Z+, r3					;store the 4th digit
	st Z+, r2					;store the 3th digit
	st Z+, r1					;store the 2nd digit
	st Z, r0					;store the 1st digit
	
	;message into dbuff1:
	ldi  ZH, high(freq_message*2)			;prepare the pointer
	ldi  ZL, low(freq_message*2)   
	rcall load_msg					;load message into buffer(s).
	rcall update_lcd_dog				;refresh the display
	jmp main_loop					;finish, go back to measure again



;*************************************************************************
;*** display string.
;*************************************************************************

freq_message:  .db 1, " Freq = 0000 Hz ", 0  ; string to display frequency
line2_message: .db 2, "                ", 0  ; not used
line3_message: .db 3, "                ", 0  ; not used

	

