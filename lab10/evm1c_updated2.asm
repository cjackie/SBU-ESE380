/*
 * lab11_avm4.asm
 *
 *  Created: 11/15/2014 4:02:42 PM
 *   Author: chaojie wang
 */ 


.nolist
.include "m16def.inc"
.list


 .org 0x000
	jmp reset


.nolist
;====================================
.include "lcd_dog_asm_driver_m16A.inc"  ; LCD DOG init/update procedures.
;====================================
.list



;*************************************************************************
;*** variables for the program
;*************************************************************************
.DSEG
state:				.byte 1			;state
mode:				.byte 1			;for this problem only 1 mode: capture mode
capture_status:		.byte 1			;wait or captured
result_val:			.byte 6			;each digit
raw_result_h:		.byte 1
raw_result_l:		.byte 1
.CSEG
;*********************************************************


;************************************************************************
;*** const strings
;***************************************************
adc_msg:				.db 1, "  -.----- VDC   ", 0		
line2_msg:				.db 2, "----------------", 0  
line3_capting_msg:		.db 3, "Capturing  eVM1c", 0
line3_capted_msg:		.db 3, "Captured   eVM1c", 0
error_msg:				.db 1, "    error       ", 0
;***************************************************


reset:
	ldi r16, low(RAMEND)			; init stack/pointer
    out SPL, r16					;
    ldi r16, high(RAMEND)			;
    out SPH, r16

	ldi r16, 0xff					;set portB = output.
    out DDRB, r16					; 
    sbi portB, 4					;set /SS of DOG LCD = 1 (Deselected)
	sbi portB, 1					;deselect the external adc
	rcall init_lcd_dog				;init display, using SPI serial interface,(fck/4)

	ldi r16, 0x00					;init state
	sts state, r16					;idle state
	ldi r16, 0x00					;default mode is capture mode
	sts mode, r16					;

	sbi DDRC, 0						;set up buzzer
	cbi portC, 0					;no sound by default
	
	rjmp main						;start the program



/****************************************************************
 * State driven programming approach, r25 is the state variable:
 * 00: nothing, idle
 * 01: in capture mode. check the capture status
 * 02: capturing.
 * 03: it's captured. hold the previous value
 ***************/
state_table:
	jmp idle
	jmp check_capt_status
	jmp capturing_state
	jmp captured_state

main:
	lds r25, state					;get state
	cpi r25, 0x05					;check if it's a valid state
	brsh invalid_state				;some error, display it

	mov r16, r25					;prepare to multiply it by 2
	add r16, r25					;mul it by 2
	ldi ZH, high(state_table)		;prepare the table
	ldi ZL, low(state_table)		;
	add ZL, r16						;get the corresponding state
	ldi r16, 0						;
	adc ZH, r16						;
	icall							;execute code for that state
	rjmp main						;end of main loop


invalid_state:
	ldi ZL, low(error_msg*2)		;load const string poiter
	ldi ZH, high(error_msg*2)		;
	rcall load_msg					;store msg to buffer
	rcall update_lcd_dog			;refresh the screen
	rjmp invalid_state





;******************************
;state subroutines
;*********************************************************
	
;*******************
;NAME:      idle(state 00)
;FUNCTION:  check the mode, transit accordingly.
;ASSUMES:   nothing
;RETURNS:   nothing.
;MODIFIES:  r16
;CALLS:     nothing
;CALLED BY: nothing 
;********************************************************************
idle:
	lds r16, mode					;check the mode
	cpi r16, 0x00					;
	breq idle_capture_mode			;is capture mode
	rjmp invalid_state				;unkown mode, error
idle_capture_mode:
	ldi r16, 0x01					;go to capture
	sts state, r16					;
	ret



;*******************
;NAME:      check_capt_status(state 01)
;FUNCTION:  check the capture_status. It's captured already, just 
;			transit to display the previous value. Otherwise, start
;			the measurement of the unkown voltage.
;ASSUMES:   nothing
;RETURNS:   nothing.
;MODIFIES:  r16.r17
;CALLS:     nothing
;CALLED BY: nothing 
;********************************************************************
check_capt_status:
	lds r16, capture_status			;check status of capture
	cpi r16, 0						;it's captured already?
	breq capt_status_hold
	;otherwise it's in running status
	ldi r16, 0x02
	sts state, r16
	ret
capt_status_hold:
	ldi r16, 0x03
	sts state, r16
	ret


