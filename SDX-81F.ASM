$PAginate title(test 8051)
$subtitle(Test file for the 8051 AVMAC)
	defseg startseg, absolute
	seg startseg
;‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹

;in the future set up a time watch to reset controller.

; based on sdx-77x . modified for new board. hset-trx control.


;SDX-7		from sdx-5. bug solving

	;sdx-6 used for nokia dtmf. abandoned temporarily. no A, B, C, D 

;SDX-5		READ AND WRITE TO NOKIA DATA BUS

;SDX-4		MODIFIED START AND END OF HANDSHAKE FOR GAT5

;SDX-3		IMPROVED END OF HANDSHAKE. WAIT UNTIL THERE IS NO
		;ANSWER TONE TO SEND "#" TO COMPLETE ACKNOWLEDGE

;SDX-2		MAC.SD file for macros. SUB.SD file for procedures


;SDX-1		PROTOTYPE VERSION. DTMF handshake. Call Timer
;		checksum of digits sent

;sd2c-7y	dtmf handshake
;SD2C-7X	VERSION FOR EMULATOR. DISCARDED RADIO BUS READING (radcont) 

;‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹

;CONSTANT ASSIGNMENTS
TRX	EQU	00H
HSET	EQU	20H

;GLOB	EQU	0E0H
GLOB	EQU	00H

XBYTE	EQU	999	;force send_message read data stored in R_DATA
;-----------------------------------------------------

;REGISTER ASSIGNMENTS

;REGISTER BANK 0, RS0=0, RS1=0			
;R0	offset POINTER (put_dtmf, put_ser, put_s, get_dmb)
;R1
;R2	GET_DMB
;R3
;R4
;R5	GENERAL COUNTER FOR MAIN PROGRAM
;R6	
;R7	TICS		1 sec tic (0 --> 255)	

;REGISTER BANK 1, RS0=1, RS1=0			CARD READER
;R0	
;R1
;R2
;R3	counter	
;R4
;R5
;R6	BIT_T		partial storage of 5 bits 
;R7	BIT_C		counter of 5 bits per digit

;REGISTER BANK 2, RS0=0, RS1=1			MODEM/DTMF | BUS READ
;R0	POINTER TO R_BUFF (24 bytes max, only needed 20)/ DTMF string pointer
;R1	BACKUP SEQUENCE NUMBER (in case of error)
;R2	LAST sequence number
;R3	check sum
;R4	data byte count
;R5	flag for get_message error
;R6	pointer to selected data byte for retrieval by get_message
;R7	total packet length ( R4 + 4 )

;REGISTER BANK 3, RS0=1, RS1=1			system clock & TICS
;R0	LS TICM		miliseconds ( 0 --> 1000 )
;R1	MS TICM
;R2	prescaler, divide by 4 for 1 ms tic	
;R3	units 			system clock (max 99999 seconds)
;R4	tenths 
;R5	hundreds 
;R6	thousands
;R7	tens of thousands 

;---------------------------------------
;DIRECT/INDIRECT MEMORY ASSIGNMENTS
;---------------------------------------
;bit addresable memory assignments 20h thru 2fh


	; LOCATIONS 20H THROUGH 27H ARE NOT BEING USED  !!!


S_FLAG		EQU	28H.0	;FLAG FOR START SENTINEL DETECTED
S_CARD		EQU	28H.1	;FLAG FOR CARD READY
TEST1		EQU	28H.2	;TEST FLAG FOR END OF CARD READING
VALID		EQU	28H.3	;IF =1, NOT A VALID CARD, START ALL OVER
error_t		equ	28h.4	;timer 0 time out flag
DEBUG		EQU	28H.5	;JUST FOR DEBUGING
TIMER_X		EQU	28H.6	;0:ERROR CHECK; 1:LAST CALL TIME
ACK_FLAG	EQU	28H.7	;ANSWERING TONE FROM MODEM RECEIVED


