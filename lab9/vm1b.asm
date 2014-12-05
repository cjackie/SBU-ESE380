/*
 * vm1b.asm
 *
 *  Created: 11/4/2014 9:32:55 PM
 *   Author: chaojie wang
 */ 

.nolist
.include "m16def.inc"
.list

.org 0x000
	jmp reset
.org 0x002
	jmp ext_int0
.org 0x00C
	jmp tim1_compa
.org 0x01C
	jmp adc_int

.nolist
;====================================
.include "lcd_dog_asm_driver_m16A.inc"  ; LCD DOG init/update procedures.
;====================================
.list


;*************************************************************************
;*** variables for the program
;*************************************************************************
.DSEG
state:			.byte 1			;state
result_val:		.byte 1			;variable for display value
mode:			.byte 1			;mode. 1 is running, 0 is hold
.CSEG
;*********************************************************


;************************************************************************
;const strings
;********************************************
adc_msg:		.db 1, "    -.-- VDC    ", 0		
line2_msg:		.db 2, "----------------", 0  
line3_run_msg:	.db 3, "Run         VM1b", 0
line3_hold_msg:	.db 3, "Hold        VM1a", 0
error_msg:		.db 1, "    error       ", 0
;********************************************


reset:
	ldi r16, low(RAMEND)			; init stack/pointer
    out SPL, r16					;
    ldi r16, high(RAMEND)			;
    out SPH, r16

	ldi r16, 0xff					; set portB = output.
    out DDRB, r16					; 
    sbi portB, 4					; set /SS of DOG LCD = 1 (Deselected)
	rcall init_lcd_dog				;init display, using SPI serial interface

	ldi r17, 0x01					;set up 0.1 second scheduler
	ldi r16, 0x7C					;
	rcall init_time_scheduler			;

	cbi DDRA, 4					;set up PA4 as analog input
	rcall init_adc					;initial adc converter

	ldi r16, 0x00					;prepare to config btns
	out DDRD, r16					;btns are input
	ldi r16, 0xf0					;prepare to enable pull ups
	out PORTD, r16					;enable pull ups for btn(no interrupt one tho)
	rcall init_ext_int0				;enable external interrupt

	ldi r25, 0x00					;default state 00(idle)
	sts state, r25					;variable for keeping the state
	sts result_val, r25				;0 is default for resulting value
	ldi r25, 0x01					;mode, default is 1(run)
	sts mode, r25					;variable for mode
	rcall init_queue				;clear the queue
	sei						;enable grobal interrupt
	rjmp main					;start the program

/***********************
 * State driven programming approach, @state is the state variable:
 * 00: nothing, idle
 * 01: display
 * 02: timeout, start a conversion if mode is run
 * 03: button push. check if need to toggle the mode
 * 04: conversion is finish. convert the data and update the value
 ***************/
state_table:
	jmp idle
	jmp display
	jmp start_adc
	jmp btn_push
	jmp conversion_done


main:
	lds r25, state					;get state
	cpi r25, 0x05					;check if it's a valid state
	brsh invalid_state				;some error, display it

	mov r16, r25					;prepare to multiply it by 2
	add r16, r25					;mul it by 2
	ldi ZH, high(state_table)			;prepare the table
	ldi ZL, low(state_table)			;
	add ZL, r16					;get the corresponding state
	ldi r16, 0					;
	adc ZH, r16					;
	icall						;execute code for that state
	rjmp main					;end of main loop


invalid_state:
	ldi ZL, low(adc_msg*2)				;load const string poiter
	ldi ZH, high(adc_msg*2)				;
	rcall load_msg					;store msg to buffer
	rcall update_lcd_dog				;refresh the screen
	rjmp invalid_state
	



;******************************
;state subroutines
;*********************************************************

;state code: 00. 
;check if any task in the queue
;add them to be executed accordingly
idle:
	rcall get_queue
	brts task_available
	ldi r16, 0x01					;if no task. go display
	sts state, r16
	clt
	ret
task_available:
	sts state, r16					;update state
	clt
	ret

