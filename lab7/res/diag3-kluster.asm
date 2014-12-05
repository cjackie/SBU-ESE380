
;*****************************************************************
;**********   BASIC KEY KLUSTER TO LCD DIAGNOSTIC     ************
;*****************************************************************
;
; diag3-kluster.asm
;
;  This diagnostic will test that each PBSW can be pressed and 
;  properly recognized.  With each pushbutton press, the sounder will
;  be activated (chirp), and the respective pushbutton identified.
;
; Inputs: key-cluster (PD7...PD3) with Keys identified as follows:
;
;     PB-Designation    Keyname      Port-Bit
;     --------------    --------     --------
;       PBSW1             UP          PD3          
;       PBSW2             DN          PD4          
;       PBSW3             LF          PD5          
;       PBSW4             RT          PD6          
;       PBSW5             GO          PD7
;          
; Outputs: LCD = Keyname and Port-bit
;          Sounder => 1 tone/chirp per keypress
;
; Version - 1.0a

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
.include "lcd_dog_asm_driver_m16.inc"  ; LCD DOG init/update procedures.
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


;*******************************************************
; delay_10mS - Nested loop delay for creating
;              a debounce delay of 10 mS
;
; inputs = none
; outputs = none
; alters r17:r16 (inner and outer loop counts)
;******************************************************

; Debouncing delay equate counts
.equ outer_cnt = 0xf1  ; outer loop counter load value
.equ inner_cnt = 0x0d  ; inner loop counter load value

delay_10mS:
    ldi  r16,outer_cnt   ;init outer loop counter value
dloop1:
	ldi  r17,inner_cnt   ;init inner loop counter value
dloop2:
	dec  r17             ; decr inner count and if
	brne dloop2          ; 0, fall thru.
    dec r16              ; decr outer count, and if
	brne dloop1          ; 0, fall thru.
    ret                  ; ************** 


;*****************
;NAME:      tone_5V
;FUNCTION:  causes tone/beep on piezo element
;ASSUMES:   nothing
;RETURNS:   nothing
;MODIFIES:  SREG
;CALLS:     v_delay
;***************************************************************
tone_5V:
       push  r23   ; save registers
       push  r22
       push  r16

      ;********************************************
      ; SOUNDER TONE/DURATION ADJUSTMENT
      ; (May be adjusted by user, as needed)
      ldi   r16, 12     ; CALIBRATION PARAMETER
      ;********************************************
  
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
    ldi r16, low(RAMEND)  ; init stack/pointer
    out SPL, r16          ;
    ldi r16, high(RAMEND) ;
    out SPH, r16
	
    ldi r16, 0xff     ; set portB = output.
    out DDRB, r16     ; 
    sbi portB, 4      ; set /SS of DOG LCD = 1 (Deselected)
	
	ldi r16, 1        ; set DDRC for all bits = 
	out DDRC, r16     ; input, but PC0... PC0=output
	sbi PortC, 0      ; turn off sounder

   ; Configure PORTD... Pushbutton Switches
    ldi   r16, $0         ;load r16 = all 0s, to set 
    out   DDRD, r16       ;PORTD = all bits input
    ldi   r16, $FF        ; load r16 = all 1s, to turn
    out   PortD, r16       ; on PORTD internal pullup Rs.
	
    rcall init_lcd_dog    ; init display, using SPI serial interface
    rcall tone_5V

	ldi  r21, 0x5         ; delay for ~ 1/5 second
msg_delay:
   rcall delay_40mS
   dec  r21
   brne msg_delay
  
   rcall tone_5V

message_dsp_loop:
   rcall clr_dsp_buffs   ; clear all three buffer lines
   rcall update_lcd_dog  ;
   

   ;load 1st line of prompt message into dbuff2
   ldi  ZH, high(line1_message<<1)  ;
   ldi  ZL, low(line1_message<<1)   ;
   rcall load_msg          ; load message into buffer(s).
   
   ;load 2nd line of prompt message into dbuff3
   ldi  ZH, high(line2_message<<1)  ;
   ldi  ZL, low(line2_message<<1)   ;
   rcall load_msg          ; load message into buffer(s).
   rcall tone_5V
   rcall update_lcd_dog

   ;wait for a pushbutton press...
