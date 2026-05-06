;**************************************************
; FILE:      PIC12F629_675_EEPROM_IR.asm          *
; CONTENTS:  RDA5807M I2C Control                 *
; COPYRIGHT: DollY LAB. 2020-2030 				  *
; AUTHOR:    Nikola Tesla     					  *
; UPDATED:   13/05/22        					  *
;**************************************************

 radix DEC

     ifdef __12F629
     include "p12F629.inc"
     list    p=12F629
     endif

     ifdef __12F675
     include "p12F675.inc"
     list    p=12F675
     endif

     errorlevel -202,-224,-302,-305 ; Warnings and Messages 

  __idlocs H'2975'
  __CONFIG _FOSC_INTRCIO & _PWRTE_ON & _WDT_OFF & _BODEN_OFF & _CP_OFF & _CPD_OFF & _MCLRE_OFF;
 ;__CONFIG H'3F84'

;#############################################################
;VARIABLES - FILE REGISTERS 
;#############################################################

RAM  set  H'20'

		cblock RAM
;#################################################
DC1         ;EQU    020h    ;Delay Count Variable1
DC2         ;EQU    021h    ;Delay Count Variable2
bit_count   ;EQU    022h    ;Counter of processed bits in I2C
i2c_data    ;EQU    023h    ;Data to receive/transmit via I2C
port        ;EQU    024h    ;Helper register to implement I2C
ack         ;EQU    035h    ;Acknowledgment received from the device
Loc_Ptr     ;EQU    026h    ;/*EEPROM R/W Address Holder */
volume      ;EQU    027h    ;Radio volume level
frequency_l ;EQU    017h    ;Frequency low byte
frequency_h ;EQU    018h    ;Frequency high byte
count       ;EQU    019h    ;Stores the time the button is pressed
button      ;EQU    01Ah    ;The number of button that is pressed
startup     ;EQU    01Bh    ;Indicates if it's the startup state
timer       ;EQU    01Ch    ;Counts time before storing the station
need_save   ;EQU    01Dh    ;Indicates if current station need to be saved
;#################################################
_count      ;EQU    02Fh    ;Saved value of the timer
_byte_count ;EQU    030h    ;Counter of processed bytes
_bit_count  ;EQU    031h    ;Counter of processed bits
_port       ;EQU    032h    ;Helper register to implement 1-wire and TWI
_color      ;EQU    019h    ;Stores the color of the RGB LED
_ir_data:4  ;EQU    01Ah    ;First IR byte
;#################################################
RAM_		
		endc

 if RAM_ > H'60'
 ERROR "File register usage overflow"
 endif

;#############################################################
; I/O PORT PINS ASSIGNMENT
;#############################################################
but_up      EQU    GP0	;3    ;Button Volume up/Next station
but_down    EQU    GP1	;0    ;Button Volume down/Previous station
ir          EQU    GP3  ;      IR Rx INPUT 38kHz TSOP 1838
scl         EQU    GP4	;1    ;SCL pin of the I2C
sda         EQU    GP5	;2    ;SDA pin of the I2C
;#############################################################

	ORG    0x00

	goto   INIT
    nop
    nop
    nop

;	ORG    0x04
    ORG    0004h

;    bcf INTCON, GIE
;    btfsc  INTCON, GPIF
; goto IR_Rx
;	goto   _LOOP
;	bsf INTCON, GPIE ;3;-> ENABLE the GPIO port change interrupt
;	bsf INTCON, GIE  ;7;-> ENABLE all interrupts
;///	goto LOOP ; RETFIE
 	RETFIE

INIT:
    bsf    STATUS,RP0
    call   H'3FF'
    movwf  OSCCAL
	MOVLW  ~((1<<T0CS)|(1<<NOT_GPPU)|(1<<PSA))
	MOVWF  OPTION_REG	;	/
;    bcf    STATUS,RP0

;    MOVLW  ~((1<<T0CS)|(1<<NOT_GPPU))
;    OPTION              ;Enable GPIO2 and pull-ups
;    MOVLW  0x3F;0x0F          ;Save 0x0F into 'port' register
;    MOVWF  port          ;It's used to switch SDA/SCL pins direction
;    TRIS   GPIO           ;Set all pins as inputs
;#############################################################
;EXAMPLE 3-1: INITIALIZING GPIO
;bcf STATUS,RP0 ;Bank 0
;clrf GPIO ;Init GPIO
;movlw 07h ;Set GP<2:0> to
;movwf CMCON ;digital IO
;bsf STATUS,RP0 ;Bank 1
;clrf ANSEL ;Digital I/O
;movlw 0Ch ;Set GP<3:2> as inputs
;movwf TRISIO ;and set GP<5:4,1:0> ;as outputs
;#############################################################
	bcf    STATUS,RP0 ;Bank 0
