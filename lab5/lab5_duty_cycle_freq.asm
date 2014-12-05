/*
 * lab5_duty_cycle.asm: a program that produces PWM signals.
 *			The frequency of the pulse generated can be programed
 *			by PD7 to PD4. The input ranges from 0 to 15, where the
 *			higher value means higer frequency(0 means stop). The periods
 *			for each input from low to high are: 8s, 6s, 4s, 2s, 1s,
 *			800ms, 600ms, 400ms, 200ms, 100ms, 70ms, 40ms, 10ms, 1ms and 
 *			300ns. The duty cycle of the PWM signals is also programmable. 
 *			It's controlled by PD3 to PD0. Only 1 to 9 values are allowed,
 *			and any invalid values would be corrected to the nearest 
 *			value. The formula for duty cycle is 10%*N where N is the 
 *			value. This value will be displayed on the 7-segment LEDs.
 *
 * inputs: PIND, PC0
 * outputs: 7 segment LEDs(PORTB), PA0
 * 
 * assume:nothing
 *
 *  Created: 10/4/2014 9:19:25 PM
 *   Author: chaojie wang
 */ 

 .nolist
 .include "m16def.inc"   ;include part specific header file
 .list

 init:
	cbi DDRC, 0				;set up LOAD button on PC0
	sbi PORTC, 0				;enable pull up for PC0
	sbi DDRA, 0				;output PA0 for PWM
	ldi r16, 0x00				;prepare to setup 8 inputs controls
	out DDRD, r16				;set up PORTD as inputs
	ldi r16, 0xff				;prepare to enable pull-up for PIND
	out PORTD, r16				;enable pull-up for PIND
	ldi r16, 0xff				;prepare to setup 7-segment LEDs
	out DDRB, r16				;set 7-segment LEDs as outputs
	ldi r20, 1				;The default duty cycles, which is 10% as now
	ldi r21, 0				;The default frequency, which is 0
	;initialize stack pointer
	ldi r16, low(RAMEND)
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16

main_loop:
	;generate waves and display on 7-segment LEDs
	mov r16, r20				;prepare to display the duty cycle
	rcall display_7seg			;display the result
	sbis PINC, 0				;check if load button is pushed
	rjmp load_requested			;yes.
	cpi r21, 1				;check if frequency setting is "0"
	brlo freq0				;yes, jmp. otherwise, next cpi
	cpi r21, 5				;check if frequency setting is 1 to 4
	brlo freq1_to_4				;yes, jmp. otherwise, next cpi
	cpi r21, 10				;check if frequency setting is 5 to 9
	brlo freq5_to_9				;yes, jmp. otherwise, next cpi
	cpi r21, 14				;check if frequency setting is 10 to 13
	brlo freq10_to_13			;yes, jmp. otherwise, next cpi
	cpi r21, 15				;check if frequency setting is 14
	brlo freq14_jmp				;yes, jmp. otherwise last case
	rjmp max_freq				;last case 15, which is maximum frequency

freq14_jmp:
	jmp freq14

freq0:
	cbi PORTA, 0				;stop the wave
	rjmp main_loop

freq1_to_4:
	sbi PORTA, 0				;high level of the pulse
	ldi r18, 2				;doing calculation to determine the delay time
	mul r18, r21
	mov r18, r0
	ldi r19, 10
	sub r19, r18
	mul r19, r20				;done calculation. r19 is the parameter to get delay time
	mov r19, r0
	mov r16, r19				;set up the parameter	
	rcall delay_by_100ms			;delay
	cbi PORTA, 1				;low level of the pulse
	ldi r18, 2				;doing calculation to determine the delay time
	mul r18, r21
	mov r18, r0
	ldi r19, 10
	sub r19, r18
	ldi r17, 10
	sub r17, r20
	mul r17, r19				;done calculation. r17 is the parameter to get delay time
	mov r17, r0
	mov r16, r17				;set up parameter
	rcall delay_by_100ms			;delay
	rjmp main_loop				;finish, go back to the main loop
	
freq5_to_9:
	sbi PORTA, 0				;high level of the pulse
	ldi r17, 2				;doing calculations
	mul r17, r21
	mov r17, r0
	ldi r18, 20
	sub r18, r17
	mul r18, r20				;done calculation, r18 is the parameter for delay time
	mov r18, r0
	mov r16, r18				;set up the parameter
	rcall delay_by_10ms			;delay
	cbi PORTA, 0				;change to low level of the pulse
	ldi r17, 2				;doing calculations
	mul r17, r21
	mov r17, r0
	ldi r18, 20
	sub r18, r17
	ldi r19, 10
	sub r19, r20
	mul r19, r18				;done calculaitons, r19 is the parameter for delay
	mov r19, r0
	mov r16, r19				;set up the parameter
	rcall delay_by_10ms			;delay
	rjmp main_loop