;state: 01.
;display according to the mode. 
;0 is hold mode, 1 is running mode
display:
	lds r16, mode					;get the mode
	cpi r16, 0x00					;check the mode
	breq display_hold				;branch if it's hold mode
	;run mode
	ldi ZL, low(line3_run_msg*2)			;load const string poiter
	ldi ZH, high(line3_run_msg*2)			;
	rcall load_msg					;store msg to buffer
	rjmp display_cont
display_hold:
	;hold mode
	ldi ZL, low(line3_hold_msg*2)			;load const string poiter
	ldi ZH, high(line3_hold_msg*2)			;
	rcall load_msg					;store msg to buffer
display_cont:				
	ldi ZL, low(adc_msg*2)				;load const string poiter
	ldi ZH, high(adc_msg*2)				;
	rcall load_msg					;store msg to buffer
	ldi ZL, low(line2_msg*2)			;load const string poiter
	ldi ZH, high(line2_msg*2)			;
	rcall load_msg					;store msg to buffer
	lds r16, result_val				;
	ldi r17, 0x00					;prepare to unpack hex
	rcall unpack_hex_val_to_bcd			;unpack it
	ldi r16, 0x30					;
	add r2, r16					;convert to ascci
	add r1, r16					;
	add r0, r16					;
	ldi ZL, low(dsp_buff_1)				;get pointer to buffer
	ldi ZH, high(dsp_buff_1)			;
	adiw Z, 4					;advance the cursor
	st Z+, r2					;
	adiw Z, 1					;skip the period
	st Z+, r1					;store rest
	st Z+, r0					;
	rcall update_lcd_dog				;refresh the display
	ldi r25, 0x00					;
	sts state, r25					;go to state 00
	ret	
	

;state: 02
;check the mode to see if need to start a adc conversion
start_adc:
	lds r16, mode					;get the mode
	cpi r16, 0x00					;check if it's hold mode
	breq start_adc_ret				;yes. do nothing
	in r16, ADCSRA					;run mode.
	ori r16, (1<<ADSC)				;prepare to start conversion
	out ADCSRA, r16					;start it
start_adc_ret:
	ldi r16, 0x00					;
	sts state, r16					;go back to idle state(00)
	ret


;state: 03
;button push. go check if it's go btn. toggle it if so
btn_push:
	ldi r16, 10					;prepare to delay 10ms
	rcall delay_by_ms				;10ms to filter
	sbic PINC, 7					;check if go btn is pressed
	rjmp btn_push_ret				;not pressed or noise	
	lds r16, mode					;get the mode
	ldi r17, 0x01					;prepare to toggle it
	eor r16, r17					;toggle
	sts mode, r16					;store the mode
btn_push_ret:
	ldi r16, 0x00					;
	sts state, r16					;back to idle state
	ret


;state: 04
;conversion finished, get the data and update the value
conversion_done:
	in r16, ADCL
	in r16, ADCH					;only high byte will be used
	ldi r17, 0xff					;prepare to do calculate
	mul r16, r17					;	
	ldi r19, 0x03					;1024 as divisor
	ldi r18, 0xff					;
	mov r17, r1					;get dividend
	mov r18, r0					;
	rcall div16u					;divide them
	ldi r18, 4					;
	mul r16, r18					;only need lower byte
	mov r16, r0					;r16 is the result.
	sts result_val, r16				;store the result val
	ldi r25, 0x00					;transit to state 00 to display the result
	sts state, r25					;00's default will display the result
	ret
	
	



;******************************
;end of state subroutines
;*********************************************************





;******************************
;interrupt response subroutines
;*********************************************************

;button push
ext_int0:
	push r16					;save r16
	in r16, SREG					;save state of sreg	
	push r16
	push r17
	push r18
	push ZL
	push ZH

	ldi r16, 0x03					;prepare to schedule the btn_push event
	rcall add_queue					;schedule it, disregard the error
	
	pop ZH						;restore data
	pop ZL
	pop r18
	pop r17
	pop r16
	out SREG, r16
	pop r16
	reti

	