;//////	clrf   GPIO ;Init GPIO
	movlw  07h ;Set GP<2:0> to
	movwf  CMCON ;digital IO
;	bsf    STATUS,RP0 ;Bank 1
;#############################################################
;	bcf    STATUS,RP0 ;Bank 0
	bcf    VRCON, VREN ;VRCON-VOLTAGE REF CTRL REG (99h)
;#############################################################
;#############################################################
;PIE1 - PERIPHERAL INTERRUPT ENABLE REGISTER 1 (ADDRESS: 8Ch)

	bcf    PIE1, EEIE   ;7; Disables the EE write complete interrupt
	bcf    PIE1, ADIE   ;6; Disables the A/D converter interrupt
	bcf    PIE1, CMIE   ;3; Disables the A/D converter interrupt
	bcf    PIE1, TMR1IE ;0; Disables the TMR1 overflow interrupt
;#############################################################

 ifdef __12F675
   banksel ADCON0
	bcf    ADCON0, ADON
   banksel ANSEL
	CLRF   ANSEL		;SELECT ALL DIGITAL I/O
 endif

;	MOVLW	B'00111011'		;SELECT PULLUP RESISTORS
;	MOVWF	WPU		;	/
	MOVLW  B'00111011'		;SETUP IO DIRECTION
	MOVWF  TRISIO		;	/
;	MOVLW	B'10000000'	;LOAD OPTION REGISTER
				;BIT 7 - 0 = WEAK PULL-UPS ENABLED
				;BIT 6 - 1 = INTERRUPT ON RISING EDGE OF GP2 disabled
				;BIT 5 - 0 = TMR0 CLOCK SET TO GP2 PIN //disable
				;BIT 4 - 1 = TMR0 INC ON HIGH TO LOW 
				;BIT 3 - 1 = PRESCALER ASSIGNED TO WDT
				;BIT 2..1  = PRESCALER SET TO MAX

;	clrf   INTCON
;	bcf    INTCON, GIE
;   BCF	   STATUS,RP0	;SET BANK 0

;#############################################################
;IOC - INTERRUPT-ON-CHANGE GPIO REGISTER (ADDRESS: 96h)
;//	clrf   IOC       ; Clear all the 5 Bits of IOC register
;//	bsf    IOC, IOC3 ; Set the GP3 Pin for the IOC Enabled
;#############################################################
;#############################################################
;INTCON - INTERRUPT CONTROL REGISTER (ADDRESS: 0Bh OR 8Bh)
	bcf INTCON, GIE  ;7;-> Disables all interrupts
	bcf INTCON, PEIE ;6;   Disables all peripheral interrupts
	bcf INTCON, T0IE ;5;   Disables the TMR0 interrupt
	bcf INTCON, INTE ;4;   Disables the GP2/INT external interrupt
	bcf INTCON, GPIE ;3;-> ENABLE/Disables the GPIO port change interrupt
	bcf INTCON, GIE  ;7;-> ENABLE/Disables all interrupts
;bcf INTCON, T0IF ;2; TMR0 register did not overflow
;#############################################################
;#############################################################

    MOVLW  0xFF          ;Perform 200 ms delay
    CALL   DELAY          ;to let the power stabilize
;#######################################################################

    MOVLW  0xFF          ;Perform 400 ms delay
    CALL   DELAY         ;to let the power stabilize
    MOVLW  0xFF          ;Perform 600 ms delay
    CALL   DELAY         ;to let the power stabilize
    MOVLW  0xFF          ;Perform 800 ms delay
    CALL   DELAY         ;to let the power stabilize
;#######################################################################

    CLRF   GPIO           ;Clear GPIO to set all pins to 0
    CLRF   need_save      ;No need to save the station for now
    BSF    startup, 0      ;Set 'startup' to 1 to indicate startup state
;#######################################################################