F_CALL		EQU	29H.1	;1= CALL ON PROGRESS
GLOBAL		EQU	29H.2	;1= GLOBALS ARE ON
SERVICE		EQU	29H.3	;1= ON SERVICE
type_glob	equ	29h.4	;1= sending a global command to hset

C_VALID		EQU	29H.5	;1= card was approved by gateway. OK short
F_POWER		EQU	29H.6	;1= sent power_on to radio
TRAP		EQU	29H.7	;trap to detect problem with auto start

BUS_WAY		EQU	2AH.0	;0= TRX
				;1= HSET

KEY_FLAG	EQU	2AH.1	;0= NO KEY RELEASE PENDING
				;1= KEY RELEASE PENDING (used by wait_user)

D_ONE		EQU	2AH.2	;1= FIRST DIGIT DIALED IS A "1"
D_ZERO		EQU	2AH.3	;1= FIRST DIGIT DIALED IS A "0"
USER_CODE	EQU	2AH.4	;1= USER HAS DIALED AN '*' CODE
ARMED		EQU	2AH.5	;1= second time around for power off
DOOR_TYPE	EQU	2AH.6	;0= 0V, 1= 12V. DOOR SWITCH TYPE
DOOR		EQU	2AH.7	;0= didn't open, 1= opened once

ready		equ	2bh.0	;0=waiting for service, 1='slide' or 'ready'
read_nok	equ	2bh.1	;1= last sent message was to read nokia memory
;---------------------------------------

	; non bit addressable starts at 30h thru 7fh
	; stack starts at 48h

TIME0	EQU	30H		;watch-dog timer for power off reset
				;GENERAL PURPOSE TIMERS/COUNTERS
TIME1	EQU	31H		;THEY INCREMENT AT 1 SECOND/COUNT
TIME2	EQU	32H		;CAN BE RESET BY: mov time#,#0
TIME3	EQU	33H		;USED FOR TIME OUTS
TIME4	EQU	34H
TIME5	EQU	35H
TIME6	EQU	36H		;NOKIA NO-GLOB TIME-OUT. RESET BY STOP_GLOBALS
time7	EQU	37H		;WAITFOR

PASS	EQU	38H		;second chance for data retransmision
RETRIES	EQU	39H		;retries to send TX request to gateway

R_DATA	EQU	3AH		;nokia bus recv selected data byte
R_SEQN	EQU	3BH		;received sequence number with GET_MESSAGE
R_TYPE	EQU	3CH		;received message type
G_SEQN	EQU	3DH		;last queried global (by WAIT_GLOBAL) SEQN
S_TYPE	EQU	3EH		;sent Message TYPE for error detect
REPEAT	EQU	3FH		;REPEAT SEND MESSAGE COUNTER

x_loop	equ	40h		;loop counter wait_globals
y_loop	equ	41h		;loop counter wait_globals
z_loop	equ	42h		;loop counter wait_message

SM_CODE	EQU	43H		;state machine variable
DOOR_CODE EQU	44H		;00=closed, 01=open (taxi), 02=normal

;not used yet 45H to 47H
; start of stack at 48H
; end of stack 7fH
;---------------------------------------
;DIRECT ONLY MEMORY ASSIGNMENTS

CMOD	EQU	0D9H
CCON	EQU	0D8H
CCAPM4	EQU	0DEH
;---------------------------------------
;INDIRECT ONLY MEMORY ASSIGNMENTS

c_numb	equ	80h		;RAM card number memory allocation

c_expd	equ	98h		;RAM expiration date memory allocation
c_sum	equ	9dh		;checksum for gateway handshake data

c_time	equ	0a0h		;time last call 
c_seqn	equ	0a6h		;sequence number of the call

c_id	equ	0a8h		;telephone id
;free	equ	0ad		;two bytes plus "$" free (or longer id)

R_BUFF	EQU	0B0H		;buffer for nokia data bus (max 20 bytes)

