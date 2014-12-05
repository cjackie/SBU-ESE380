/*
 * lab8_freq_mea_int.asm: a simple program to measure
 *	the frequency of the input waveform in 1sec using the 
 * 	interrupt driven timer/counter.
 *
 *  Created: 10/30/2014 8:01:09 PM
 *  Description: a program to measure the 
 *	frequency of the unknown square wave on PortA0.
 *	Timer 1 interrupt is deployed to get accurate 
 *  1 second. The frequency will be display on the 
 *	LCD display after 1 second. The frequency is 
 *	acceptable in range of 10Hz to 10KHz. Otherwise,
 *	"out of range" will be displayed.
 *
 *  Inputs: PA0(sqaure wave)
 *  Outputs: PORTB(LCD display)
 *			PA6: osciliscope period gating
 *
 *  Assume: nothing
 *  Alters: r3,r2,r1,r0,r16,r17,r18,r19,r21,r22,r23,
 *			Z,Y
 *	Subroutine: tim1_compa::Interrupt subroutine
 *				start_tc1:	timer counter initialization
 *				display_result
 *				unpack_hex_val_to_bcd
 *				less_than
 *				load_msg
 *	
 *	Lab 08
 *	Lab section 04
 *	Lab bench 01			
 *

 *  Author: Chaojie Wang, Zhaoqi Li.
 *	Version: 1.0.0
 */ 

.nolist
.include "m16def.inc"
.list

.org 0x000
	jmp reset
.org 0x00C
	jmp tim1_compa

;;---------------------------- INTERRUPT SUBROUTINES ----------------------------
;*******************
;NAME:      tim1_compa
;FUNCTION:  timer 1 compare A interrupt subroutine. It will stop the timer
;			and disable compare A interrupt. Then return T with 1 to signal
;			timeout.
;ASSUME:    nothing
;RETURNS:   T-flag with 1 value
;MODIFIES:  TCCR1B, TIMSK
;CALLS:     nothing
;*****************************************************************
tim1_compa:
	push r16					;save r16
	in r16, SREG					;save state of sreg	
	push r16
			
	ldi r16, 0					;prepare to stop the counter			
	out TCCR1B, r16					;stop the counter
	ldi r16, (0<<OCIE1A)				;prepare to disable compare interrupt
	out TIMSK, r16					;disable comparator interrupt

	pop r16						;restore data
	out SREG, r16					;
	pop r16
	set						;generate a hand shake
	reti

;---------------------------- SUBROUTINES ----------------------------

;====================================
.include "lcd_dog_asm_driver_m16A.inc"  ; LCD DOG init/update procedures.
;====================================

;*******************
;NAME:      start_tc1
;FUNCTION:  start the timer 1 to count 1 second. compare A interrupt 
;			will be generated when 1 second elapse.
;ASSUME:    nothing
;RETURNS:   nothing
;MODIFIES:  r16, r17, TCCR1B, TCNT1, OCR1A, TIMSK
;CALLS:     nothing
;*****************************************************************
start_tc1:								
	ldi r16, 0x00					;prepare to stop the counter
	out TCCR1B, r16					;stop the counter
	ldi r16, 0					;prepare to clear counter
	out TCNT1H, r16					;clear the counter
	out TCNT1L, r16					;
	ldi r16, 0x42					;prepare to set comparator
	ldi r17, 0x0f					;to get 1s
	out OCR1AH, r17					;set the value being compared
	out OCR1AL, r16					;
	ldi r16, (1<<OCIE1A)				;prepare to enable cmpa interrupt
	out TIMSK, r16					;enable comparator interrupt
	ldi r16, (1<<CS12)				;prepare to enable prescale
	out TCCR1B, r16					;set prescale and ready to count
	ret

