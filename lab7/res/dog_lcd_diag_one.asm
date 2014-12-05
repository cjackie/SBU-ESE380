
;*****************************************************************
;**********      BASIC DOG LCD CHAR DIAGNOSTIC          **********
;*****************************************************************
; dog_lcd_diag_one.asm
;   Clears the display, and writes each character position with an “*”,
;   one after the other, and once the display is full, a “chip/beep” is 
;   produced by the sounder device... Then the test starts over.
;
; Inputs - None
;
; Outputs - DOG LCD module (3-line x 16 char)
;           Sounder (active low, PC0)
;
; Version - 1.1a
;

.nolist
.include "m16def.inc"
.list

     .CSEG

     ; interrupt vector table, with several 'safety' stubs
     rjmp RESET      ;Reset/Cold start vector
     reti            ;External Intr0 vector
     reti            ;External Intr1 vector

	 
;---------------------------- SUBROUTINES ----------------------------

;====================================
.include "lcd_dog_asm_driver_m16A.inc"  ; LCD DOG init/update procedures.
;====================================


;************************
;NAME:      clr_dsp_buffs
;FUNCTION:  Initializes dsp_buffers 1, 2, and 3 with blanks (0x20)
;ASSUMES:   Three CONTIGUOUS 16-byte dram based buffers named
;           dsp_buff_1, dsp_buff_2, dsp_buff_3.
;RETURNS:   nothing.
;MODIFIES:  r25,r26, Z-ptr
;CALLS:     none
;CALLED BY: main application and diagnostics
;********************************************************************
clr_dsp_buffs:
     ldi R25, 48               ; load total length of both buffer.
     ldi R26, ' '              ; load blank/space into R26.
     ldi ZH, high (dsp_buff_1) ; Load ZH and ZL as a pointer to 1st
     ldi ZL, low (dsp_buff_1)  ; byte of buffer for line 1.
   
    ;set DDRAM address to 1st position of first line.
store_bytes:
     st  Z+, R26       ; store ' ' into 1st/next buffer byte and
                       ; auto inc ptr to next location.
     dec  R25          ; 
     brne store_bytes  ; cont until r25=0, all bytes written.
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


;*****************
;NAME:      tone_5V
;FUNCTION:  causes tone/beep on piezo element
;ASSUMES:   nothing
;RETURNS:   nothing
;MODIFIES:  SREG
;CALLS:     v_delay
;*********************************************************************
tone_5V:
      push  r23   ; save registers
      push  r22
      push  r16

   ;***************************************************
   ;SOUNDER TONE/DURATION - ADJUSTABLE VALUE
   ;(Originally was 8)
    ldi   r16, 12     ; CALIBRATION PARAMETER
   ;SOUNDER TONE/DURATION ADJUSTMENT
   ;***************************************************

      ldi  r22, 0x04  ; inner delay count.
      ldi  r23, 1     ; outer delay count.
tone_loop:
      push r22        ; save counts in r22 and r23
      push r23        ;
      cbi  PortC,0    ; turn on sounder
      rcall v_delay   ; delay
      sbi  PortC,0    ; turn off sounder
      pop r23         ; restore delay count
      pop r22         ; down registers
      dec r16         ; adjust loop ctr, and if not
      brne tone_loop  ; zero, then branch and repeat.

      pop  r16   ; restore registers
      pop  r22
      pop  r23

      ret


;**********************************************************************
;************* M A I N   A P P L I C A T I O N   C O D E  *************
;**********************************************************************
RESET:
    ldi r16, low(RAMEND)   ; init stack/pointer
    out SPL, r16           ;
    ldi r16, high(RAMEND)  ;
    out SPH, r16

    ldi r16, 0xff     ; set portB = output.
    out DDRB, r16     ; 
    sbi portB, 4      ; set /SS of DOG LCD = 1 (Deselected)

	ldi r16, 1        ; set DDRC for all in but PC0
	out DDRC, r16

	sbi PortC, 0      ; turn off sounder

    rcall init_lcd_dog     ; init display, using SPI serial interface
	
lcd_display_diag:
    rcall clr_dsp_buffs    ; clear all three display lines
    rcall update_lcd_dog   ;

    ; *** DOG LCD display 'workout' diagnostic 
basic_dsp_diag_one:
    rcall clr_dsp_buffs   
    
    ldi   r20, 48    ; total length of all display buffers.
    ldi   ZH, high(dsp_buff_1) ; init pointer to 1st byte of
    ldi   ZL, low(dsp_buff_1)  ; buffer-1
    ;rcall tone_5V

write_loop:         ; -------------------------------------------------
    ldi   r16, '*'  ; LOAD "*", THIS CAN BE CHANGED TO ANY CHAR/LETTER!
                    ; -------------------------------------------------
    push  r20         ; save r20 bytes-written counter
    st    Z+, r16     ; store next "*"
    push  ZL          ; save Z-ptr
    push  ZH          ;
    rcall update_lcd_dog   ; update "*" pattern

    ; delay code setup and execution...
    ldi   r22, 0     ; load delay count in
    ldi   r23, 0x04  ; r23 & r22
    rcall v_delay    ; delay ~0.2 sec

    pop   ZH         ; restore regs altered by update &
    pop   ZL         ; vdelay
    pop   r20        ;
    dec   r20        ; check if buffer full
    brne  write_loop ;
    rcall tone_5V       ; beep is display full

    ldi   r22, 0     ;
    ldi   r23, 0x1b  ;
    rcall v_delay    ; delay ~1+ secs

    rjmp  basic_dsp_diag_one   ; repeat test...



;***** END OF FILE ******