RAW_C	equ	0C8H		;buffer up to 48 bytes ( C8H to FF )
				;used by CARD (for raw data from mag.strip)
				;and number dialed from keyboard
;last entry in indirect ram. 

;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

;TEST THE FOLLOWING SINTAX FOR REGISTER ASSIGNMENTS. 
;IT MAY BE INCORRECT AND BE WORKING BY SHEER LUCK. good heavens!


;register assignments
 
;bank 0
TICS	EQU	07H	;R7(bank 0)   seconds counter for time-out

;bank 1
BIT_T	EQU	0eH	;R5(bank 1)   TEMPORARY STORAGE RECEIVED CARD BITS
BIT_C	EQU	0fH	;R7(bank 1)   RECEIVED CARD BIT COUNTER

;bank 2
F_ERROR	EQU	15H	;R5 BANK 2
;this does not work for sure
;M_TYPE	EQU	16H	;message type received from nokia bus. R6, bank 2


;bank 3
;system clock registers bank 3
ck_1	equ	1bh	;r3 bank 3
ck_10	equ	1ch	;r4
ck_100	equ	1dh	;r5
ck_1k	equ	1eh	;r6
ck_10k	equ	1fh	;r7


;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!




;---------------------------------------
;external I/O pin assignment
;hardware configuration

C_STRB	EQU	P1.1	;CARD READER STROBE
C_DATA	EQU	P1.2	;CARD READER DATA

ROUT	EQU	P1.6	;the next 4 controls the TRI-STATE buffer
RIN	EQU	P1.4
HOUT	EQU	P1.7
HIN	equ	p1.5

bypass	equ	p1.3

ASCTR	EQU	P1.0	;ANALOG SWITCH CONTROL

;ON_HOOK	EQU	P3.5	;0: OFF HOOK,   1: ON HOOK
DOOR_NEG	EQU	P3.5	;T1, 0V DOOR SWITCH SIGNAL, 0=door open
DOOR_POS	EQU	P3.4	;T0, 12V DOOR SWITCH SIGNAL, 0=door open
IGNIT	EQU	P3.2	;ignition sense 
;---------------------------------------


;INTERRUPT ADDRESS TABLE
	org	00h		;RESET
	jmp	init
;---------------------------------------
	org	03h		;INT0 (P3.2)	NOT USED
	reti		
;---------------------------------------
	org	0bh		;timer 0 
	jmp	time_e		;system clock
;---------------------------------------
;;
	org	013h		;INT1 (P3.3)	answr tone detect
	RETI
;	JMP	MOD_INT
;---------------------------------------
	org	1bh		;timer 1	used by uart
	reti
;---------------------------------------
	org	23h		;SERIAL PORT	NOT USED
	reti		
;---------------------------------------
	org	2bh		;INTERRUPT EXF2 (P1.1) IE.5
	JMP	CARD
;---------------------------------------
	org	33h		;PCA	not used
	reti
;---------------------------------------
	org	3Bh		;start of main program code
;---------------------------------------

;STRING STORAGE DECLARATIONS
;---------------------------------------
x_time	db	"00000$"
x_seqn	db	"6$"			;test sequence number
x_expd	db	"9506$"			;dummy expiration date for test
x_numb	db	"122333444455555$"	;dummy card number for test

; make sure these codes can not be a valid YEAR/MONTH combination
;; they must start with 9
multi_null	db	"0000$"		;multiple call w/o dialed number
multi_numb	db	"9000$"		;multiple call with number included
multi_stop	db	"9999$"		;non valid user action (or noise/error)
multi_same	db	"2222$"		;redial previous number
multi_code	db	"3333$"		;number included is an action * code


;‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹
;system identification number. Different for each unit (4 DIGITS ONLY)
x_id	db	"9000$"
;‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹


;macro definitions
;must be declared before being used
%INCLUDE SDX.MAC
%INCLUDE NOKIA.MAC
%INCLUDE SYSTEM.MAC



;‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹

init:	
;;;

	clr	ea
	CLR	ASCTR		;ANALOG SW  AUDIO ON, mantain power to MPP
	MOV	SP,#48h		;set start stack pointer
	
	setb	ea		; enable interrupts
	SETB	IE.1		; ENABLE TIMER 0 INTERRUPT

	clr	bypass		; disable radio/hset comm

;----------------------------------------------------------
	mov	tmod,#22h	; set timer 0 and 1
	setb	tr0		; start timer 0 (interrupt timer)

;;	; initialize PCA watchdog timer
	mov	ccapm4, #48h		; watchdog mode for pca module 4
	mov	ccon, #40h		; start pca counter
	setb	ie.6		; enable PCA for watchdog timer

	clr	ready

;----------------------------------------------------------

	clr	rs0		;set reg. bank 0 in PSW register
	clr	rs1

	mov	IP,#20h		;set priority to card interrupt


;	clr	tr0
	clr	tr1

	setb	C_STRB
	setb	C_DATA

	setb	ignit

	setb	p3.0		;modem rxd
	setb	p3.1		;modem txd
	setb	p3.2		;prepare INT0 pin level
	setb	IT0		;set negative edge trigger

	CLR	IE.5		;TIMER 2 INTERRUPT DISABLE (CARD READER)


	CLR	ROUT		;SWITCH OFF WRITE RADIO BUS 
	CLR	RIN		;SWITCH OFF READ RADIO BUS 
	CLR	HOUT		;MUST BE OFF ALL THE TIME
	clr	HIN


	CLR	F_CALL		;NOT ON CALL DURING INIT SEQUENCE

;set up interrupt of timer 2 for card reader
	CLR	0C8H.2		;TR2 SWITCH OFF TIMER 2
	CLR	0C8H.4		;TCLK  DISABLE AS UART BAUD GENERATOR
	CLR	0C8H.5		;RCLK
	SETB	0C8H.3		;EXEN2 ENABLE EXTERNAL INT P1.1
	CLR	0C8H.0		;CP/RL2 SET FOR CLOCK OUT MODE
	MOV	0C9H,#0		;T2OE DISABLE OUTPUT TIMER 2 

	CLR	S_FLAG		;if 1: START SENTINEL DETECTED
	clr	s_card		;flag for card present
	clr	test1		;card not read yet

	clr	key_FLAG	;allow testing hset with noops (wait_user)
	setb	door_pos	; positive 12V sensing pin
	setb	door_neg	; negative 0V sensing pin

;--------------------------
;reset system clock
	setb	rs0		;select clock register bank 3
	setb	rs1
	mov	time0, #0	;RESET power watch-dog timer

	mov	r0,#0		;reset clock registers
	mov	r1,#0
	mov	r2,#0
	mov	r3,#0
	mov	r4,#0
	mov	r5,#0
	mov	r6,#0
	mov	r7,#0
	mov	tics,#0		;init TICS counter ( 0 --> 255s )
	clr	rs0		;INIT START REG BANK 0
	clr	rs1
;--------------------------
;SET UP TIMER 0 FOR SYSTEM CLOCK
	mov	a,tmod
	CLR	acc.0
	SETB	acc.1
	CLR	acc.2
	CLR	acc.3
	mov	tmod,a
	
	MOV	TH0,#5		;RELOAD value FOR 250 us (256-250)

	mov	time1, #0	;initialize counter for watchdog
	SETB	IE.1		;ENABLE TIMER 0 INTERRUPT
	SETB	TCON.4		;START TIMER 0

	CLR	F_POWER		;radio is assumed in power down
;----------------------------------------------------------


;----------------------------------------------------------

;--------------------------
;initialize nokia sequence number
	clr	rs0
	setb	rs1
	mov	r2,#1
	clr	rs1
	
;--------------------------
	setb	ea		;enable interrupts