;*******************
;NAME:      display_result
;FUNCTION:  takes BCD value in r3:r2:r1:r0 and display it on the LCD 
;			display. If r3 is 0x0f, it means the result is out of range
;			so just display out of range string
;ASSUME:    nothing
;RETURNS:   nothing
;MODIFIES:  r20,r19,r18,r17,r16,r3,r2,r1,r0,Z,Y
;CALLS:     load_msg, update_lcd_dog
;*****************************************************************
display_result:
	ldi r16, 0x0f				;prepare data to be compared with
	cp r3, r16				;check if it's out of range
	breq display_out_of_range		;out of range
	ldi ZL, low(freq_message*2)		;load const string poiter
	ldi ZH, high(freq_message*2)		;
	rcall load_msg				;store msg to buffer
	ldi ZL, low(dsp_buff_1)			;get pointer of the buffer
	ldi ZH, high(dsp_buff_1)		;
	adiw ZH:ZL, 9				;get index of first number
	ldi r16, 3				;
	add r3, r16				;convert them to ascii
	add r2, r16				;
	add r1, r16				;
	add r0, r16				;
	st Z+, r3				;store the 4th digit
	st Z+, r2				;store the 3th digit
	st Z+, r1				;store the 2nd digit
	st Z, r0				;store the 1st digit
	ldi ZL, low(line3_message*2)		;load third line string pointer
	ldi ZH, high(line3_message*2)		;
	rcall load_msg				;store msg to buffer
	rcall update_lcd_dog			;refresh the lcd display	
	ret
display_out_of_range:
	ldi ZL, low(out_of_range_msg*2)		;load const string poiter
	ldi ZH, high(out_of_range_msg*2)	;
	rcall load_msg				;store msg to buffer
	ldi ZL, low(line3_message*2)		;load third line string pointer
	ldi ZH, high(line3_message*2)		;
	rcall load_msg				;store msg to buffer
	rcall update_lcd_dog			;refresh the lcd display	
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
	ret								;ended

less_than_10K:
	ldi r18, 0
	mov r3, r18					;4th digit
less_than_10K_loop:
	push r17					;save inputs
	push r16						;
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
	cp r19, r17					;check if less than
	brlo less_than_true				;yep, 
	cp r19, r17					;check if the same
	brne less_than_false				;no, so it's greater than
	cp r18, r16					;check if lower less than
	brlo less_than_true				;yep, return false otherwise
less_than_false:
	clt
	ret
less_than_true:
	set
	ret

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


;*************************************************************************
;*** display string.
;*************************************************************************
freq_message:  .db 1, " Freq = 0000 Hz ", 0  ; string to display frequency
out_of_range_msg: .db 1, "  out of range  ", 0  ; out of range string
line2_message: .db 2, "                ", 0  ; not used
line3_message: .db 3, "  Gate = 1 se   ", 0  ; not used
;*****************************************************************

;**********************************************************************
;************* M A I N   A P P L I C A T I O N   C O D E  *************
;**********************************************************************
reset:
	ldi r16, low(RAMEND)			; init stack/pointer
    out SPL, r16				;
    ldi r16, high(RAMEND)			;
    out SPH, r16

	rcall init_lcd_dog			;init display, using SPI serial interface
	cbi DDRA, 0				;set PortA0 as input of the wave
	rcall start_tc1				;start timer
	sei					;enable global interrupt

main:
	ldi r23, 0x00					;previous state variable, set it low
	ldi r21, 0x00					;variable to keep track of counts(1 word)
	ldi r22, 0x00					;
counting_loop:
	in r16, PINA					;prepare to check wave state
	andi r16, 0x01					;mask out all bits except first one
	cp r23, r16						;see if there is an edge
	brne edge_detected				;yes. a edge is detected
check_t:
	brts timer_done					;if t set, timeout,counting finished
	rjmp counting_loop


edge_detected:
	;there is a edge, check if it's 0->1
	sbrs r23, 0					;check previous is 1 or not
	rjmp edge_0to1					;previous is 0, so it's 0 to 1 edge
	rjmp edge_1to0					;previous is 1, so it's 1 to 0 edge
edge_0to1:
	inc r21						;increment counter
	ldi r16, 0					;
	adc r22, r16					;
	ldi r23, 0x01					;change previous state
	rjmp check_t					;go back
edge_1to0:
	ldi r23, 0x00					;change previous state
	rjmp check_t					;go back


timer_done:
	;counting is finshed. clean up and display result
	mov r17, r22					;prepare to unpack hex
	mov r16, r21					;
	rcall unpack_hex_val_to_bcd			;unpack	
	rcall display_result				;display the result 
	clt						;clear t flag.
	rcall start_tc1					;restart the timer
	rjmp main					;counting again

