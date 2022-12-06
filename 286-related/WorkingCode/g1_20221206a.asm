; Last updated 30 NOV 2022
; Latest update: SD Card reader (SPI)
; Assembler: NASM
;
; *physical memory map*
; -----------------------
; -    ROM  (256 KB)    -
; -   0xC0000-0xFFFFF   -
; -----------------------
; -   VIDEO  (128 KB)   -
; -   0xA0000-0xBFFFF   -
; -----------------------
; -    RAM  (640 KB)    -
; -   0x00000-0x9FFFF   -
; -----------------------
;
; Additional Comments
; PPI/LCD code adapted from "The 80x86 IBM PC and Compatible Computers..., 4th Ed." -- Mazidi & Mazidi
; Sample interrupt code adapted from https://stackoverflow.com/questions/51693306/registering-interrupt-in-16-bit-x86-assembly
; Sample interrupt code adapted from "The 80x86 IBM PC and Compatible Computers..., 4th Ed." -- Mazidi & Mazidi
; https://tiij.org/issues/issues/fall2006/32_Jenkins-PIC/Jenkins-PIC.pdf
; 80286 Hardware Reference Manual, pg. 5-20
; http://www.nj7p.org/Manuals/PDFs/Intel/121500-001.pdf
;
; SPI SD Card routines
; Using HiLetgo Micro SD TF Card Reader - https://www.amazon.com/gp/product/B07BJ2P6X6
; Core logic adapted from George Foot's awesome page at https://hackaday.io/project/174867-reading-sd-cards-on-a-65026522-computer
; https://developpaper.com/sd-card-command-details/
; https://www.kingston.com/datasheets/SDCIT-specsheet-64gb_en.pdf

; ! to do !
; -routine to set specific CS low
; -routine to bring all CS high
; -constants for Nano SPI commands
; -consolidation of similar procedures
; -improved code commenting
; -...

cpu		286
bits 	16

section .data

	ivt		times 1024	db	0xaa			; prevent writing in the same space as the IVT

	;PPI1 (1602 LCD)						BUS_ADDR (BUS addresses are shifted one A2-->pin A1, A1-->pin A0)
	;Base address: 0x00E0					11100000
	;PPI1 pin values
	;A1=0, A0=0		PORTA					11100000	0x00E0
	;A1=0, A0=1		PORTB					11100010	0x00E2
	;A1=1, A0=0		PORTC					11100100	0x00E4
	;A1=1, A0=1		CONTROL REGISTER		11100110	0x00E6

	PPI1_PORTA	equ	0x00E0
	PPI1_PORTB	equ	0x00E2
	PPI1_PORTC	equ 0x00E4
	PPI1_CTL	equ	0x00E6

	;PPI2 (PS/2 Keyboard)
	PPI2_PORTA	equ	0x00E8
	PPI2_PORTB	equ	0x00EA
	PPI2_PORTC	equ 0x00EC
	PPI2_CTL	equ	0x00EE
	
	
	; ***** PPI1 Configuration *****
	;							1=I/O Mode	|	00=Mode 0	|	1=PA In		|	0=PC (upper 4) Out	|	0=Mode 0	|	0=PB Out	|	0=PC (lower 4) Out
	CTL_CFG_PA_IN		equ		0b10010000		;0x90

	;							1=I/O Mode	|	00=Mode 0	|	0=PA Out	|	0=PC (uppper 4) Out	|	0=Mode 0	|	0=PB Out	|	0=PC (lower 4) Out
	CTL_CFG_PA_OUT		equ		0b10000000		;0x80

	;							1=I/O Mode	|	00=Mode 0	|	0=PA Out	|	0=PC (uppper 4) Out	|	0=Mode 0	|	1=PB In		|	0=PC (lower 4) Out
	CTL_CFG_PB_IN		equ		0b10000010		;0x82


	RS	equ 0b00000001
	RW 	equ 0b00000010
	E 	equ 0b00000100

	; ***** Interrupt Controller *****
	;Base address: 0x0010		;BUS_A1 connected to pin A0 of PIC
	PICM_P0		equ	0x0010		;PIC Master Port 0		ICW1				OCW2, OCW3
	PICM_P1		equ	0x0012		;PIC Master Port 1		ICW2, ICW3, ICW4	OCW1

	KBD_BUFSIZE equ 32					; Keyboard Buffer length. Must be a power of 2
	KBD_IVT_OFFSET equ 9*4				; Base address of keyboard interrupt (IRQ) in IVT  // 9*4=36=0x24
										; Keyboard: IRQ1, INT number 0x09 (* 4 bytes per INT)

	RELEASE		equ		0b0000000000000001
    SHIFT		equ		0b0000000000000010

	kb_flags	dw		0x0

	;R			dd		9.75			;411c0000 = 9.75		In ROM: 00001C41
	AREA	dd		0x0	


	VIA1_PORTB	equ		0x0020			; read and write to port pins on port B
    VIA1_PORTA	equ		0x0022			; read and write to port pins on port A
    VIA1_DDRB	equ		0x0024			; configure read/write on port B
    VIA1_DDRA	equ		0x0026			; configure read/write on port A
	VIA1_IER	equ		0x003c			; modify interrupt information, such as which interrupts are processed

	SPI_MISO    equ		0b00000001     
	SPI_MOSI    equ		0b00000010     
	SPI_CLK     equ		0b00000100     
											; support for 5 SPI devices per VIA port
											; *** PORT B ***								*** PORT A ***
	SPI_CS1     equ		0b10000000			; 8-digit 7-segment display						Arduino Nano serial output
	SPI_CS2		equ		0b01000000			; SD card										tbd
	SPI_CS3		equ		0b00100000			; tbd											tbd
	SPI_CS4		equ		0b00010000			; tbd											tbd
	SPI_CS5		equ		0b00001000			; tbd											tbd

	spi_state_b	db		0x0					; track CS state for spi on via port b
	spi_state_a	db		0x0					; track CS state for spi on via port a

	marker		times 32	db	0xbb			; for visibility in the rom
	dataend:

;section .bss

section .text

;org		0x0000		; 0xC000
top:				; physically at 0xC0000

;*** SETUP REGISTERS **********************************
xor		ax,	ax
mov		ds, ax
mov		sp,	ax				; Start stack pointer at 0. It will wrap around (down) to FFFE.
mov		ax,	0x0040			; First 1K is reserved for interrupt vector table,
mov		ss,	ax				; Start stack segment at the end of the IVT.
mov		ax, 0xf000			; Read-only data in ROM at 0x30000 (0xf0000 in address space)
mov		es,	ax				; extra segment

;*** /SETUP REGISTERS *********************************

cli					; disable interrupts
call	lcd_init
call	print_message
call	pic_init
call	spi_init
call	spi_sdcard_init
call	spi_8char7seg_init

mov		ax,	0x0600						; cmd06 = OLED init / reset, no param
call	spi_send_NanoSerialCmd
call	delay

mov		ax,	0x0801						; cmd08 = print status, 1 = RAM test begin
call	spi_send_NanoSerialCmd
;call	Test_RAM
mov		ax,	0x0802						; cmd08 = print status, 2 = RAM test finish
call	spi_send_NanoSerialCmd
mov		ax,	0x0803						; cmd08 = print status, 3 = PIC1 test begin
call	spi_send_NanoSerialCmd
mov		ax,	0x0804						; cmd08 = print status, 4 = PIC1 test finish
call	spi_send_NanoSerialCmd
mov		ax,	0x0805						; cmd08 = print status, 5 = PIC2 test begin
call	spi_send_NanoSerialCmd
mov		ax,	0x0806						; cmd08 = print status, 6 = PIC2 test finish
call	spi_send_NanoSerialCmd
mov		ax,	0x0807						; cmd08 = print status, 7 = VIA1 test begin
call	spi_send_NanoSerialCmd
mov		ax,	0x0808						; cmd08 = print status, 8 = VIA1 test finish
call	spi_send_NanoSerialCmd
mov		ax,	0x0809						; cmd08 = print status, 9 = MathCo test begin
call	spi_send_NanoSerialCmd
mov		ax,	0x080A						; cmd08 = print status, 10 (0x0A) = MathCo test finish
call	spi_send_NanoSerialCmd
mov		ax,	0x0832						; cmd08 = print status, 50 (0x32) = POST complete
call	spi_send_NanoSerialCmd

sti										; Enable interrupts

call	play_sound

.main_loop:
	jmp .main_loop


spi_sdcard_init:

	mov		bx,		msg_sdcard_init
	call	print_string_to_serial

	call	delay			;remove? ...test
	call	delay


	; using SPI mode 0 (cpol=0, cpha=0)
	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; SPI_CS2 high (not enabled), start with MOSI high and CLK low
	out		VIA1_PORTB,		al	
	
	;call	delay

	mov		si,				0x00a0			;80 full clock cycles to give card time to initiatlize
	.init_loop:
		xor		al,				SPI_CLK
		out		VIA1_PORTB,		al
		nop									; nops might not be needed... test reducing/removing
		nop
		nop
		nop
		dec		si
		cmp		si,				0    
		jnz		.init_loop

	;call	delay
    .try00:
		mov		bx,		msg_sdcard_try00
		call	print_string_to_serial

		mov		bx,		cmd0_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

        ; Expect status response 0x01 (not initialized)
		cmp		al,		0x01
		jne		.try00

		mov		bx,		msg_sdcard_try00_done
		call	print_string_to_serial


		mov		bx,		msg_garbage
		call	print_string_to_serial

	call	delay

	.try08:

		mov		bx,		msg_sdcard_try08
		call	print_string_to_serial

		mov		bx,		cmd8_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

        ; Expect status response 0x01 (not initialized)
		cmp		al,		0x01
		jne		.try08

		mov		bx,		msg_sdcard_try08_done
		call	print_string_to_serial
		
		call	spi_readbyte_port_b
		call	spi_readbyte_port_b
		call	spi_readbyte_port_b
		call	spi_readbyte_port_b

	.try55:
		mov		bx,		msg_sdcard_try55
		call	print_string_to_serial

		mov		bx,		cmd55_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

        ; Expect status response 0x01 (not initialized)
		cmp		al,		0x01
		jne		.try55

		mov		bx,		msg_sdcard_try55_done
		call	print_string_to_serial

	.try41:
		mov		bx,		msg_sdcard_try41
		call	print_string_to_serial

		mov		bx,		cmd41_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

        ; Expect status response 0x01 (not initialized)
		cmp		al,		0x00
		jne		.try55

		mov		bx,		msg_sdcard_try41_done
		call	print_string_to_serial

	.try18:
		mov		bx,		msg_sdcard_try18
		call	print_string_to_serial

		mov		bx,		cmd18_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand_noclose						; start reading SD card at 0x0

		
		;call	spi_readbyte_port_b	
		;cmp		al,		0xfe								; 0xfe = have data
		;jne		.nodata										; if data avail, continue, otherwise jump to .nodata

		call	spi_sdcard_readdata	

		mov		bx,		msg_sdcard_try18_done
		call	print_string_to_serial
	
		jmp		.out

	.nodata:
		mov		bx,		msg_sdcard_nodata
		call	print_string_to_serial
	
	.out:

		mov		bx,		msg_sdcard_init_out
		call	print_string_to_serial

	ret