LOAD_EEPROM:
	clrf   Loc_Ptr	      ;00<- Loc_Ptr to Volume Information
	call   READ_EEPROM	  ;read the Volume information stored
    movwf  volume         ;And store it into 'volume' register

	incf   Loc_Ptr,f	  ;01<- Loc_Ptr to Channel Freq Information
	call   READ_EEPROM	  ;Read the Channel Frequency Low Byte Info
    movwf  frequency_l    ;and store its content into 'frequency_l'

	incf   Loc_Ptr,f	  ;02<- Loc_Ptr to Channel Freq Information
	call   READ_EEPROM    ;Read the Channel Frequency High Byte Info
    movwf  frequency_h    ;and store its content into 'frequency_h'
;#######################################################################

    MOVLW  0xC0           ;Implement AND operation between 0xC0
    ANDWF  frequency_l, F ;and 'frequency_l' to clear its last 6 bits
    BSF    frequency_l, 4 ;Set bit 4 (Tune) to adjust the frequency

START_RADIO:
                          ;Start FM radio
    CALL   I2C_START      ;Issue I2C Start condition
    MOVLW  0x20           ;Radio chip address for sequential writing is 0x20
    CALL   I2C_WRITE_BYTE ;Write the radio address via i2C
    MOVLW  0xC0           ;Write high byte into radio register 0x02
    CALL   I2C_WRITE_BYTE
    MOVLW  0x01           ;Write low byte into radio register 0x02
    CALL   I2C_WRITE_BYTE
    MOVF   frequency_h, W ;Write high byte into radio register 0x03
    CALL   I2C_WRITE_BYTE
    MOVF   frequency_l, W ;Write low byte into radio register 0x03
    CALL   I2C_WRITE_BYTE
    CALL   I2C_STOP       ;Issue I2C Stop condition

    MOVLW  0x0F         ;Implement AND operation between 0xC0
    ANDWF  volume, F    ;and 'volume' to clear its higher 4 bits
    BSF    volume, 7    ;Set bit 7  to select correct LNA input
    GOTO   SET_VOLUME   ;And go to the 'SET_VOLUME' label

LOOP:                   ;Main loop of the program
                        ;Beginning of the button 1 checking
;// bsf INTCON, GPIE ;3;-> ENABLE the GPIO port change interrupt
;// bsf INTCON, GIE  ;7;-> ENABLE all interrupts
    CALL   CHECK_BUTTONS  ;Read the buttons state
    ANDLW  3             ;Clear all the bits of the result except two LSBs
    BTFSC  STATUS, Z     ;If result is 0 (none of buttons were pressed)
    GOTO   WAIT_FOR_TIMER ;Then go to the 'WAIT_FOR_TIMER' label 
    MOVLW  .40            ;Otherwise load initial value for the delay  
    CALL   DELAY          ;and perform the debounce delay
    CALL   CHECK_BUTTONS  ;Then check the buttons state again
    ANDLW  3
    BTFSC  STATUS, Z     ;If result is 0 (none of buttons were pressed)
    GOTO   WAIT_FOR_TIMER ;Then go to the 'WAIT_FOR_TIMER' label
    MOVWF  button        ;Save the W value into the 'button'
    CLRF   count          ;clear loop counter

BUTTONS_LOOP:           ;Loop while button is pressed
    MOVLW  0xFF          ;Load initial value for the delay 200ms
    CALL   DELAY          ;And perform the delay
    CALL   CHECK_BUTTONS  ;Then check the buttons state again
    ANDLW  3
    BTFSC  STATUS, Z     ;If state is 0 (it was a short press)
    GOTO   CHANNEL_SEEK    ;Go to the 'CHANNEL_SEEK' label
    INCF   count, F       ;Otherwise (long press) increment the counter
    BTFSS  button, 0     ;Check the last bit of the 'button' register
    GOTO   DECREASE_VOLUME;If it's 0 (Down), go to 'DECREASE_VOLUME'

INCREASE_VOLUME:        ;Otherwise start 'INCREASE_VOLUME'
    INCF   volume, F      ;Increment the 'volume' register
    BTFSC  volume, 4     ;If bit 4 becomes set (volume = 0b10010000)
    DECF   volume, F      ;then decrement the 'volume' to get 0b10001111
    GOTO   SET_VOLUME     ;and go to the 'SET_VOLUME' label

DECREASE_VOLUME:        ;Decrease the volume here
    DECF   volume, F      ;Decrement the 'volume' register
    BTFSS  volume, 7     ;If bit 7 becomes 0 (volume = 0b01111111)
    INCF   volume, F      ;then increment the 'volume' to get 0b10000000