;time out, schedule a adc conversion
tim1_compa:
	push r16					;save r16
	in r16, SREG					;save state of sreg	
	push r16
	push r17
	push r18
	push ZL
	push ZH

	ldi r16, 0					;prepare to clear counter
	out TCNT1H, r16					;clear the counter
	out TCNT1L, r16					;
	ldi r16, 0x02					;schedule the start conversion task 
	rcall add_queue					;add it, disregard errors

	pop ZH						;restore data
	pop ZL
	pop r18
	pop r17
	pop r16
	out SREG, r16
	pop r16
	reti

;adc is finish. schedule update value task(04)
adc_int:
	push r16					;save r16
	in r16, SREG					;save state of sreg	
	push r16
	push r17
	push r18
	push ZL
	push ZH

	ldi r16, 0x04					;prepare to schedule update value task
	rcall add_queue					;schedule it, disregard the error

	pop ZH						;restore data
	pop ZL
	pop r18
	pop r17
	pop r16
	out SREG, r16
	pop r16
	reti

;*************************************
;end of interrupt response subroutines
;*****************************************************************







;***********************************
;interrupt configuration subroutines
;******************************************************


init_ext_int0:
	ldi r16, (1<<ISC01)|(1<<ISC00)			;respond rising edge of PD2 
	out MCUCR, r16					;
	ldi r16, (1<<INT0)				;enable interrupt on PD2
	out GICR, r16					;
	ret

init_adc:
	ldi r16, (1<<REFS1)|(1<<REFS0)			;use internal 2.56V ref
	ori r16, 0x04					;select ADC4(PA4) as analog input
	ori r16, (1<<ADLAR)				;left adjust
	out ADMUX, r16					;set the config
	ldi r16, (1<<ADEN)|(1<<ADIE)			;enable conversion and interrupt
	out ADCSRA, r16					;set the config
	ret

init_time_scheduler:
	push r16					;save the input
	ldi r16, 0x00					;prepare to stop the counter
	out TCCR1B, r16					;stop the counter
	ldi r16, 0					;prepare to clear counter
	out TCNT1H, r16					;clear the counter
	out TCNT1L, r16					;
	pop r16						;restore input
	out OCR1AH, r17					;set the value being compared
	out OCR1AL, r16					;
	ldi r16, (1<<OCIE1A)				;prepare to enable cmpa interrupt
	out TIMSK, r16					;enable comparator interrupt
	ldi r16, (1<<CS12)				;prepare to enable prescale
	out TCCR1B, r16					;set prescale and ready to count
	ret


;*****************************************
;end of interrupt configuration subroutine
;*********************************************************************




;***************Queue data structure***************************
;call init_queue before use. it will have queue with size of 16
;@get_queue, return front variable, t=0 means empty queue, t=1
;	means it's good. the value is in r16
;@add_queue, add a value to a queue, the variable is r16,
;	t=0 means not good, t=1 means add successfully
;***************************************************************

;init the queue
init_queue:
	ldi r16, 0						;just set index of queue to 0
	ldi ZH, high(task_queue_index)	
	ldi ZL, low(task_queue_index)	
	st Z, r16			
	ldi r16, 0						;set tail of the queue 0
	ldi ZH, high(task_queue_tail)	
	ldi ZL, low(task_queue_tail)	
	st Z, r16						;
	ldi r16, 0						;set size of the queue 0
	ldi ZH, high(task_queue_size)
	ldi ZL, low(task_queue_size)
	st Z, r16						;
	ret

;return first index of the queue
;if queue is empty, t is clear, else it's set
;return value is in r16
;use: r16, r17 and r18, Z
get_queue:
	lds r16, task_queue_index		;get current index
	lds r17, task_queue_size		;get current size of the que
	cpi r17, 0				;check the size
	breq empty_queue			;it's empty return t=0
	ldi ZH, high(task_queue)		;get queue
	ldi ZL, low(task_queue)			;
	mov r18, r16				;advance the cursor to the front
	add ZL, r18			
	ldi r18, 0			
	adc ZH, r18			
	ld r18, Z				;get the front value
	inc r16					;prepare to advance the index
	cpi r16, 16				;if size is out of bound,
	brne in_bound
	ldi r16, 0