;=================================================================
;MAIN PROGRAM STARTS HERE
;***************************
;=================================================================

ini:	




;initialize modem
	mov	dptr,#6000h	;address control register 0
	mov	a,#00h		;power down, reset
	movx	@dptr,a
	mov	dptr,#6001h	;address control register 1
	mov	a,#04h		;reset modem
	movx	@dptr,a
	mov	dptr,#6003h	;no dtmf tones, DISable RXD
	mov	a,#10h
	movx	@dptr,a
	
;make sure later on to clear all interrupts
;and initialize all internal devices (uart, timers, pca, etc)



;----------------------------------------------------------
;	GET_DMB		C_TIME, X_TIME	;initial data for time
	CALL	GET_CLOCK	
;----------------------------------------------------------
;;Initialize phone call sequence number
	
;	get_dmb		c_seqn, x_seqn	;problems after sliDINg card
	call	get_C_seqn
;----------------------------------------------------------
;----------------------------------------------------------
;----------------------------------------------------------
;----------------------------------------------------------
	clr	C_VALID		;card not valid yet, "slide card"
	GET_DMB	C_EXPD, multi_stop	;default no user action or error
;----------------------------------------------------------
;----------------------------------------------------------

;----------------------------------------------------------
;----------------------------------------------------------
;----------------------------------------------------------
;;	; wait until phone is on service 
;	setb	C_VALID		;temporary for fast press send mode
	clr	door
;	setb	door_type	;test pos sensing 12V
	clr	door_type	;test neg sensing 0V
;----------------------------------------------------------
;;;
	sleep	15

;	jmp	$
;----------------------------------------------------------

WAIT_SERVICE:
	setb	bypass		; allow transceiver and hset to talk
	clr	ready
	clr	read_nok	;no mem-read messages to nokia

;;initialize modem
	mov	dptr,#6000h	;address control register 0
	mov	a,#00h		;power down, reset
	movx	@dptr,a
	mov	dptr,#6001h	;address control register 1
	mov	a,#04h		;reset modem
	movx	@dptr,a
	mov	dptr,#6003h	;no dtmf tones, DISable RXD
	mov	a,#10h
	movx	@dptr,a

	clr	ex1	;disable interrupt for answering tone
	setb	bypass
	setb	rin
;-------------------------------------------------------------
;-------------------------------------------------------------
;-------------------------------------------------------------

	wait_service
	setb	trap	;this flag has to be cleared by wait user
			;to detect if firmware skips steps
;	clr	bypass



;----------------------------------------------------------
	;; read door setup from nokia memory 55	
;----------------------------------------------------------
	mov	door_code, #01h	; default door allways open (ignore switch)

	setb	read_nok		; set long ack wait for get_msg 
	SEND_MESSAGE 06H, HSET, <"5", "5">	; read mem 55
	clr	read_nok		; set ack wait to normal

	SLEEPY	100
	get_byte	3
	jne	r_data, #0bbh, end_setup	;code must start with "**"
	get_byte	4

	anl	r_data, #0f0h	; disregard second digit


d_neg:				; **0 in MEM 55 --> 0V switch
	jne	r_data, #0a0h, d_pos
	clr	door_type	;neg sensing 0V
	mov	door_code, #02h	; normal operation, switch active
	jmp	end_setup

d_pos:				; **1 in MEM 55 --> 12V switch
	jne	r_data, #10h, d_clo
	setb	door_type	;pos sensing 12V
	mov	door_code, #02h	; normal operation, switch active
	jmp	end_setup

d_clo:				; **2 in MEM 55 --> door always closed
	jne	r_data, #20h, d_opn
	mov	door_code, #00h	; door allways closed (ignore switch)
	jmp	end_setup

d_opn:				; **3 in MEM 55 --> door always open
	mov	door_code, #01h	; door allways open (ignore switch)


end_setup:


;----------------------------------------------------------
	setb	ready		; this flag disables the power on watchdog