wait4press:
	in    r16, PinD  ; read all pbsw values.
	com   r16         ; turn all 1's to 0's and
	andi  r16, $F8    ; mask all but pb-sw bits
	breq  wait4press  ; if eq to zero, no key pressed!

	rcall delay_10mS  ; debounce delay

    ;re-check PBs to be sure pb is still pressed
	in    r16, PinD  ; read all pbsw values.
	mov   r17, r16    ; temp store if key is pressed
	com   r16         ; turn all 1's to 0's and
	andi  r16, $F8    ; mask all but pb-sw bits
	breq  wait4press  ; if eq to zero, no key pressed!

	; OK... A PB is pressed!  --> clr dsply and
	;    using original bit pattern (r17), find
	;    the first '0' (keypressed) bit, starting
	;    from D7 (GO) and working down.

    rcall clr_dsp_buffs  ; clr display buffers
    mov r16, r17         ; reload port image.

    ; check for a zero-bit = key pressed
	; if found return with T-1 and keycode in r20
check_for_pb_press:
    lsl   r16        ; logical shift left upper 
	                 ; bits of r16 (pb port image)
	brcc  go_pressed ; cy=0, PBSW5 pressed = GO

    lsl   r16        ; logical shift left and if
	brcc  rt_pressed ; cy=0, PBSW4 pressed = RT

    lsl   r16        ; logical shift left and if
	brcc  lf_pressed ; cy=0, GO key pressed.

    lsl   r16        ; logical shift left and if
	brcc  dn_pressed ; cy=0, GO key pressed.


	;Then it is the UP pb that is pressed...
up_pressed:
   ldi  ZH, high(up_pb_msg<<1)  ; load pointer to UP
   ldi  ZL, low(up_pb_msg<<1)   ; pressed message
   rjmp display_pb_pressed_msg

dn_pressed:
   ldi  ZH, high(dn_pb_msg<<1)  ; load pointer to UP
   ldi  ZL, low(dn_pb_msg<<1)   ; pressed message
   rjmp display_pb_pressed_msg

lf_pressed:
   ldi  ZH, high(lf_pb_msg<<1)  ; load pointer to UP
   ldi  ZL, low(lf_pb_msg<<1)   ; pressed message
   rjmp display_pb_pressed_msg

rt_pressed:
   ldi  ZH, high(rt_pb_msg<<1)  ; load pointer to UP
   ldi  ZL, low(rt_pb_msg<<1)   ; pressed message
   rjmp display_pb_pressed_msg

go_pressed:
   ldi  ZH, high(go_pb_msg<<1)  ; load pointer to UP
   ldi  ZL, low(go_pb_msg<<1)   ; pressed message

display_pb_pressed_msg:
   rcall tone_5V
   rcall load_msg          ; load message into buffer
   rcall update_lcd_dog    ; and update to display.
   
wait4release:
	in    r16, PinD  ; read all pbsw values.
	com   r16         ; turn all 1's to 0's and
	andi  r16, $F8    ; mask all but pb-sw bits
	brne  wait4release  ; if eq to zero, no key pressed!

	; add an additional delay
	ldi r16, 0xf
release_delay:
    push  r16
	rcall delay_10mS  ; debounce delay
    pop   r16
    dec   r16
	brne  release_delay

    rjmp message_dsp_loop



;*************************************************************************
;*** FIXED TEXT LINES: All are16 chars in long, with varying ascii symbols
;*************************************************************************

line1_message: .db 1, "Press any       ", 0  ; prompt for pushbutton
line2_message: .db 2, "   pushbutton...", 0  ; switch press.
;blank_line:    .db 1, "                ", 0  ; empty line... if needed.

go_pb_msg:  .db 2, " GO pressed...  ", 0  ; go pb message string
rt_pb_msg:  .db 2, " RT pressed...  ", 0  ; go pb message string
lf_pb_msg:  .db 2, " LF pressed...  ", 0  ; go pb message string
dn_pb_msg:  .db 2, " DN pressed...  ", 0  ; go pb message string
up_pb_msg:  .db 2, " UP pressed...  ", 0  ; go pb message string


;***** END OF FILE ******