in_bound:
	sts task_queue_index, r16		;update current index
	lds r17, task_queue_size		;update current size
	dec r17					;decrement by 1
	sts task_queue_size, r17
	mov r16, r18				;return the value in the queue
	set
	ret

empty_queue:
	clt
	ret


;add a value to a queue, the variable is r16,
;	t=0 means not good, t=1 means add successfully
;use: r16, r17, r18, and Z pointer T flag
add_queue:
	push r16
	lds r16, task_queue_tail		;get current tail
	lds r17, task_queue_size		;get current size of the que
	cpi r17, 16				;check the size
	breq full_queue				;it's full return t=0
	ldi ZH, high(task_queue)		;get queue
	ldi ZL, low(task_queue)			;
	mov r18, r16				;advance the cursor to the tail
	add ZL, r18				;						
	ldi r18, 0				;
	adc ZH, r18				;this is the location to store(later use)
	inc r16					;prepare to advance the tail
	cpi r16, 16				;if size is out of bound,
	brne tail_in_bound
	ldi r16, 0
tail_in_bound:
	sts task_queue_tail, r16		;update current index
	lds r17, task_queue_size		;prepare to update the size
	inc r17					;increment by 1
	sts task_queue_size, r17		;
	pop r16					;the value to be store
	st Z, r16				;store it
	set
	ret
	
full_queue:
	pop r16
	clt
	ret
	

.DSEG
task_queue_index:	.byte 1
task_queue_tail:	.byte 1
task_queue_size:	.byte 1
task_queue:		.byte 16

.CSEG
;***************************
;end of queue data structure
;**************************************************************




;*************************************************
;delay_by_ms: a self-contained delay subroutine to 
;	generate N ms delay (in 1MHz clock 
;	frequency). N is the time factor for the user
;	specified frequency(the factor is passed by
;	r16 and serves as the count for outer loop).
;	The inner loop is 248 for each count down of	
;	r16.
; 
; input: r16 
; return: nothing
;
; calls: none
; programm memory word: 7
;
; assum: r16>0
; resiger altered: r16, r17, ZREG, Z flag
;*******************************************************
delay_by_ms:
	ldi r17, 248				;the varibale for the inner loop
delay_by_ms_inner:
	nop							;total 4 cycles
	dec r17
	brne delay_by_ms_inner
	dec r16						;counting
	brne delay_by_ms			;if not done, go back and continue delay
	ret							;done



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
	push r17						;save inputs
	push r16						;
	mov r19, r17					;prepare to compare
	mov r18, r16					;
	ldi r17, 0x27					;compare with 10K
	ldi r16, 0x10					;
	rcall less_than					;call subroutine
	pop r16							;restore inputs
	pop r17
	brts less_than_10K				;determine if less than 10K
	ldi r18, 0x0f					;greater than 10K
	mov r3, r18						;make r3 a invalid bcd
	ret								;ended

less_than_10K:
	ldi r18, 0
	mov r3, r18						;4th digit
less_than_10K_loop:
	push r17						;save inputs
	push r16						;
	mov r19, r17					;prepare to compare
	mov r18, r16					;
	ldi r17, 0x03					;compare with 1K
	ldi r16, 0xe8					;
	rcall less_than
	pop r16							;restore inputs
	pop r17
	brts less_than_1K				;determine if it's less than 1K
	ldi r18, 0xe8					;prepare to substract lower bits of 1K
	sub r16, r18					;execute substraction
	ldi r18, 0x03					;prepare to substract higher bits of 1K
	sbc r17, r18					;execute it with carry from lower bits
	inc r3							;increment 4th digit 
	rjmp less_than_10K_loop			;continue doing substration

less_than_1K:
	ldi r18, 0
	mov r2, r18						;3th digit