;----------------------------------------------------------

;;
WAIT_USER:
	sleepy	100
	start_globals		; verify if this does anything ???
	stop_globals



	GET_DMB	C_EXPD, multi_stop	;default no user action or error
	jmpb	f_power, 0, wait_service
	setb	ignit
	jmpb	ignit, 1, wait_service
	
	wait_user
	jumpif	0, send_X	;valid user action
	;else
	jmp	wait_user




;----------------------------------------------------------
CALL_GATEWAY:
;	call_gateway

;----------------------------------------------------------
SEND_X:
;----------------------------------------------------------

	jnb	trap, ok_send
	jmp	wait_user

ok_send:
	

;;compare here if c_expd contains 9999
	comp	c_expd, multi_stop
	JUMPIF	1, wait_user


	; SEND FIELDS

	GET_DMB		C_ID, X_ID

;----------------------------------------------------------
	; IF RADIO IS ON CALL, GO DIRECTLY TO HANDSHAKE

	SEND_MESSAGE 14H, TRX, ,1	;request call status
	sleepy 200
	MOV	A,#40H
	ANL	A,R_DATA		;check call status flag
	JZ	NO_CALL
	JMP	S_HANDSHAKE
;----------------------------------------------------------



;----------------------------------------------------------
NO_CALL:
	; WRITE "please wait"
	SEND_MESSAGE 38H, HSET, <50h,4ch,45h,41h,53h,45h,20h,20h,20h,20h,20h,20h,57h,41h,49h,54h >
	SLEEPY	100
;----------------------------------------------------------

	; press "END" to erase display and keys pressed previously
	send_message 05h, trx, <81h>
	SLEEPY	100
;----------------------------------------------------------
;make sure here that a card has been swiped or the send key pressed

;----------------------------------------------------------
;;;dial gateway
	; dial MAIN GATEWAY 1-203-425-4145
;	send_message 0ch, trx, <12h, 0A3h, 42h, 54h, 14h, 50h>
;----------------------------------------------------------
	; dial HOT LINED *CNET *2638
;	send_message 0ch, trx, <0b2h, 63h, 80h>
;----------------------------------------------------------
	; dial ALTERNATE-1 GATEWAY 1-203-425-4571
;	send_message 0ch, trx, <12h, 0A3h, 42h, 54h, 57h, 10h>
;----------------------------------------------------------
;----------------------------------------------------------
	; dial ALTERNATE-2 GATEWAY 1-203-425-4572
;	send_message 0ch, trx, <12h, 0A3h, 42h, 54h, 57h, 20h>
;----------------------------------------------------------
	; read gateway number from memory

	setb	read_nok		; set long ack wait for get_msg 
	send_message 06h, hset, <30h, 31h>	; read mem 01
	clr	read_nok		; set ack wait to normal

	sleepy	200

	; the following command can't be used if MEMORY ONLY ENABLE
	; is active in NOKIA. With globals off this is the only known way
	; to dial. 1+send does not work with globals off.

	send_message 0ch, trx, <555>		; call to number in mem 01




;----------------------------------------------------------

;	sleepy	70
;	send_message 05h, trx, <"*">
;	sleepy	70
;	send_message 05h, trx, <"2">
;	sleepy	70
;	send_message 05h, trx, <"6">
;	sleepy	70
;	send_message 05h, trx, <"3">
;	sleepy	70
;	send_message 05h, trx, <"8">
;	sleepy	70
;	send_message 05h, trx, <80h>
;	sleepy	70
;----------------------------------------------------------


	MOV	TIME7,#0		;RESET TIMER FOR WAIT1
WAIT_CALL:				;wait until radio is "on call"
	sleepy	100
	get_radio_stat
	jmpb	service, 0, wait_service
	WAIT1	F_CALL,8,WAIT_user,WAIT_CALL

;..	; the following code is to release the trx beep before turning
	; the globals on again at "you may dial now"

	start_globals		;release beep of "on call"