SET_VOLUME:               ;Set the radio volume
    CALL   I2C_START      ;Issue I2C start condition
    MOVLW  0x22           ;Radio chip address for random writing is 0x22
    CALL   I2C_WRITE_BYTE ;Write the radio address via I2C
    MOVLW  0x05           ;Set the register number to write to (0x05)
    CALL   I2C_WRITE_BYTE ;And write it via I2C
    MOVLW  0x88           ;Set the high byte of 0x05 register (default value)
    CALL   I2C_WRITE_BYTE ;And write it via i2C
    MOVF   volume, W      ;Set the 'volume' as low byte of 0x05 register
    CALL   I2C_WRITE_BYTE ;And write it via I2C
    CALL   I2C_STOP       ;Issue Stop condition
    BTFSS  startup, 0     ;If 'startup' is 0 (not startup condition)
    GOTO   BUTTONS_LOOP   ;Then return to the 'BUTTONS_LOOP' label
    BCF    startup, 0     ;Otherwise reset the 'startup' register
; bcf INTCON, GPIE ;3;-> ENABLE the GPIO port change interrupt
; bcf INTCON, GIE  ;7;-> ENABLE all interrupts
; clrf _ir_data
    GOTO   LOOP           ;And return to the 'LOOP' label

CHANNEL_SEEK:             ;Here button is released and we check what to do
    MOVF   count, F       ;Check if 'count' register is 0
    BTFSS  STATUS, Z      ;If 'count' is not 0 (it was a long press)
    GOTO   SAVE_VOLUME    ;then go to the 'SAVE VOLUME' label
    CLRF   timer          ;Otherwise (short press) we clear the 'timer'
    BSF    need_save, 0   ;And set the 'need_save' register

CH_UP:
    CALL I2C_START      ;Issue I2C Start condition
    MOVLW 0x20          ;Radio chip address for sequential writing is 0x20
    CALL I2C_WRITE_BYTE ;Write the radio address via I2C
    BTFSS button, 0     ;Check the last bit of the 'button' register
    GOTO SEEK_DOWN      ;If it's 0 (button Down), go to 'SEEK_DOWN' label
    MOVLW 0xC3          ;Otherwise set 0xC3 as high byte of 0x02 register
    CALL I2C_WRITE_BYTE ;And write it via I2C
    MOVLW 0x01          ;Set 0x01 as low byte of 0x02 register
    CALL I2C_WRITE_BYTE ;And write it via I2C
    CALL I2C_STOP       ;Issue I2C Stop condition
; bcf INTCON, GPIE ;3;-> ENABLE the GPIO port change interrupt
; bcf INTCON, GIE  ;7;-> ENABLE all interrupts
; clrf _ir_data
    GOTO WAIT_FOR_TIMER ;And go to the 'WAIT_FOR_TIMER' label

SEEK_DOWN:              ;Seek the station down
    MOVLW 0xC1          ;Set 0xC1 as high byte of 0x02 register
    CALL I2C_WRITE_BYTE ;Ending of previous transaction
    MOVLW 0x01          ;Set 0x01 as low byte of 0x02 register
    CALL I2C_WRITE_BYTE ;And write it via I2C
    CALL I2C_STOP       ;Issue I2C Stop condition
    GOTO WAIT_FOR_TIMER ;And go to the 'WAIT_FOR_TIMER' label
;####################################################################

SAVE_VOLUME:
	clrf   Loc_Ptr	      ;ADDRESS to 0x00
	MOVFW  volume	      ;Move Volume value to W Register
	call   WRITE_EEPROM   ;Write current Volume into EEPROM
;####################################################################

WAIT_FOR_TIMER:           ;Wait for 10 second to save the channel to EEPROM
    MOVLW  45             ;Set the delay about 40 ms
    CALL   DELAY          ;And call the DELAY subroutine
    INCFSZ timer, F       ;Increase the 'timer' and check while it becomes 0
    GOTO   LOOP           ;If it's not 0 then return to the 'LOOP' label

    BTFSS  need_save, 0   ;Otherwise check the 'need_save' register
    GOTO   LOOP           ;If it's 0 then return to the 'LOOP' register
    BCF    need_save, 0   ;Otherwise clear the 'need_save' register
    CALL   I2C_START      ;Issue I2C start condition
    MOVLW  0x22           ;Set the radic chip address for random writing
    CALL   I2C_WRITE_BYTE ;And write it via I2C
    MOVLW  0x03           ;Set the radio register to read from (0x03)
    CALL   I2C_WRITE_BYTE ;And write it via I2C
    CALL   I2C_START      ;Issue I2C Repeated start condition
    MOVLW  0x23           ;Set the radio chip address for random reading
    CALL   I2C_WRITE_BYTE ;And write it via I2C
    CALL   I2C_READ_BYTE  ;Read the high byte of the register 0x03
    CALL   I2C_ACK        ;Issue the Acknowledgement
    MOVF   i2c_data, W    ;Copy the 'i2c_data' content into W register
    MOVWF  frequency_h    ;And save it to the 'frequency_h' register
    CALL   I2C_READ_BYTE  ;Read the low byte of the register 0x03
    CALL   I2C_NACK       ;Issue the Not acknowledgement
    MOVF   i2c_data, W    ;Copy the 'i2c_data' content into W register
    MOVWF  frequency_l    ;And save it to the 'frequency_l' register
    CALL   I2C_STOP       ;Issue I2C stop condition