;*******************
;NAME:      capturing_state(state 02)
;FUNCTION:  start to capture. check the voltage. if it start to increase
;			then delay and go ahead and mearsure it.
;ASSUMES:   nothing
;RETURNS:   nothing.
;MODIFIES:  r16.r17
;CALLS:     nothing
;CALLED BY: nothing 
;********************************************************************
capturing_state:
	rcall start_adc					;check the voltage
	mov r19, r17					;prepare to compare
	mov r18, r16					;to see if voltage has drop to near 0
	ldi r17, 0
	ldi r16, 10
	rcall less_than
	brtc capture_ready				;ready to capture
	;not ready 
	ldi r16, 0x00					;waiting
	sts state, r16					;
	ret								
capture_ready:
	ldi r16, 1						;time for voltage to be stable
	rcall delay_by_ms
	rcall start_adc					;check the voltage
	sts raw_result_l, r16			;update raw result
	sts raw_result_h, r17			;
	rcall calculate_val				;determine the value
	rcall display_capted			;display the result
	rcall make_beep					;make a beep sound to indicate it's finished
	ldi r16, 0x00
	sts capture_status, r16			;change the status. it's captured already
	ldi r16, 0x00					
	sts state, r16					;go back to idle
	ret
	
	



;*******************
;NAME:      captured_state(state 05)
;FUNCTION:  the voltage has been captured. check if it has been 
;			disconnected(voltage near 0). if yes, start a new 
;			capture by updating state status
;ASSUMES:   nothing
;RETURNS:   nothing.
;MODIFIES:  r16.r17
;CALLS:     nothing
;CALLED BY: nothing 
;********************************************************************	
captured_state:
	rcall start_adc					;read in raw_data of voltage
	mov r19, r17					;prepare to compare
	mov r18, r16					;to see if voltage has drop to near 0
	ldi r17, 0
	ldi r16, 10
	rcall less_than
	brts capted_state_hold_change	;yes, need to change the mode
	;not disconnected, just display previous value
	rcall display_capted			;display captured
	ldi r16, 0x00
	sts state, r16					;finished back to idle
	ret
capted_state_hold_change:
	rcall clr_result_val			;has disconnected, prepare to display 0 V
	rcall display_ready_capt		;display it's ready to capture
	ldi r16, 0x01
	sts capture_status, r16			;store capturing status
	ldi r16, 0x00
	sts state, r16					;start capturing
	ret
	














;****************************************
;helper subroutines for state subroutines
;**********************************************************


;*****************************
;NAME:      start_adc
;FUNCTION:  trigger the external adc to start conversion.
;			wait for it to finish then get the data
;ASSUMES:   external ADC is available, and the MCU is running
;			on 1MHz and 1/4 freq for SPI clock
;RETURNS:   r17:r16
;MODIFIES:  state, r17, r16, r18
;CALLS:     start_adc_wait
;CALLED BY: start_capture
;********************************************************************
start_adc:
	sbi portB, 4					;deselect the dog led
	cbi portB, 1					;select the external adc to begin conversion
	ldi r16, 1						;prepare to delay 1ms
	rcall delay_by_ms				;delay 1ms, minimum wake-up time is 2.5 us
	out SPDR, r16					;start transmition
	rcall start_adc_wait			;wait for transmition finished
	in r17, SPDR					;get the data, higher byte
	out SPDR, r16					;start transmition
	rcall start_adc_wait			;wait for transmition finished
	in r16, SPDR					;get the data, lower byte
	sbi portB, 1					;deselect the external adc(stop it)
	ldi r16, 1						;delay 1ms. (60ns minimum)
	rcall delay_by_ms				;
	andi r17, 0x0f					;mask out unused bits in high byte				
	ret

;************************
;NAME:      start_adc_wait
;FUNCTION:  wait for transmition to finish.
;ASSUMES:   SPDR will be read after end of this subroutine
;RETURNS:   nothing
;MODIFIES:  nothing
;CALLS:     nothing
;CALLED BY: start_adc
;********************************************************************
start_adc_wait:
	push r16
start_adc_wait_inner:
	in r16, SPSR					;get status
	sbrs r16, SPIF					;check 
	rjmp start_adc_wait_inner		;not finish, continue waiting
	pop r16
	ret								;finish, return


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