spi_sdcard_readdata:
	;call	lcd_clear

	call	send_garbage
	mov		al,				(SPI_CS1|			SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; drop SPI_CS2 low to enable, start with MOSI high and CLK low
	mov		[spi_state_b],	al
	out		VIA1_PORTB,		al		
	call	send_garbage

	mov		si, 1024
	.loop:
		; first real data from card is the byte after 0xfe is read... usually the first byte
		call	spi_readbyte_port_b	
		; call	print_char_hex
		mov		ah,	0x02		; cmd02 = print hex
		call	spi_send_NanoSerialCmd
		dec		si
		jnz		.loop

		mov		ax,	0x010a		; cmd01 = print char - newline
		call	spi_send_NanoSerialCmd


	.out:
		call	send_garbage
		mov		al,				(SPI_CS1| SPI_CS2 |	SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; drop SPI_CS2 low to enable, start with MOSI high and CLK low
		mov		[spi_state_b],	al
		mov		bx,		cmd12_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

		mov		bx,		msg_sdcard_read_done
		call	print_string_to_serial
	ret

send_garbage:
	mov		bp,		0x08					; send 8 bits
	.loop:
		mov		al,				[spi_state_b]	; instead of 0, need to keep CS properly set when using multiple SPI devices		
	.clock:
		; remove the following line
		and		al,				~SPI_CLK	;0b11111011	 low clock			to do: invert SPI_CLK instead of 0b... value		--use ~
		
		out		VIA1_PORTB,		al			; set MOSI (or not) first with SCK low
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		or		al,				SPI_CLK		; high clock
		out		VIA1_PORTB,		al			; raise CLK keeping MOSI the same, to send the bit
		nop
		nop
		nop
		nop
		nop
		nop
		nop

		dec		bp
		jne		.loop						; loop if there are more bits to send

		; end on low clock
		mov		al,				[spi_state_b]	
		out		VIA1_PORTB,		al			
		
	ret

spi_sdcard_sendcommand:

	call	send_garbage
	mov		al,				(SPI_CS1|			SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; drop SPI_CS2 low to enable, start with MOSI high and CLK low
	mov		[spi_state_b],	al
	out		VIA1_PORTB,		al		
	call	send_garbage

	nop									; nops might not be needed... test reducing/removing
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	mov		al,				ES:[bx+1]
	;call	print_char_hex
	call	spi_writebyte_port_b

	mov		al,				ES:[bx]
	;call	print_char_hex
	call	spi_writebyte_port_b
	
	mov		al,				ES:[bx+3]
	;call	print_char_hex
	call	spi_writebyte_port_b
	
	;call	lcd_line2

	mov		al,				ES:[bx+2]
	;call	print_char_hex
	call	spi_writebyte_port_b
	
	mov		al,				ES:[bx+5]
	;call	print_char_hex
	call	spi_writebyte_port_b
	
	mov		al,				ES:[bx+4]
	;call	print_char_hex
	call	spi_writebyte_port_b

	;call	delay

	call	spi_waitresult
	push	ax				; save result

	;call	delay

	call	send_garbage
	mov		al,				(SPI_CS1| SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)	
	mov		[spi_state_b],	al
	out		VIA1_PORTB,		al	
	call	send_garbage

	pop		ax				; retrieve result

	.out:
  ret

  spi_sdcard_sendcommand_noclose:

	call	send_garbage
	mov		al,				(SPI_CS1|			SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; drop SPI_CS2 low to enable, start with MOSI high and CLK low
	mov		[spi_state_b],	al
	out		VIA1_PORTB,		al		
	call	send_garbage

	nop									; nops might not be needed... test reducing/removing
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	mov		al,				ES:[bx+1]
	;call	print_char_hex
	call	spi_writebyte_port_b

	mov		al,				ES:[bx]
	;call	print_char_hex
	call	spi_writebyte_port_b
	
	mov		al,				ES:[bx+3]
	;call	print_char_hex
	call	spi_writebyte_port_b
	
	;call	lcd_line2

	mov		al,				ES:[bx+2]
	;call	print_char_hex
	call	spi_writebyte_port_b
	
	mov		al,				ES:[bx+5]
	;call	print_char_hex
	call	spi_writebyte_port_b
	
	mov		al,				ES:[bx+4]
	;call	print_char_hex
	call	spi_writebyte_port_b

	;call	delay

	call	spi_waitresult
	push	ax				; save result

	;call	delay

	;call	send_garbage
	;mov		al,				(SPI_CS1| SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)	
	;mov		[spi_state_b],	al
	;out		VIA1_PORTB,		al	
	;call	send_garbage

	pop		ax				; retrieve result

	.out:
  ret

spi_waitresult:
	; Wait for the SD card to return something other than $ff
 
	call	spi_readbyte_port_b
	cmp		al,		0xff
	je		spi_waitresult
 
	ret

test_math_co:
	push	ax

	R			dd		91.67			; 42b7570a				In ROM: 0a57b742

	call	ToROM						; Change DS to 0xC000
	mov		ax,		[R+3]				; 42
	call	print_char_hex

	mov		ax,		[R+2]				; b7
	call	print_char_hex

	mov		ax,		[R+1]				; 57
	call	print_char_hex

	mov		ax,		[R]					; 0a
	call	print_char_hex

	finit								; Initialize math coprocessor
	fld		dword [R]					; Load radius
	fmul	st0,st0						; Square R
	fldpi								; Load PI
	fmul	st0,st1						; Multiply PI by R squared
	call	ToRAM						; Change DS to 0x0000
	
	;mov		word [AREA],	0x1234
	;mov		word [AREA+2],	0x4567

	fstp	dword [AREA]				; Store calculated area			;was getting FFFFFFFF here
										; 26400.0232375 = 46ce400c		In RAM: 0c40ce46

	call	lcd_line2

	mov		ax,		[AREA+3]				; 46
	call	print_char_hex

	mov		ax,		[AREA+2]				; ce
	call	print_char_hex

	mov		ax,		[AREA+1]				; 40
	call	print_char_hex

	mov		ax,		[AREA]					; 0c
	call	print_char_hex


	; ***** SPI 8char 7seg display *****
	
	mov		ax,					0b00001010_00000100		; intensity = 9/32
	call	spi_send_LEDcmd
	mov		ax,					0b00000001_00000000		; digit 0 = '0'
	call	spi_send_LEDcmd
	mov		ax,					0b00000010_00000001		; digit 1 = '1'
	call	spi_send_LEDcmd
	mov		ax,					0b00000011_00000010		; digit 2 = '2'
	call	spi_send_LEDcmd
	mov		ax,					0b00000100_00000011		; digit 3 = '3'
	call	spi_send_LEDcmd
	mov		ax,					0b00000101_00000100		; digit 4 = '4'
	call	spi_send_LEDcmd
	mov		ax,					0b00000110_00000101		; digit 5 = '5'
	call	spi_send_LEDcmd
	mov		ax,					0b00000111_00000110		; digit 6 = '6'
	call	spi_send_LEDcmd
	mov		ax,					0b00001000_00000111		; digit 7 = '7'
	call	spi_send_LEDcmd

	; /***** SPI 8char 7seg display *****

	pop		ax
	ret

spi_8char7seg_init:

	push	ax
	mov		ax,					0b00001001_11111111		; decode mode = code B for all digits			0x09FF
	call	spi_send_LEDcmd
	mov		ax,					0b00001011_00000111		; scan limit = display all digits				
	call	spi_send_LEDcmd
	mov		ax,					0b00001010_00000000		; intensity = 1/32
	call	spi_send_LEDcmd
	mov		ax,					0b00001100_00000001		; shutdown mode = normal operation
	call	spi_send_LEDcmd
	
	mov		ax,					0b00000001_00001010		; digit 0 = '-'
	call	spi_send_LEDcmd
	mov		ax,					0b00000010_00001010		; digit 1 = '-'
	call	spi_send_LEDcmd
	mov		ax,					0b00000011_00001010		; digit 2 = '-'
	call	spi_send_LEDcmd
	mov		ax,					0b00000100_00001010		; digit 3 = '-'
	call	spi_send_LEDcmd
	mov		ax,					0b00000101_00001010		; digit 4 = '-'
	call	spi_send_LEDcmd
	mov		ax,					0b00000110_00001010		; digit 5 = '-'
	call	spi_send_LEDcmd
	mov		ax,					0b00000111_00001010		; digit 6 = '-'
	call	spi_send_LEDcmd
	mov		ax,					0b00001000_00001010		; digit 7 = '-'
	call	spi_send_LEDcmd

	mov		ax,					0b00001111_00000000		; normal operation (turn off display-test)
	call	spi_send_LEDcmd

	pop		ax
	ret

spi_init:
	; configure the port
	push	ax
	push	bx

	mov		al,			0b01111111			; disable all interrupts on VIA
	out		VIA1_IER,	al

	mov		al,			(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_CLK | SPI_MOSI)	; set bits as output -- other bits will be input
	out		VIA1_DDRB,	al
	nop
	nop
	nop
	nop
	nop
	nop
	out		VIA1_DDRA,	al

	; set initial values on the port
	mov		al,			(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)	; start with all select lines high and clock low - mode 0
	out		VIA1_PORTB,	al		; set initial values - not CS's selected
	nop
	nop
	nop
	nop
	nop
	out		VIA1_PORTA,	al		; set initial values - not CS's selected

	mov		bx,		msg_spi_init
	call	print_string_to_serial

	pop		bx
	pop		ax
	ret

spi_writebyte_port_b:
	; Value to write in al
	; CS values and MOSI high in spi_state

	; Tick the clock 8 times with descending bits on MOSI
	; Ignoring anything returned on MISO (use spi_readbyte if MISO is needed)
  
	push	ax
	push	bx
	push	bp

	mov		bp,		0x08					; send 8 bits
	.loop:
		shl		al,				1			; shift next bit into carry
		mov		bl,				al			; save remaining bits for later
		jnc		.sendbit					; if carry clear, don't set MOSI for this bit and jump down to .sendbit
		mov		al,				[spi_state_b]	; instead of 0, need to keep CS properly set when using multiple SPI devices		
		;or		al,				SPI_MOSI	; if value in carry, set MOSI
		jmp		.clock
	.sendbit:
		mov		al,				[spi_state_b]	; instead of 0, need to keep CS properly set when using multiple SPI devices		
		and		al,				~SPI_MOSI	;0b11111101	; to do: invert SPI_MOSI instead of 0b... value
	.clock:
		; remove the following line
		and		al,				~SPI_CLK	;0b11111011	 low clock			to do: invert SPI_CLK instead of 0b... value		--use ~
		
		out		VIA1_PORTB,		al			; set MOSI (or not) first with SCK low
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		or		al,				SPI_CLK		; high clock
		out		VIA1_PORTB,		al			; raise CLK keeping MOSI the same, to send the bit
		nop
		nop
		nop
		nop
		nop
		nop
		nop

		mov		al,				bl			; restore remaining bits to send
		dec		bp
		jne		.loop						; loop if there are more bits to send


	;bring clock low
	mov		al,				[spi_state_b]			
	out		VIA1_PORTB,		al			


	pop		bp
	pop		bx
	pop		ax
	ret

spi_writebyte_port_a:
	; Value to write in al
	; CS values and MOSI high in spi_state

	; Tick the clock 8 times with descending bits on MOSI
	; Ignoring anything returned on MISO (use spi_readbyte if MISO is needed)
  
	push	ax
	push	bx
	push	bp

	mov		bp,		0x08					; send 8 bits
	.loop:
		shl		al,				1			; shift next bit into carry
		mov		bl,				al			; save remaining bits for later
		jnc		.sendbit					; if carry clear, don't set MOSI for this bit and jump down to .sendbit
		mov		al,				[spi_state_a]	; instead of 0, need to keep CS properly set when using multiple SPI devices		
		;or		al,				SPI_MOSI	; if value in carry, set MOSI
		jmp		.clock
	.sendbit:
		mov		al,				[spi_state_a]	; instead of 0, need to keep CS properly set when using multiple SPI devices		
		and		al,				~SPI_MOSI	;0b11111101	; to do: invert SPI_MOSI instead of 0b... value
	.clock:
		; remove the following line
		and		al,				~SPI_CLK	;0b11111011	 low clock			to do: invert SPI_CLK instead of 0b... value		--use ~
		
		out		VIA1_PORTA,		al			; set MOSI (or not) first with SCK low
		or		al,				SPI_CLK		; high clock
		out		VIA1_PORTA,		al			; raise CLK keeping MOSI the same, to send the bit

		mov		al,				bl			; restore remaining bits to send
		dec		bp
		jne		.loop						; loop if there are more bits to send

	pop		bp
	pop		bx
	pop		ax
	ret

spi_readbyte_port_b:
	mov		bp,		0x08					; send 8 bits
	.loop:
		mov		al,				[spi_state_b]		; MOSI already high and CLK low
		out		VIA1_PORTB,		al
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop

		or		al,				SPI_CLK		; toggle the clock high
		out		VIA1_PORTB,		al
		in		al,				VIA1_PORTB	; read next bit
		and		al,				SPI_MISO
		clc									; default to clearing the bottom bit
		je		.readyByteBitNotSet			; unless MISO was set
		stc									; in which case get ready to set the bottom bit

		.readyByteBitNotSet:
			mov		al,				bl		; transfer partial result from bl
			rcl		al,				1		; rotate carry bit into read result
			mov		bl,				al		; save partial result back to bl
			dec		bp						; decrement counter
			jne		.loop					; loop if more bits

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	push	ax		;save read value
	; end clock high
	mov		al,				[spi_state_b]		; MOSI already high and CLK low
	out		VIA1_PORTB,		al
	pop		ax		;retrieve read value

	ret

spi_readbyte_port_a:
	;push	ax
	push	bx
	push	bp

	mov		bp,		0x08					; send 8 bits
	.loop:
		
		;mov		al,				SPI_MOSI	; enable card (CS low), set MOSI (resting state), SCK low
		mov		al,				[spi_state_a]		; MOSI already high and CLK low
		out		VIA1_PORTA,		al
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		or		al,				SPI_CLK		; toggle the clock high
		out		VIA1_PORTA,		al
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		in		al,				VIA1_PORTA	; read next bit
		and		al,				SPI_MISO
		clc									; default to clearing the bottom bit
		je		.readyByteBitNotSet			; unless MISO was set
		stc									; in which case get ready to set the bottom bit

		.readyByteBitNotSet:
			mov		al,				bl		; transfer partial result from bl
			rcl		al,				1		; rotate carry bit into read result
			mov		bl,				al		; save partial result back to bl
			dec		bp						; decrement counter
			jne		.loop					; loop if more bits

	pop		bp
	pop		bx
	;pop		ax

	ret
	
spi_send_NanoSerialCmd:
	; using SPI mode 0 (cpol=0, cpha=0)
	push	bx
	push	ax

	mov		al,				(			SPI_CS2	| SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; drop SPI_CS1 low to enable, start with MOSI high and CLK low
	mov		[spi_state_a],		al
	out		VIA1_PORTA,		al		

	pop		ax						; get back original ax
	push	ax						; save it again to stack

	mov		al,				ah		; digit 1
	call	spi_writebyte_port_a	; write high byte (i.e., SPI cmd)
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)		; bring all SPI_CSx high, keep MOSI high, and CLK low
	out		VIA1_PORTA,		al	
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	mov		al,				[spi_state_a]
	out		VIA1_PORTA,		al	

	pop		ax						; get back original ax
	push	ax						; save it again to stack
	call	spi_writebyte_port_a	; using original al, write low byte (parameter data for previously-sent cmd above)

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)		; bring all SPI_CSx high, keep MOSI high, and CLK low
	out		VIA1_PORTA,		al	

	pop		ax
	pop		bx
	ret

spi_send_LEDcmd:
	push	bx
	push	ax

	mov		al,				(		   SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; drop SPI_CS1 low to enable, start with MOSI high and CLK low
	mov		[spi_state_b],		al
	out		VIA1_PORTB,		al		

	pop		ax						; get back original ax
	push	ax						; save it again to stack

	mov		al,				ah		; digit 1
	call	spi_writebyte_port_b
	nop
	nop
	nop
	nop

	pop		ax						; get back original ax
	push	ax						; save it again to stack
	call	spi_writebyte_port_b			; using original al

	nop
	nop
	nop
	nop
	nop

	mov		al,				(		SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)		; bring all SPI_CSx high, keep MOSI and CLK high
	out		VIA1_PORTB,		al	
	nop
	nop
	nop
	nop
	nop

	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)		; bring all SPI_CSx high, keep MOSI and CLK high
	out		VIA1_PORTB,		al	

	nop
	nop
	nop
	nop
	nop

	pop		ax
	pop		bx
	ret

kbd_isr:
	; to do - write scancodes to array and get out of ISR quickly - then print char as part of .main_loop

	; cli		; for interrupt gates, this should not be needed (but should be used for trap gates)

	pusha

	; if releasing a key, don't read PPI, but reset RELEASE flag
	mov		ax,					[kb_flags]
	and		ax,					RELEASE
	je		.read									; if equal, releasing flag is not set, so continue reading the PPI
	mov		ax,					[kb_flags]
	and		ax,					~RELEASE			; clear the RELEASE flag
	mov		word [kb_flags],	ax
	jmp		.not_ascii

	.read:
		call	kbd_get_scancode		; read scancode from PPI2 into al
		;call	print_char_hex			; print scancode as hex string
	
	; to do - filter for scancodes that map to printable ascii
	; to do - process non-ascii scancodes (e.g., ESC)
	
	.filter:										;Filter out some noise scancodes
		cmp		al,					0x7e		;Microsoft Ergo keyboard init? - not using
		jne		.release
		jmp		.not_ascii

	.release:
		cmp		al,					0xf0		; key release
		jne		.esc
		mov		ax,					[kb_flags]
		or		ax,					RELEASE		; set release flag
		mov		word [kb_flags],	ax
		jmp		.not_ascii
	
	.esc:
		cmp		al,			0x76		; ESC
		jne		.ascii
		call	lcd_clear
		
		; call	via1_portb_test
			
		call	test_math_co

		jmp		.not_ascii

	; to do - check for other non-ascii

	.ascii:
		;call	print_char_hex			; print scancode as hex string
		call	kbd_scancode_to_ascii	; convert scancode to ascii
		call	print_char				; print ascii char
		mov		ah,		0x01			; spi cmd 1 - print char
		call	spi_send_NanoSerialCmd

	
	.not_ascii:
		mov		al,			0x20		; EOI byte for OCW2 (always 0x20)
		out		PICM_P0,	al			; to port for OCW2

	;sti		; for interrupt gates, this should not be needed (but should be used for trap gates)

	popa
	iret

pic_init:
	push	ax
											; kbd_isr is at physical address 0xC0047. The following few lines move segment C000 and offset 0047 into the IVT
	mov word [KBD_IVT_OFFSET], kbd_isr		; DS set to 0x0000 above. These MOVs are relative to DS.
											; 0x0000:0x0024 = IRQ1 offset in IVT
	mov		ax, 0xC000
	mov word [KBD_IVT_OFFSET+2], ax			; 0x0000:0x0026 = IRQ1 segment in IVT

									; ICW1: 0001 | LTIM (1=level, 0=edge) | Call address interval (1=4, 0=8) | SNGL (1=single, 0=cascade) | IC4 (1=needed, 0=not)
	mov		al,			0b00010111			;0x17		ICW1 - edge, master, ICW4
	out		PICM_P0,	al

									; ICW2: Interrupt assigned to IR0 of the 8259 (usually 0x08)
	mov		al,			0x08		; setup ICW2 - interrupt type 8 (8-F)
	out		PICM_P1,	al

									; ICW3: 1=IR input has a slave, 0=no slave			--only set if using master/slave (SNGL=0 in ICW1)
	;mov		al,			0x00		; setup ICW3 - no slaves
	;out		PICM_P1,	al

									; ICW4: 000 | SFNM (1=spec fully nested mode, 0=not) | BUF & MS (0x = nonbuffered, 10 = buffered slave, 11 = buffered master) 
									; | AEOI (1=auto EOI, 0=normal) | PM (1=x86,0=8085)
	mov		al,			0x01		; setup ICW4 - master x86 mode
	out		PICM_P1,	al

	; PIC should be ready for interrupt requests at this point

									; OCW1: For bits, 0=unmask (enable interrupt), 1=mask
	;mov		al,			0b11010000	; Unmask IR0-IR7
	;out		PICM_P1,	al

	pop		ax
	ret

print_message:
	;mov		al,		'R'
	;call	print_char
	;mov		al,		'e'
	;call	print_char
	;mov		al,		'a'
	;call	print_char
	;mov		al,		'd'
	;call	print_char
	;mov		al,		'y'
	;call	print_char
	mov		al,		'>'
	call	print_char
	ret

print_string_to_serial:
	; Assuming string is in ROM space (not RAM)
	; Send a NUL-terminated string to the LCD display;
	; In: DS:BX -> string to print
	; Return: AX = number of characters printed
	; All other registers preserved or unaffected.

	call ToROM

	push	bx 					; Save BX 
	push	cx 					; and CX onto the sack
	mov		cx, bx 				; Save contents of BX for later use
	
	.loop:
		mov		al, [bx] 		; Read byte from [DS:BX]
		or		al, al 			; Did we encounter a NUL character?
		jz		.return 		; If so, return to the caller
		;call	print_char	 	; call our character print routine
		mov		ah,		0x01	; spi cmd 1 - print char

		call	ToRAM
		call	spi_send_NanoSerialCmd
		call	ToROM

		inc		bx 				; Increment the index
		jmp		.loop 			; And loop back
	
	.return: 
		call	ToRAM
		sub		bx, cx 			; Calculate our number of characters printed
		mov		ax, bx 			; And load the result into AX
		pop		cx 				; Restore CX
		pop		bx 				; and BX from the stack
		ret 					; Return to our caller

lcd_init:
	push	ax
	mov		al,		0b00111000	;0x38	; Set to 8-bit mode, 2 lines, 5x7 font
	call	lcd_command_write
	mov		al,		0b00001110	;0x0E	; LCD on, cursor on, blink off
	call	lcd_command_write
	mov		al,		0b00000001	;0x01	; clear LCD
	call	lcd_command_write
	mov		al,		0b00000110  ;0x06	; increment and shift cursor, don't shift display
	call	lcd_command_write
	pop		ax
	ret

lcd_command_write:
	call	lcd_wait
	push	dx
	push	ax
	mov		dx,		PPI1_PORTA			; Get A port address
	out		dx,		al					; Send al to port A
	mov		dx,		PPI1_PORTB			; Get B port address
	mov		al,		E					; RS=0, RW=0, E=1
	out		dx,		al					; Write to port B
	nop									; wait for high-to-low pulse to be wide enough
	nop
	mov		al,		0x0					; RS=0, RW=0, E=0
	out		dx,		al					; Write to port B

	pop		ax
	pop		dx
	ret

print_char:
	call	lcd_wait
	push	dx
	push	ax

	mov		dx,		PPI1_PORTA			; Get A port address
	out		dx,		al					; Write data (e.g. char) to port A
	mov		al,		(RS | E)			; RS=1, RW=0, E=1
	mov		dx,		PPI1_PORTB			; Get B port address
	out		dx,		al					; Write to port B - enable high
	nop									; wait for high-to-low pulse to be wide enough
	nop
	mov		al,		RS					; RS=1, RW=0, E=0
	out		dx,		al					; Write to port B - enable low

	pop		ax
	pop		dx
	ret

print_char_hex:
	push	ax

	mov		al,		'x'
	call	print_char

	pop		ax
	push	ax
	and		al,		0xf0		; upper nibble of lower byte
	shr		al,		4
	cmp		al,		0x0a
	sbb		al,		0x69
	das
	call	print_char

	pop		ax
	push	ax
	and		al,		0x0f		; lower nibble of lower byte
	cmp		al,		0x0a
	sbb		al,		0x69
	das
	call	print_char

	pop		ax
	ret

kbd_get_scancode:
	; Places scancode into al

	push	dx

	mov		al,		CTL_CFG_PB_IN
	mov		dx,		PPI2_CTL
	out		dx,		al
	mov		dx,		PPI2_PORTB			; Get B port address
	in		al,		dx					; Read PS/2 keyboard scancode into al

	pop		dx
	ret

kbd_scancode_to_ascii:
	call	ToROM
	push	bx
	and		ax,		0x00FF
	mov		bx,		ax
	mov		ax,		[ keymap + bx]			; can indexing be done with bl? "invalid effective address"
	and		ax,		0x00FF
	pop		bx
	call	ToRAM
	ret

ToROM:
	push 	cs 					; push CS onto the stack	
	pop 	ds 					; and pop it into DS so that DS is in ROM address space
	ret

ToRAM:
	push	ax
	mov		ax,	0x0				; return DS back to 0x0
	mov		ds, ax
	pop		ax
	ret

lcd_wait:
	push	ax				
	push	dx
	mov		al,		CTL_CFG_PA_IN		; Get config value
	mov		dx,		PPI1_CTL			; Get control port address
	out		dx,		al					; Write control register on PPI

	.again:	
		mov		al,		(RW)				; RS=0, RW=1, E=0
		mov		dx,		PPI1_PORTB			; Get B port address
		out		dx,		al					; Write to port B
		mov		al,		(RW|E)				; RS=0, RW=1, E=1
		out		dx,		al					; Write to port B
	
		mov		dx,		PPI1_PORTA			; Get A port address

		in		al,		dx				; Read data from LCD (busy flag on D7)
		rol		al,		1				; Rotate busy flag to carry flag
		jc		.again					; If CF=1, LCD is busy
		mov		al,		CTL_CFG_PA_OUT	; Get config value
		mov		dx,		PPI1_CTL		; Get control port address
		out		dx,		al				; Write control register on PPI

	pop	dx
	pop	ax
	ret

delay:
	push	bp
	push	si

	mov		bp, 0xFFFF
	mov		si, 0x0001
	.delay2:
		dec		bp
		nop
		jnz		.delay2
		dec		si
		cmp		si,0    
		jnz		.delay2

	pop		si
	pop		bp
	ret

lcd_clear:
	push	ax
    mov		al,		0b00000001		; Clear display
	call	lcd_command_write
	pop		ax
	ret

lcd_line2:
	push	ax
	mov		al,		0b10101000		; Go to line 2
	call	lcd_command_write
	pop		ax
	ret

play_sound:
	push	ax
	push	dx

	mov		al,		CTL_CFG_PA_OUT	; Get config value - PA_OUT includes PB_OUT also
	mov		dx,		PPI1_CTL		; Get control port address
	out		dx,		al				; Write control register on PPI

	mov		bp, 0x01FF				; Number of "sine" waves (-1) - duration of sound
	.wave:
		.up:
			mov		al,		0x1
			mov		dx,		PPI1_PORTC			; Get C port address
			out		dx,		al					; Write data to port C
			mov		si,		0x0060				; Hold duration of "up"

			.uploop:
				nop
				dec		si
				cmp		si,	0
				jnz		.uploop

		.down:
			mov		al,		0x0
			mov		dx,		PPI1_PORTC			; Get C port address
			out		dx,		al					; Write data to port C
			mov		si,		0x0060				; Hold duration of "down"

			.downloop:
				nop
				dec		si
				cmp		si,	0
				jnz		.downloop

		dec		bp
		jnz		.wave

	mov		bp, 0x00FF				; Number of "sine" waves (-1) - duratin of sound
	.wave2:
		.up2:
			mov		al,		0x1
			mov		dx,		PPI1_PORTC			; Get C port address
			out		dx,		al					; Write data to port C
			mov		si,		0x0050				; Hold duration of "up"

			.uploop2:
				nop
				dec		si
				cmp		si,	0
				jnz		.uploop2

		.down2:
			mov		al,		0x0
			mov		dx,		PPI1_PORTC			; Get C port address
			out		dx,		al					; Write data to port C
			mov		si,		0x0050				; Hold duration of "down"

			.downloop2:
				nop
				dec		si
				cmp		si,	0
				jnz		.downloop2

		dec		bp
		jnz		.wave2

	.out:
		pop		dx
		pop		ax

		ret

; strings
string_test					db	'80286 at 8 MHz!', 0x0
msg_spi_init				db	'SPI (and VIA) Init', 0x0a, 0x0
msg_sdcard_init				db	'SD Card Init starting', 0x0a, 0x0
msg_sdcard_try00			db	'SD Card Init: Sending cmd 00...', 0x0a, 0x0
msg_sdcard_try00_done		db	'SD Card Init: cmd 00 success', 0x0a, 0x0
msg_sdcard_init_out			db	'SD Card routine finished',0x0a, 0x0
msg_sdcard_sendcommand		db	'SD Card Send Command: ', 0x0
msg_sdcard_received			db	0x0a, 'Received: ', 0x0
msg_sdcard_try08			db	'SD Card Init: Sending cmd 08...', 0x0a, 0x0
msg_sdcard_try08_done		db	'SD Card Init: cmd 08 success', 0x0a, 0x0
msg_garbage					db	'.', 0x0a, 0x0
msg_sdcard_try55			db	'SD Card Init: Sending cmd 55...', 0x0a, 0x0
msg_sdcard_try55_done		db	'SD Card Init: cmd 55 success', 0x0a, 0x0
msg_sdcard_try41			db	'SD Card Init: Sending cmd 41...', 0x0a, 0x0
msg_sdcard_try41_done		db	'SD Card Init: cmd 41 success.', 0x0a, '** SD Card initialization complete. Let the party begin! **', 0x0a, 0x0
msg_sdcard_try18			db	'SD Card Init: Sending cmd 18...', 0x0a, 0x0
msg_sdcard_try18_done		db	'SD Card Init: cmd 18 success', 0x0a, 0x0
msg_sdcard_nodata			db	'SD Card - No data!', 0x0a, 0x0
msg_sdcard_read_done		db  'SD Card - Finished reading data', 0x0a, 0x0

keymap:
	db "????????????? `?"          ; 00-0F
	db "?????q1???zsaw2?"          ; 10-1F
	db "?cxde43?? vftr5?"          ; 20-2F
	db "?nbhgy6???mju78?"          ; 30-3F
	db "?,kio09??./l;p-?"          ; 40-4F
	db "??'?[=????",$0a,"]?",$5c,"??"    ; 50-5F     orig:"??'?[=????",$0a,"]?\??"   '\' causes issue with retro assembler - swapped out with hex value 5c
	db "?????????1?47???"          ; 60-6F0
	db "0.2568",$1b,"??+3-*9??"    ; 70-7F
	db "????????????????"          ; 80-8F
	db "????????????????"          ; 90-9F
	db "????????????????"          ; A0-AF
	db "????????????????"          ; B0-BF
	db "????????????????"          ; C0-CF
	db "????????????????"          ; D0-DF
	db "????????????????"          ; E0-EF
	db "????????????????"          ; F0-FF
keymap_shifted:
	db "????????????? ~?"          ; 00-0F
	db "?????Q!???ZSAW@?"          ; 10-1F
	db "?CXDE#$?? VFTR%?"          ; 20-2F
	db "?NBHGY^???MJU&*?"          ; 30-3F
	db "?<KIO)(??>?L:P_?"          ; 40-4F
	db "??",$22,"?{+?????}?|??"          ; 50-5F      orig:"??"?{+?????}?|??"  ;nested quote - compiler doesn't like - swapped out with hex value 22
	db "?????????1?47???"          ; 60-6F
	db "0.2568???+3-*9??"          ; 70-7F
	db "????????????????"          ; 80-8F
	db "????????????????"          ; 90-9F
	db "????????????????"          ; A0-AF
	db "????????????????"          ; B0-BF
	db "????????????????"          ; C0-CF
	db "????????????????"          ; D0-DF
	db "????????????????"          ; E0-EF
	db "????????????????"          ; F0-FF


times 0x30000-($-$$)-0x0800 db 0xff	; Fill ROM with FFs up to (near) bootvector
										; ff's allow for faster writing of flash ROMs


section .rodata start=0x30000
	; SPI SD Card commands - Each cmd has six bytes of data to be sent
	cmd0_bytes:						; GO_IDLE_STATE
		dw	0x4000
		dw	0x0000
		dw	0x0095; 
	cmd1_bytes:						; SEND_OP_COND
		dw 0x4100
		dw 0x0000
		dw 0x00f9
	cmd8_bytes:						; SEND_IF_COND
		dw 0x4800
		dw 0x0001
		dw 0xaa87
	cmd12_bytes:					; STOP_TRANSMISSION
		dw 0x4c00
		dw 0x0000
		dw 0x0061
	cmd18_bytes:					; READ_MULTIPLE_BLOCK, starting at 0x0
		dw 0x5200	
		dw 0x0000
		dw 0x00e1
	cmd41_bytes:					; SD_SEND_OP_COND
		dw 0x6940
		dw 0x0000
		dw 0x0077
	cmd55_bytes:					; APP_CMD
		dw 0x7700
		dw 0x0000
		dw 0x0065

times 0x0fff0 - ($-$$) db 0xff		; fill remainder of section with FFs (faster flash ROM writes)
									; very end overlaps .bootvector

; https://www.nasm.us/xdoc/2.15.05/html/nasmdoc7.html#section-7.3
section .bootvector	start=0x3fff0

reset:						; at 0xFFFF0			*Processor starts reading here
	jmp 0xc000:0x0			; Jump to TOP: label

; times 0x040000-($-$$) db 0xff	; Fill the rest of ROM with bytes of 0x01 (256 KB total)
times 0x10 - ($-$$) db 0xff		; 16 - length of section so far (i.e., fill the rest of the section)