;#############################################################################

SAVE_CH:
	clrf   Loc_Ptr		  ;0x00
	incf   Loc_Ptr,f	  ;0x01
	MOVF   frequency_l,W  ;0x01
	call   WRITE_EEPROM
	incf   Loc_Ptr,f	  ;0x02
	BCF    frequency_h,7
	MOVF   frequency_h,W
	call   WRITE_EEPROM
;#############################################################################

    GOTO LOOP           ;loop forever
;-------------Check buttons---------------
CHECK_BUTTONS:
;#############################################################
;INTCON - INTERRUPT CONTROL REGISTER (ADDRESS: 0Bh OR 8Bh)
;	bsf INTCON, GPIE ;3;-> ENABLE the GPIO port change interrupt
;	bsf INTCON, GIE  ;7;-> ENABLE all interrupts
;	bcf INTCON, PEIE ;6;   Disables all peripheral interrupts
;	bcf INTCON, T0IE ;5;   Disables the TMR0 interrupt
;	bcf INTCON, INTE ;4;   Disables the GP2/INT external interrupt
;	bsf INTCON, GPIE ;3;-> ENABLE the GPIO port change interrupt
;bcf INTCON, T0IF ;2; TMR0 register did not overflow
;#############################################################


    BTFSS GPIO, but_up  ;Check if button Up is pressed
    RETLW 1             ;and return 1 (b'01')
    BTFSS GPIO, but_down;Check if button Down is pressed
    RETLW 2             ;and return 2 (b'10')
;// goto _LOOP ;///140522////////
;//CONTINUE:
; btfss GPIO, GP3
; goto IR_Rx
    RETLW 0             ;If none of buttons is pressed then return 0
;-------------Helper subroutines---------------
SDA_HIGH:               ;Set SDA pin high
    BSF port, sda       ;Set 'sda' bit in the 'port' to make it input
    MOVF port, W        ;Copy 'port' into W register
    TRIS GPIO           ;And set it as TRISGPIO value
    RETLW 0

SDA_LOW:                ;Set SDA pin low
    BCF port, sda       ;Reset 'sda' bit in the 'port' to make it output
    MOVF port, W        ;Copy 'port' into W register
    TRIS GPIO           ;And set it as TRISGPIO value
    RETLW 0

SCL_HIGH:               ;Set SCL pin high
    BSF port, scl       ;Set 'scl' bit in the 'port' to make it input
    MOVF port, W        ;Copy 'port' into W register
    TRIS GPIO           ;And set it as TRISGPIO value
    RETLW 0

SCL_LOW:                ;Set SCL pin low
    BCF port, scl       ;Reset 'scl' bit in the 'port' to make it output
    MOVF port, W        ;Copy 'port' into W register
    TRIS GPIO           ;And set it as TRISGPIO value
    RETLW 0

;-------------I2C start condition--------------
I2C_START:
    CALL SCL_HIGH       ;Set SCL high
    CALL SDA_LOW        ;Then set SDA low
    RETLW 0
;-------------I2C stop condition---------------
I2C_STOP:
    CALL SDA_LOW        ;Set SDA low
    CALL SCL_HIGH       ;Set SCL high
    CALL SDA_HIGH       ;Then set SDA highs and release the bus
    RETLW 0
;------------I2C write byte--------------------
I2C_WRITE_BYTE:
    MOVWF i2c_data      ;Load 'i2c_data' from W register
    MOVLW 8             ;Load value 8 into 'bit_count'
    MOVWF bit_count     ;to indicate we're going to send 8 bits