idle1:
	wait_message	trx
	jne	r_type, #7fh, idle1
	stop_globals

;..
	sleepy	200
	send_message	7fh, 0f0h, <0ffh, 81h>	;SEND GLOBAL,turn on call lite
	sleepy	20
;---------------------------------------------------
S_HANDSHAKE:

;WRITE "please wait"
;E
	SEND_MESSAGE 38H, HSET, <50h,4ch,45h,41h,53h,45h,20h,20h,20h,20h,20h,20h,57h,41h,49h,54h >
;P
;	SEND_MESSAGE 38H, HSET, <46h,41h,56h,4Fh,52h,20h,20h,20h,41h,47h,55h,41h,52h,44h,41h,52h >
	sleepy	200

	mov	PASS,#0				;allow only one retransmision
	mov	RETRIES,#0

	; WAIT FOR ANSWERING TONE
ACK1:

	get_radio_stat
	jmpb	service, 0, wait_service
	jb	f_call,continue_ack
	jmp	wait_service

	send_message	14h, trx,, 0
	mov	a,#20h			;on service?
	anl	a,r_data
	jnz	continue_ack
	jmp	wait_service

continue_ack:
	MOV	A,#4		;increase number of repetitions
	cjne	A,PASS,ACK3			;IF SECOND PASS, WAIT FOR CARD
	clr	c_valid				;display "slide card"
	JMP	WAIT_USER

ACK3:
	WAIT_END

	INC	RETRIES
	tone	13, P				;ACKNOWLEGE START OF HANDSHAKE
	MOV	time7,#0			;RESET FOR WAIT1

ACK2:
;................

	MOV	A,#15		;more fast retries until gateway answers
;	MOV	A,#4
	CJNE	A,RETRIES,ACK4
	
	send_message 05h, trx, <81h>		;press "end" to stop call
	sleepy	200
	jmp	wait_service

ACK4:	
	CALL	GET_ACK

;;timer set to zero??!!
;	WAIT1	ACK_FLAG, 0, ACK1, ACK4		;start handshake when gateway
	WAIT1	ACK_FLAG, 1, ACK1, ACK4		;start handshake when gateway
						;answers
;WAIT FOR END OF ANSWERING TONE

	MOV	time7,#0
W_SILENCE:			;REPEAT IF GATEWAY DIDN'T START ACK
	MOV	RETRIES,#0
	CALL	GET_ACK
	WAIT0	ACK_FLAG, 2, ACK1, W_SILENCE

	sleepy	250		;wait a bit for handsfree audio to settle
	sleepy	250
	sleepy	250
	sleepy	250
;-----------------------

	WAIT_END		; if end key pressed, exit

;-----------------------
SEND_DATA:

	CALL	CARD_CSUM

	PUT_DTMF	C_ID
	PUT_DTMF	C_TIME
	PUT_DTMF	C_SEQN
	PUT_DTMF	C_EXPD
	PUT_DTMF	C_NUMB
	tone		12		;#, END OF STRING
	PUT_DTMF	C_SUM

TX_END:
	WAIT_END
	inc	PASS			;second and last transmision

WAIT_ATONE:
				;WAIT FOR ANSWERING TONE
	MOV	RETRIES,#0

WAIT_ACK:
	INC	RETRIES
	MOV	A,#3
	MOV	time7,#0		;RESET TIMER FOR WAIT1 MACRO

	CJNE	A,RETRIES,WAIT_ACK2	;IF MAX RETRIES, SEND NEW PACKET
	MOV	RETRIES,#0
	JMP	ACK1
;---------------------


WAIT_ACK2:
	CALL	GET_ACK

;repeat handshake if ack answering tone not received

;;timer set to zero??!!
	WAIT1	ACK_FLAG, 0, WAIT_ACK, WAIT_ACK2

;WAIT FOR END OF ANSWERING TONE

	MOV	time7,#0		;RESET TIMER FOR WAIT0 MACRO