less_than_1K_loop:
	push r17						;save inputs
	push r16						;
	mov r19, r17					;prepare to compare
	mov r18, r16					;
	ldi r17, 0x00					;compare with 100
	ldi r16, 0x64					;
	rcall less_than
	pop r16							;restore inputs
	pop r17
	brts less_than_100				;determine if it's less than 100
	ldi r18, 0x64					;prepare to substract lower bits of 100
	sub r16, r18					;execute substraction
	ldi r18, 0x00					;prepare to substract higher bits of 100
	sbc r17, r18					;execute it with carry from lower bits
	inc r2							;increment 3th digit 
	rjmp less_than_1K_loop			;continue doing substration

less_than_100:
	ldi r18, 0
	mov r1, r18						;2th digit
less_than_100_loop:
	push r17						;save inputs
	push r16						;
	mov r19, r17					;prepare to compare
	mov r18, r16					;
	ldi r17, 0x00					;compare with 100
	ldi r16, 0x0a					;
	rcall less_than
	pop r16							;restore inputs
	pop r17
	brts less_than_10				;determine if it's less than 10
	ldi r18, 0x0a					;prepare to substract lower bits of 10
	sub r16, r18					;execute substraction
	inc r1							;increment 2nd digit 
	rjmp less_than_100_loop			;continue doing substration

less_than_10:
	mov r0, r16						;last digit
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
	brlo less_than_true				;yep, 
	cp r19, r17						;check if the same
	brne less_than_false			;no, so it's greater than
	cp r18, r16						;check if lower less than
	brlo less_than_true				;yep, return false otherwise
less_than_false:
	clt
	ret
less_than_true:
	set
	ret


;*********************************************
;Division library from AVR
;*************************************************************************

;***************************************************************************
;*
;* "div16u" - 16/16 Bit Unsigned Division
;*
;* This subroutine divides the two 16-bit numbers 
;* "r17:r16" (dividend) and "r19:r18" (divisor). 
;* The result is placed in "r17:r16" and the remainder in
;* "r15:r14".
;*  
;* Number of words	:19
;* Number of cycles	:235/251 (Min/Max)
;* Low registers used	:2 (r14,r15)
;* High registers used  :5 (r16/r16,r17/r17,r18,r19,
;*			    r20)
;*
;***************************************************************************


;***** Code

div16u:	clr	r14	;clear remainder Low byte
	sub	r15,r15;clear remainder High byte and carry
	ldi	r20,17	;init loop counter
d16u_1:	rol	r16		;shift left dividend
	rol	r17
	dec	r20		;decrement counter
	brne	d16u_2		;if done
	ret			;    return
d16u_2:	rol	r14	;shift dividend into remainder
	rol	r15
	sub	r14,r18	;remainder = remainder - divisor
	sbc	r15,r19	;
	brcc	d16u_3		;if result negative
	add	r14,r18	;    restore remainder
	adc	r15,r19
	clc			;    clear carry to be shifted into result
	rjmp	d16u_1		;else
d16u_3:	sec			;    set carry to be shifted into result
	rjmp	d16u_1



;***************************************************************************
;*
;* "mpy16u" - 16x16 Bit Unsigned Multiplication
;*
;* This subroutine multiplies the two 16-bit register variables 
;* r19:r18 and r17:r16.
;* The result is placed in r21:r20:r19:r18.
;*  
;* Number of words	:14 + return
;* Number of cycles	:153 + return
;* Low registers used	:None
;* High registers used  :7 (r18,r19,r16/r18,r17/r19,r20,
;*                          r21,r22)	
;*
;***************************************************************************


;***** Code

mpy16u:	clr	r21		;clear 2 highest bytes of result
	clr	r20
	ldi	r22,16	;init loop counter
	lsr	r19
	ror	r18

m16u_1:	brcc	noad8		;if bit 0 of multiplier set
	add	r20,r16	;add multiplicand Low to byte 2 of res
	adc	r21,r17	;add multiplicand high to byte 3 of res
noad8:	ror	r21		;shift right result byte 3
	ror	r20		;rotate right result byte 2
	ror	r19		;rotate result byte 1 and multiplier High
	ror	r18		;rotate result byte 0 and multiplier Low
	dec	r22		;decrement loop counter
	brne	m16u_1		;if not done, loop more
	ret

;********************************************
;End of division library from AVR
;************************************************************
					
	