I2C_WRITE_BIT:          ;Write single bit to I2C
    CALL SCL_LOW        ;Set SCL low, now we can change SDA
    BTFSS i2c_data, 7   ;Check the MSB of 'i2c_data'
    GOTO I2C_WRITE_0    ;If it's 0 then go to the 'I2C_WRITE_0' label
I2C_WRITE_1:            ;Else continue with 'I2C_WRITE_1'
    CALL SDA_HIGH       ;Set SDA high
    GOTO I2C_SHIFT      ;And go to the 'I2C_SHIFT' label
I2C_WRITE_0:
    CALL SDA_LOW        ;Set SDA low
I2C_SHIFT:
    CALL SCL_HIGH       ;Set SCL high to start the new pulse
    RLF i2c_data, F     ;Shift 'i2c_data' one bit to the left
    DECFSZ bit_count, F ;Decrement the 'bit_count' value, check if it's 0
    GOTO I2C_WRITE_BIT  ;If not then return to the 'I2C_WRITE_BIT'
I2C_CHECK_ACK:          ;Else check the acknowledgement bit
    CALL SCL_LOW        ;Set I2C low to end the last pulse
    CALL SDA_HIGH       ;Set SDA high to release the bus
    CALL SCL_HIGH       ;Set I2C high to start the new pulse
    MOVF GPIO, W        ;Copy the GPIO register value into the 'ack'
    MOVWF ack           ;Now bit 'sda' of the 'ack' will contain ACK bit
    CALL SCL_LOW        ;Set SCL low to end the acknowledgement bit
    RETLW 0
;------------I2C read byte--------------------
I2C_READ_BYTE:
    MOVLW 8             ;Load value 8 into 'bit_count'
    MOVWF bit_count     ;to indicate we're going to receive 8 bits
    CLRF i2c_data       ;Clear the 'i2c_data' register
I2C_READ_BIT:           ;Read single bit from the I2C
    RLF i2c_data, F     ;Shift the 'i2c_data' register one bit to the left
    CALL SCL_LOW        ;Set SCL low to prepare for the new bit
    CALL SCL_HIGH       ;Set SCL high to read the bit value
    BTFSC GPIO, sda     ;Check the 'sda' bit in the GPIO register
    BSF i2c_data, 0     ;if it's 1 then set the LSB of the 'i2c_data'
    DECFSZ bit_count, F ;Decrement the 'bit_count' value, check if it's 0
    GOTO I2C_READ_BIT   ;If not, then return to the 'I2C_READ_BIT'
    CALL SCL_LOW        ;Set SCL low to end the last pulse
    RETLW 0             ;Otherwise return from the subroutine
;----------I2C send ACK----------------------
I2C_ACK:
    CALL SDA_LOW        ;Set SDA low to issue ACK condition
    CALL SCL_HIGH       ;Set SCL high to start the new pulse
    CALL SCL_LOW        ;Set SCL low to end the pulse
    CALL SDA_HIGH       ;Set SDA high to release the bus
    RETLW 0
;----------I2C send NACK----------------------
I2C_NACK:
    CALL SDA_HIGH       ;Set SDA low to issue NACK condition
    CALL SCL_HIGH       ;Set SCL high to start the new pulse
    CALL SCL_LOW        ;Set SCL low to end the pulse
    RETLW 0

;-------------Delay subroutine--------------
DELAY:                   ;Start DELAY subroutine here  
    MOVWF  DC1           ;Copy the value to the register i
    MOVWF  DC2           ;Copy the value to the register j
DELAY_LOOP:              ;Start delay loop
 btfss GPIO, GP3
 goto IR_Rx
    DECFSZ DC1, F        ;Decrement i and check if it is not zero
    GOTO   DELAY_LOOP    ;If not, then go to the DELAY_LOOP label
    DECFSZ DC2, F        ;Decrement j and check if it is not zero
    GOTO   DELAY_LOOP    ;If not, then go to the DELAY_LOOP label
    RETLW  0             ;Else return from the subroutine
;------------------------------------------------------------------------------
; writes the EEPROM using W Register
;------------------------------------------------------------------------------
WRITE_EEPROM:
    bsf    STATUS,RP0
    movwf  EEDATA
    movfw  Loc_Ptr 	;//////////////////////////////////
    movwf  EEADR 	;//////////////////////////////////
    movfw  EEDATA
    bsf    EECON1,RD
    xorwf  EEDATA 	;//////////destination?////////////
    bz     write2
    movwf  EEDATA
    bsf    EECON1,WREN
    bcf    INTCON,GIE ;Disable INTs
    movlw  0x55 	;//////////////////////////////////
    movwf  EECON2 	;//////////////////////////////////
    movlw  0xAA 	;//////////////////////////////////
    movwf  EECON2 	;//////////////////////////////////
	bsf    EECON1,WR
    bsf    INTCON,GIE ;Enable INTS