WAIT_SILENCE:
	CALL	GET_ACK
	WAIT0	ACK_FLAG, 2, WAIT_service, WAIT_SILENCE

	sleepy	200			;idle time to settle hands-free mode
	SLEEPY	100

	tone		15,P		;#, SEND FINAL ACKNOLEDGMENT

	MOV	time7,#0		;RESET TIMER FOR WAIT1 MACRO
NEW_REQUEST:
	CALL	GET_ACK
	; if second tone received before 2 sec, go to slide card
	WAIT1	ACK_FLAG, 1, RECEIVED_OK, NEW_REQUEST
;;	JMP	WAIT_SILENCE
	clr	c_valid
	JMP	WAIT_USER

;-----------------------------------	

RECEIVED_OK:
	CLR	ASCTR		;ANALOG SW  AUDIO ON
;______________________________________________________________________
	;WRITE "YOU MAY DIAL NOW" or "THANK YOU"

	comp	c_expd, multi_numb	;display thank you if number included
	JUMPIF	1, THANK_YOU
	comp	c_expd, multi_same	;display thank you if redial
	JUMPIF	1, THANK_YOU
	comp	c_expd, multi_code	;display thank you if speed code
	JUMPIF	1, THANK_YOU
	jmp	dial_now

THANK_YOU:
	SEND_MESSAGE 38H, HSET, <"T","H","A","N","K"," "," "," "," "," "," "," "," ","Y","O","U">
	JMP	DIAL_OK

DIAL_NOW:
	SEND_MESSAGE 38H, HSET, <20H,59H,4FH,55H,20H,4DH,41H,59H,44H,49H,41H,4CH,20H,4EH,4FH,57H>
DIAL_OK:
	SLEEPY	200	
	start_globals
;______________________________________________________________________
	; switch back to hset up. user can only speek thru hset

	wait_global
	SEND_MESSAGE 41H, TRX, <0H, 84H>, 0	;MEMORY DUMP, retrieve byte 0
	MOV	A,#08H
	ANL	A,R_DATA		;0= off hook, 1= on hook
	JnZ	END_HOOK
	send_message	21h, hset, <03>	; SWITCH TO INTERNAL MIC
end_hook;
;______________________________________________________________________
	;increment call sequence number
	SAVE_SEQN
;______________________________________________________________________

	;START COUNTING THE TIME OF THE CALL
	call	reset_clock
;______________________________________________________________________
on_call:

	wait_message TRX, 1
	jne	f_error, #0, on_call 	;this can be infinite if no globals!!
	jne	r_type, #7fh, test_hang_up
	anl	r_data, #80h		;test if on call (byte 1, bit 7 = 1)
	jeq	r_data, #80h, on_call
	jmp	call_ended
	
test_hang_up:
	jne	r_type, #05h, on_call	;not a key depresion
	get_byte 3			;retrieve data-byte 0 (4th byte)
	jne	r_data, #8Ah, on_call	;reed switch closed

call_ended:
	clr	f_call		;reset for power watch-dog timer
	call	save_clock
	setb	c_valid

test_end_call:
	send_message 05h, trx, <81h>	;stop on going call
	wait_global			;wait to allow trx switch off
	SEND_MESSAGE 38H, HSET, <"T","H","A","N","K"," "," "," "," "," "," "," "," ","Y","O","U">
	get_radio_stat
	jmpb	service, 0, wait_service
	jmpb	f_call, 1, test_end_call	;make sure call has ended
	jmp	wait_service			;hang_up complete


;---------------------------------------------------
;END OF HANDSHAKE




;‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹
;---------------------------------------------------
;SUBROUTINES
%INCLUDE SDX.SUB
%INCLUDE NOKIA.SUB

;‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹
;=================================================================
;---------------------------------------
;-----------------------------------------------------------------
;-----------------------------------------------------------------
;-----------------------------------------------------------------

	END