freq10_to_13:
	sbi PORTA, 0				;high level of the pulse
	ldi r17, 3				;doing calculation
	mul r17, r21
	mov r17, r0
	ldi r18, 40
	sub r18, r17
	mul r18, r20				;done calculation
	mov r18, r0
	mov r16, r18				;set up parameter
	rcall delay_by_ms			;delay
	cbi PORTA, 0				;change to low level of the pulse
	ldi r17, 3				;doing calculation
	mul r17, r21
	mov r17, r0
	ldi r18, 40
	sub r18, r17
	ldi r19, 10
	sub r19, r20
	mul r19, r18				;done calculation
	mov r19, r0
	mov r16, r19				;set up the parameter
	rcall delay_by_ms			;delay
	rjmp main_loop
	
freq14:
	sbi PORTA, 0				;high level of the pulse
	ldi r16, 24				;the multiply factor for getting delay
	mul r16, r20				;get the delay parameter
	mov r16, r0
	subi r16, 5				;adjust it because of other instruction time
	rcall delay_by_ns			;delay r20*100 ns
	cbi PORTA, 0				;low level of the pulse
	ldi r17, 10				;prepare to get delay time
	sub r17, r20				
	ldi r16, 24
	mul r16, r17
	mov r16, r0
	subi r16, 2				;adjust it because of other instruction time
	rcall delay_by_ns			;delay (10-r20)*100ns
	rjmp main_loop
	
max_freq:
	sbi PORTA, 0				;high level of the pulse
	ldi r16, 10				;doing calculations
	mul r16, r20
	mov r16, r0				
	subi r16, 3					
	rcall delay_by_ns			;delay r20*100 ns
	cbi PORTA, 0				;low level of the pulse
	ldi r17, 10				;doing calculaitons
	sub r17, r20				
	ldi r16, 10
	mul r16, r17
	mov r16, r0
	subi r16, 9				;adjust it because of other instruction time
	rcall delay_by_ns			;delay (10-r20)*100ns
	rjmp main_loop

load_requested:
	ldi r17, 10				;outer loop
filter_noise:
	ldi r16, 0xfe				
	rcall delay_by_ns			;roughly 1ms
	dec r17
	brne filter_noise			;10 times of 1ms
	sbic PINC, 0				;check if the button is still being pressed
	rjmp main_loop				;no, it's noise
	in r16, PIND				;read in the value
	andi r16, 0x0f				;mask out higher 4 nipples
	cpi r16, 0x0a				;compare readin with 10
	brsh invalid_input1			;10 or above. invalid input. correct it
	cpi r16, 0x01				;compare readin with 0	
	brlo invalid_input2			;0, invalid. correct it.
	mov r20, r16				;valid input, set the new duty cycle
get_freq:
	in r16, PIND				;read in the value
	swap r16				;prepare to get new frequency
	andi r16, 0x0f				;obtain only higher 4 nipples, which is the frequency
	mov r21, r16				;set the new frequency
	rjmp wait_for_btn_release

invalid_input1:
	ldi r20, 9				;correct wrong input with 9, and setthe new duty cycle
	rjmp get_freq
	
invalid_input2:
	ldi r20, 1				;correct wrong input with 1, and setthe new duty cycle
	rjmp get_freq

wait_for_btn_release:
	sbic PINC, 0				;check the load button
	rjmp main_loop				;it's released, go back to main loop
	rjmp wait_for_btn_release		;otherwise, continue waiting

;generate N*10 ms delay (in 1MHz clock frequency)
;where N is spcified by r16. use 17 as well
;r16>0
delay_by_10ms:
	push r16				;save the original vale	
	ldi r16, 10				;prepare to delay for 10ms
	rcall delay_by_ms			;delay
	pop r16					;restore the value
	dec r16					;counting how many 10ms delay
	brne delay_by_10ms			;not done, continue
	ret						


;generate N*100 ms delay (in 1MHz clock frequency)
;where N is spcified by r16. use 17 as well
;r16>0
delay_by_100ms:
	push r16				;save the original value of r16
	ldi r16, 100				;prepare to delay 100ms
	rcall delay_by_ms			;delay for 100ms
	pop r16					;get back the original value
	dec r16					;dec the counter
	brne delay_by_100ms			;if not done yet, conitue
	ret					;done

;generate N ms delay (in 1MHz clock frequency)
;where N is specified by r16. use r17 as well
;r16>0,
delay_by_ms:
	ldi r17, 248				;the varibale for the inner loop
delay_by_ms_inner:
	nop					;total 4 cycles
	dec r17
	brne delay_by_ms_inner
	dec r16					;counting
	brne delay_by_ms			;if not done, go back and continue delay
	ret					;done

;generate (N+1)*4-1 ns delay (in 1MHz clock frequency)
;where N is specified by r16
;r16>0
delay_by_ns:
	dec r16						
	nop
	brne delay_by_ns
	ret

;display number on 7seg
;uses r16 as the number, r17 is used as tmp variable
;clock: 13
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