write1:
    btfsc  EECON1,WR
    goto   write1
    bcf    EECON1,WREN
write2: 
	bcf    STATUS,RP0
    return
;------------------------------------------------------------------------------
; reads the EEPROM into W Register
;------------------------------------------------------------------------------
READ_EEPROM:
    bsf    STATUS,RP0
    movfw  Loc_Ptr  ;///////////////////////////////////////
    movwf  EEADR 	;////////////////////////////////////
    bsf    EECON1,RD
    movfw  EEDATA
    bcf    STATUS,RP0
    return
;------------------------------------------------------------------------------
;##############################################################################
IR_Rx:	    ;---IR REMOTE CONTROL 38kHz ROUTINE--------------------------------
;##############################################################################

_LOOP:                    ;Main loop of the program
;---------------Wait for the preamble positive pulse---------------------
    BTFSC GPIO, ir       ;Wait while 'ir' pin goes down
    GOTO _LOOP           ;If it's high then return to 'LOOP'
;///    GOTO CONTINUE ; //LOOP           ;If it's high then return to 'LOOP'
INT_JMP:
    CLRF  TMR0           ;Otherwise clear the timer register
    BTFSS GPIO, ir       ;And wait while 'ir' is low
    GOTO  $-1
    MOVF  TMR0, W        ;Copy the TMR0 value into the W register
    MOVWF _count         ;and save the value into the 'count' register
    MOVLW d'30'          ;Load 30 into W (256 us x 32 = 7.7 ms)
    SUBWF _count, W      ;And subtract W from 'count'
    BTFSS STATUS, C      ;If 'count' < 30 (pulse is shorter than 7.7 ms)
    GOTO  _LOOP          ;then return to 'LOOP'
    MOVLW d'45'          ;Load 45 into W (256 us x 45 = 11.5 ms)
    SUBWF _count, W      ;And subtract W from 'count'
    BTFSC STATUS, C      ;If 'count' > 45 (pulse is longer than 8 ms)
    GOTO _LOOP           ;then return to 'LOOP'
;---------------Check the preamble negative pulse---------------------
    CLRF TMR0            ;Otherwise clear the timer register
    BTFSC GPIO, ir       ;And wait while 'ir' is high
    GOTO $-1
    MOVF TMR0, W         ;Copy the TMR0 value into the W register
    MOVWF _count         ;and save the value into the 'count' register
    MOVLW d'13'          ;Load 15 into W (256 us x 13 = 3.3 ms)
    SUBWF _count, W      ;And subtract W from 'count'
    BTFSS STATUS, C      ;If 'count' < 13 (pulse is shorter than 3.3 ms)
    GOTO _LOOP           ;then return to 'LOOP'
    MOVLW d'20'          ;Load 20 into W (256 us x 20 = 5.1 ms)
    SUBWF _count, W      ;And subtract W from 'count'
    BTFSC STATUS, C      ;If 'count' > 20 (pulse is longer than 5.1 ms)
    GOTO _LOOP           ;then return to 'LOOP'
;---------------Receive the command bytes-----------------------------
    CLRF _byte_count     ;Clear the 'byte_count' register    
    MOVLW _ir_data       ;Load the address of the 'ir_data' into W
    MOVWF FSR            ;and save it to the indirect pointer register
_RECEIVE_BYTE:
    CLRF _bit_count      ;Clear the 'bit_count' register
    CLRF INDF            ;Clear the indirectly addressed register
_RECEIVE_BIT:
    RRF INDF, F          ;Shift the INDF register to the right