;**********************************
;NAME:      unpack_hex_val_to_bcd
;FUNCTION:  unpack value in r18, r17, r16 into BCD and store them on r5, r4, r3,
;           r2,r1 and r0. The order is from r5 to r0, where r4 is the 
;           most significant digit.
;ASSUME:    r18:r17:r16 is less than 1000K
;RETURNS:   r4, r3,r2,r1,r0
;MODIFIES:  r19,r18,r17,r16,r4,r3,r2,r1,r0
;CALLS:     less_than
;*************************************************************************
unpack_hex_val_to_bcd:
	ldi r19, 0						;init the sixth digit
	mov r5, r19						;0
unpack_hex_val_to_bcd_loop0:
	push r18						;store the input
	push r17						;
	push r16						;
	mov r22, r18					;prepare to compare
	mov r21, r17					;
	mov r20, r16					;
	ldi r18, 0x01					;compare with 100K
	ldi r17, 0x86					;
	ldi r16, 0xa0					;
	rcall less_than_3bytes			;
	pop r16							;restore input
	pop r17							;
	pop r18							;
	brts unpack_hex_val_to_bcd_r4	;less than 100K, extract next digit
	ldi r19, 0xa0					;prepare substraction
	sub r16, r19					;
	ldi r19, 0x86
	sbc r17, r19
	ldi r19, 0x01
	sbc r18, r19
	inc r5
	rjmp unpack_hex_val_to_bcd_loop0

unpack_hex_val_to_bcd_r4:
	ldi r19, 0
	mov r4, r19
unpack_hex_val_to_bcd_loop1:
	push r18						;store the input
	push r17						;
	push r16						;
	mov r22, r18					;prepare to compare
	mov r21, r17					;
	mov r20, r16					;
	ldi r18, 0x00
	ldi r17, 0x27
	ldi r16, 0x10
	rcall less_than_3bytes			;
	pop r16							;restore input
	pop r17							;
	pop r18							;
	brts unpack_hex_val_to_bcd_r3	;less than 10K, extract next digit
	ldi r19, 0x10
	sub r16, r19
	ldi r19, 0x27
	sbc r17, r19
	ldi r19, 0
	sbc r18, r19
	inc r4
	rjmp unpack_hex_val_to_bcd_loop1

unpack_hex_val_to_bcd_r3:
	ldi r19, 0
	mov r3, r19
unpack_hex_val_to_bcd_loop2:
	push r18						;store the input
	push r17						;
	push r16						;
	mov r22, r18					;prepare to compare
	mov r21, r17					;
	mov r20, r16					;
	ldi r18, 0x00
	ldi r17, 0x03
	ldi r16, 0xe8
	rcall less_than_3bytes			;
	pop r16							;restore input
	pop r17							;
	pop r18							;
	brts unpack_hex_val_to_bcd_r2	;less than 1K, extract next digit
	ldi r19, 0xe8
	sub r16, r19
	ldi r19, 0x03
	sbc r17, r19
	ldi r19, 0
	sbc r18, r19
	inc r3
	rjmp unpack_hex_val_to_bcd_loop2

unpack_hex_val_to_bcd_r2:
	ldi r19, 0
	mov r2, r19
unpack_hex_val_to_bcd_loop3:
	push r18						;store the input
	push r17						;
	push r16						;
	mov r22, r18					;prepare to compare
	mov r21, r17					;
	mov r20, r16					;
	ldi r18, 0x00
	ldi r17, 0x00
	ldi r16, 0x64
	rcall less_than_3bytes			;
	pop r16							;restore input
	pop r17							;
	pop r18							;
	brts unpack_hex_val_to_bcd_r1	;less than 100, extract next digit
	ldi r19, 0x64
	sub r16, r19
	ldi r19, 0
	sbc r17, r19
	ldi r19, 0
	sbc r18, r19
	inc r2
	rjmp unpack_hex_val_to_bcd_loop3

unpack_hex_val_to_bcd_r1:
	ldi r19, 0
	mov r1, r19
unpack_hex_val_to_bcd_loop4:
	push r18						;store the input
	push r17						;
	push r16						;
	mov r22, r18					;prepare to compare
	mov r21, r17					;
	mov r20, r16					;
	ldi r18, 0x00
	ldi r17, 0x00
	ldi r16, 0x0a
	rcall less_than_3bytes			;
	pop r16							;restore input
	pop r17							;
	pop r18							;
	brts unpack_hex_val_to_bcd_r0	;less than 10, extract next digit
	ldi r19, 0x0a
	sub r16, r19
	ldi r19, 0
	sbc r17, r19
	ldi r19, 0
	sbc r18, r19
	inc r1
	rjmp unpack_hex_val_to_bcd_loop4

