;;  ------- REVISION HISTORY -----------------------------------------------
;;
;;  -----------
;;  modified mm/dd/yy  <initials>
;;      <modification description text>
;;  -----------
;;  original release: 11/06/2014  FST  {BETA Version}
;;      basic set of routines, including send_audio_r17r16 audio driver.
;;--------------------------------------------------------------------------

;************************************************************************ 
;  FILE NAME: audio_playback_WTV20SD_beta.inc    (Version 1b)
;
;  (ATmega16/ATmega16A  Initial Beta Version                                   
;   
;  This AVR-asm include module provides the asm-drivers to send
;  audio playback message requests to the WTV20SD Audio Playback Module
;
;  This code is designed to be executed on an AVR ATMega micro-computer.
;  
;
;************************************************************************
;  This module contains all of the following procedures:
;  ----------------------------------------------------
;    1. Fixed DELAYS:
;          audelay_30uS 
;          audelay_300uS 
;          audelay_1mS
;          audelay_2mS
;          audelay_40mS
;    
;    2. Audio request subroutine:
;          send_audio_r17r16
;
;

;======== audmo DELAY ROUTINES =======================================	



;************************
;NAME:        audelay_30uS
;ASSUMES:     nothing
;RETURNS:     nothing
;MODIFIES:    SREG
;CALLED BY:   
;DESCRIPTION: This procedure will generate a fixed delay of just over
;             30 uS (assuming a 1 MHz clock).
;********************************************************************
audelay_30uS: nop               ; fine tune delay
     nop               ;
     push  r24         ; save count reg
     ldi   r24, 0x0f   ; load delay count.
aud30_loop:
     dec   r24         ; count down to
     brne  aud30_loop  ; zero.
     pop   r24         ; restore orig contents
     ret


;**************************
;NAME:        audelay_300uS
;ASSUMES:     nothing
;RETURNS:     nothing
;MODIFIES:    R25, SREG
;CALLED BY:   
;DESCRIPTION: This procedure will generate a fixed delay of APPROX
;             300 uS (assuming a 1 MHz clock).
;********************************************************************
audelay_300uS:
    ldi   r25, 10        ; loop count = 10 decimal
dly_300_loop:
    push  r25 
    rcall audelay_30uS
    pop   r25
    dec   r25            ; count down to
    brne  dly_300_loop   ; zero.
    ret


;*************************************************************
; audelay_1mS - Nested loop delay for creating a delay of 1 mS
; inputs: none
; outputs: none
; alters: nothing
;
; equates for this delay routine
.equ outer_cnt11 = 0x18  ; *20* worked (loop ctr val)
.equ inner_cnt11 = 0x0d  ; inner loop ctr load value
;
;****************************************************
audelay_1mS:
    push r16
    push r17
    ldi  r16,outer_cnt11   ;init outer loop counter value
dloop111:
    ldi  r17,inner_cnt11   ;init inner loop counter value
dloop222:
    dec  r17               ; decr inner count and if
    brne dloop222          ; 0, fall thru.
    dec r16                ; decr outer count, and if
    brne dloop111          ; 0, fall thru.
    pop  r17
    pop  r16
    ret       



;*************************************************************
; audelay_2mS - Nested loop delay for creating a delay of 2 mS
; inputs: none
; outputs: none
; alters: nothing
;
; equates for this delay routine
.equ outer_cnt2 = 0x33  ; outer loop counter load value
.equ inner_cnt2 = 0x0d  ; inner loop counter load value
;
;***********************************************
audelay_2mS:
    push r16
push r17
    ldi  r16,outer_cnt2   ;init outer loop counter value
dloop11:
    ldi  r17,inner_cnt2   ;init inner loop counter value
dloop22:
    dec  r17             ; decr inner count and if
    brne dloop22          ; 0, fall thru.
    dec r16              ; decr outer count, and if
    brne dloop11          ; 0, fall thru.
    pop  r17
    pop  r16
    ret       


;*********************************************************************
; audelay_10mS - Nested loop delay for creating a 10mS
;                (Useful for software debouncing)
;
; inputs: none
; outputs: none
; alters: nothing
;
; Debouncing delay equate counts
.equ o_cnt = 0xf1  ; outer loop counter load value
.equ i_cnt = 0x0d  ; inner loop counter load value
;
;***********************************************
audelay_10mS:
    push r16             ; save registers
    push r17
    ldi  r16,o_cnt   ; init outer loop counter value
audloop1:
    ldi  r17,i_cnt   ; init inner loop counter value
audloop2:
    dec  r17             ; decr inner count and if
    brne audloop2          ; 0, fall thru.
    dec r16              ; decr outer count, and if
    brne audloop1          ; 0, fall thru.
    pop  r17             ; restore registers
    pop  r16
    ret 



;************************
;NAME:        audelay_300mS
;ASSUMES:     nothing
;RETURNS:     nothing
;MODIFIES:    R22,R23, SREG
;CALLED BY:   init_dsp, ????
;DESCRIPTION: This procedure will generate a fixed delay of just over
;             300 mS.
;********************************************************************
audelay_300mS:
     ldi  r25, 27      ; outer loop ctr : *26* was min that worked
                       ; load count-down value for ~300mS
audelay_300ms_loop:
     push  r25           ; save loop counter
     rcall audelay_10mS  ; do a 10 mS delay, 35 times
     pop   r25           ; restore loop counter
     dec   r25           ; dec and check for 0
     brne  audelay_300ms_loop
     ret
	 

;************************
; NAME: send_audio_r17r16
; DESC: Each call causes a 16 bit value to be transmitted to 
;   the audio playback module. The 16-bit value can range 
;   from 0x0000 to 0x01ff, providing for the playback of 
;   up to 512 .AD4 audio message files (AMFs). 
;
;  Currently: AMFs 0x0000 to 0x0009 are the matching
;     "number" audio files. So to output an audio "1", 
;     you load r17r16 with 0x0001.  To output an audio "2",
;     load r17:r16 withh 0x0002, and so on. See below for 
;     a full list presently available, pre-recorded
;     audio playback messages
;
; Interface signals:
;    DATA   = PA0    Data out to audio module.
;    DCLK   = PA1    Normally logic 1, Low for 2mS at start.
;    RESET  = PA2    Pulsed low, for 5mS, high for 300 mS
;                    before the clock goes low for 2mS.
;    BUSY   = PA3    Compicated signal!! (300mS delay required
;                    before testing this bit)
;                    1=processing data (busy), 0=ready for data
;
; Assumes: r17:r16 = trigger data to be serially sent. Sound 
;                    files available are as follows:
;
;    r17:r16 =  0x0000 = zero
;            =  0x0001 = one
;            =	0x0002 = two
;                  ...
;                  ...
;            =  0x0009 = nine
;            =  0x000a = 'point'
;            =
;-------------
; Inputs: r17:r16, PA3=Busy status bit
; Outputs: PA0=DATA; PA1=DCK; PA2=RESET (audio module)
; Notes: TIMING FOR THIS MODULE IS CRITICAL & IT IS
;        SUGGESTED THAT THE DELAY TIMES NOT BE ALTERED.
;
send_audio_r17r16:
check_busy:
     sbic  PinA, 3           ; if BUSY = 1... Wait!
     rjmp  check_busy    ;
     rcall audelay_10mS  ; **10mS**
check_busyy:
     sbic  PinA, 3           ; if BUSY = 1... Wait!
     rjmp  check_busyy   ;

reset_pulse:
     cbi  PortA, 2         ; take RESET of audmo low...
     rcall audelay_1mS     ; **10mS** must be low for > 5 mS,
     sbi  PortA, 2         ; take RESET back to '1'.

     ;audelay for 300mS before dclk goes low
     rcall audelay_300mS   ; REQ'D delay of 300mS
take_clk_low:
     cbi   PortA, 1        ; take DCLK low, and delay
     rcall audelay_1mS     ; **1mS** 

     ;send ZEROs loop
     ldi   r18, 0x010    ; load loop counter (16 clocks)
send_r17r16_loop:
     rol   r16           ; rotate and test next bit...
     rol   r17           ; (move bit into CY)
     brcs  out_one       ; if cy set, brch to output a '1'
     cbi   PortA, 0      ; OK... data bit is '0'
     rjmp  pulse_clk     ; jmp and gen clock pulse
out_one:
     sbi   PortA, 0      ; data bit is '1'
pulse_clk:
     cbi   PortA, 1      ; Take clk low, and
     rcall audelay_1mS   ; delay for 1mS
     sbi   PortA, 1      ; set clock bit high
     rcall audelay_1mS   ; delay for 2mS
	 dec   r18           ; check loop counter &
     brne  send_r17r16_loop  ; jump if NOT zero

take_clk_data_high:
     sbi   PortA, 1      ; Take clk high, and
     sbi   PortA,0       ; take data high.
     rcall audelay_10mS  ; delay, and both
     rcall audelay_10mS  ; SEEM to be REQUIRED!
     ret 


;*** END OF AUDIO OUTOUT RELATED ROUTINES ***
;==============================================