;---------------Receive the positive pulse of the bit-----------------
    CLRF TMR0           ;Otherwise clear the timer register
    BTFSS GPIO, ir      ;And wait while 'ir' is low
    GOTO $-1
    MOVF TMR0, W        ;Copy the TMR0 value into the W register
    MOVWF _count         ;and save the value into the 'count' register
    MOVLW 1             ;Load 1 into W (256 us x 1 = 0.26 ms)
    SUBWF _count, W      ;And subtract W from 'count'
    BTFSS STATUS, C     ;If 'count' < 1 (pulse is shorter than 0.26 ms)
    GOTO _LOOP           ;then return to 'LOOP'
    MOVLW 3             ;Load 3 into W (256 us x 3 = 0.77 ms)
    SUBWF _count, W      ;And subtract W from 'count'
    BTFSC STATUS, C     ;If 'count' > 3 (pulse is longer than 0.77 ms)
    GOTO _LOOP           ;then return to 'LOOP'
;---------------Receive the negative pulse of the bit-----------------
    CLRF TMR0           ;Otherwise clear the timer register
    BTFSC GPIO, ir      ;And wait while 'ir' is high
    GOTO $-1
    MOVF TMR0, W        ;Copy the TMR0 value into the W register
    MOVWF _count         ;and save the value into the 'count' register
    MOVLW 4;///////////             ;Load 5 into W (256 us x 4 = 1.1 ms)
    SUBWF _count, W      ;And subtract W from 'count'
    BTFSS STATUS, C     ;If 'count' < 4 (pulse is shorter than 1.1 ms)
    GOTO _NEXT_BIT       ;then go to the 'NEXT_BIT' label
    MOVLW 8             ;Load 8 into W (256 us x 8 = 2 ms)
    SUBWF _count, W      ;And subtract W from 'count'
    BTFSC STATUS, C     ;If 'count' > 8 (pulse is longer than 2 ms)
    GOTO _LOOP           ;then go to the 'LOOP' label
    BSF INDF, 7         ;Set the MSB of the INDF register
_NEXT_BIT:
    INCF   _bit_count, F   ;Increment the 'bit_count' register
    BTFSS  _bit_count, 3   ;Check if 'bit_count' becomes 8
    GOTO   _RECEIVE_BIT    ;If it's not, then return to 'RECEIVE_BIT' label
    INCF   _byte_count, F  ;Increment the 'byte_count' register
    BTFSC  _byte_count, 2  ;Check if 'byte_count' becomes 4    
    GOTO   _CHECK_DATA     ;If it is then go to 'CHECK_DATA' label
    INCF   FSR, F          ;Increment the indirect addressing pointer
    GOTO   _RECEIVE_BYTE   ;and go to 'RECEIVE_BYTE' label

_CHECK_DATA:
    COMF _ir_data+1, W   ;Negate the second received byte
    XORWF _ir_data, W    ;And implement the XOR between 1st and 2nd bytes
    BTFSS STATUS, Z      ;If the result is not 0 (bytes are not equal)
    GOTO _LOOP           ;<--Then return to the 'LOOP' label
    COMF _ir_data+3, W   ;Negate the fourth received byte
    XORWF _ir_data+2, W  ;And implement the XOR between 3rd and 4th bytes
    BTFSS STATUS, Z      ;If the result is not 0 (bytes are not equal)
    GOTO _LOOP           ;<--Then return to the 'LOOP' label

    MOVLW 0x05;//////////0x09          ;Check the R button (code 0x09)
    XORWF _ir_data+2, W  ;If command is not 0x09
    BTFSS STATUS, Z
    GOTO $+2            ;then skip the next three lines
	goto DECREASE_VOLUME

    MOVLW 0x06;///////////8          ;Check the G button (code 0x08)
    XORWF _ir_data+2, W  ;If command is not 0x08
    BTFSS STATUS, Z
    GOTO $+2            ;then skip the next three lines
	goto INCREASE_VOLUME

    MOVLW 0x02;//////7;A          ;Check the B button (code 0x0A)
    XORWF _ir_data+2, W  ;If command is not 0x0A
    BTFSS STATUS, Z
    GOTO $+3            ;then skip the next three lines
    bsf button,0
	goto CH_UP ;///////////////////

    MOVLW 0x03;//////////B          ;Check the W button (code 0x0B)
    XORWF _ir_data+2, W  ;If command is not 0x0B
    BTFSS STATUS, Z
    GOTO $+3            ;then skip the next three lines
	bcf button,0
	goto CH_UP ;////////////////////////
; clrf _ir_data
; clrf _ir_data+1
; clrf _ir_data+2
; clrf _ir_data+3
;//	bsf INTCON, GPIE ;3;-> ENABLE the GPIO port change interrupt
;//	bsf INTCON, GIE  ;7;-> ENABLE all interrupts

; retfie
    GOTO LOOP           ;loop forever

    END                   ;/* END of the Program */.