unpack_hex_val_to_bcd_r0:
	mov r0, r16
	ret



;*******************
;NAME:      less_than_3bytes
;FUNCTION:  compare r22:r21:r20 with r18:r17:r16. 
;			determine if r22:r21:r20 is less than r18:r17:r16.
;			T flag will indicate the result: 
;           1 means it's true that r22:r21:r20 is less than
;			r18:r17:r16.
;           0 means otherwise
;RETURNS:   T-flag
;MODIFIES:  T-flag.
;CALLS:     nothing
;*******************************************************************
less_than_3bytes:
	sub r20, r16
	sbc r21, r17
	sbc r22, r18
	brmi less_than_3bytes_true
	clt
	ret
less_than_3bytes_true:
	set
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

;make a beef sound
make_beep:
	sbi portC, 0					;make a beep sound
	ldi r16, 10						;
	rcall delay_by_ms				;delay by 10ms(sound duration)
	cbi portC, 0					;
	ret


;clear the result_val for display
clr_result_val:
	ldi ZL, low(result_val)			;clear value in the result_val
	ldi ZH, high(result_val)
	ldi r16, 0
	st Z+, r16
	st Z+, r16
	st Z+, r16
	st Z+, r16
	st Z+, r16
	st Z, r16
	ret

;display ready to capture
display_ready_capt:
	ldi ZL, low(adc_msg*2)				;load const string poiter
	ldi ZH, high(adc_msg*2)				;
	rcall load_msg						;store msg to buffer
	ldi ZL, low(line2_msg*2)			;load const string poiter
	ldi ZH, high(line2_msg*2)			;
	rcall load_msg						;store msg to buffer
	ldi ZL, low(line3_capting_msg*2)	;load const string poiter
	ldi ZH, high(line3_capting_msg*2)	;
	rcall load_msg						;store msg to buffer
	rcall update_lcd_dog				;refresh the display
	rcall display_num
	ret

;display captured stuff
display_capted:
	ldi ZL, low(line2_msg*2)			;load const string poiter
	ldi ZH, high(line2_msg*2)			;
	rcall load_msg						;store msg to buffer
	ldi ZL, low(line3_capted_msg*2)		;load const string poiter
	ldi ZH, high(line3_capted_msg*2)	;
	rcall load_msg						;store msg to buffer
	rcall update_lcd_dog				;refresh the display
	rcall display_num
	ret

;display the number of resule_val
display_num:
	ldi ZL, low(result_val)			;get pointer to the result array
	ldi ZH, high(result_val)		;
	ld r5, Z+						;get all digits
	ld r4, Z+						;
	ld r3, Z+						;
	ld r2, Z+						;
	ld r1, Z+						;
	ld r0, Z						;
	ldi r16, 0x30					;
	add r5, r16						;convert to ascci
	add r4, r16						;
	add r3, r16						;
	add r2, r16						;
	add r1, r16						;
	add r0, r16						;
	ldi ZL, low(dsp_buff_1)			;get pointer to buffer
	ldi ZH, high(dsp_buff_1)		;
	adiw Z, 2						;advance the cursor
	st Z+, r5						;
	adiw Z, 1						;skip the period
	st Z+, r4						;store rest
	st Z+, r3						;
	st Z+, r2						;
	st Z+, r1						;
	st Z, r0						;
	rcall update_lcd_dog			;refresh the display
	ret

;take the raw_result_h and raw_result_l
;and get the bcd value in result_val
calculate_val:
	lds r16, raw_result_l
	lds r17, raw_result_h
	ldi r18, 125					;step size in mV*10^-2 unit
	ldi r19, 0						;prepare to multiply
	rcall mpy16u					;multiply by step size
	mov r16, r18					;prepare to unpack the result(3 Bytes)
	mov r17, r19					;
	mov r18, r20					;
	rcall unpack_hex_val_to_bcd		;unpack
	ldi ZL, low(result_val)			;get the pointer 
	ldi ZH, high(result_val)		;
	st Z+, r5						;store digits into it
	st Z+, r4						;
	st Z+, r3						;
	st Z+, r2						;
	st Z+, r1						;
	st Z, r0						;
	ret

	
	
;****************************************
;end of helper subroutines for state subroutines
;**********************************************************




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
					
	

