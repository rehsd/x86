;Last updated 27 NOV 2022
;Latest update: VIA SPI 8char7Seg
;Assembler: NASM
;
; *physical memory map*
;-----------------------
;-    ROM  (256 KB)    -
;-   0xC0000-0xFFFFF   -
;-----------------------
;-   VIDEO  (128 KB)   -
;-   0xA0000-0xBFFFF   -
;-----------------------
;-    RAM  (640 KB)    -
;-   0x00000-0x9FFFF   -
;-----------------------
;
; To do:
;   -initialize interrupt vector table
;	-handlers, exceptions, hardware traps
;
; PPI/LCD code adapted from "The 80x86 IBM PC and Compatible Computers..., 4th Ed." -- Mazidi & Mazidi
; Sample interrupt code adapted from https://stackoverflow.com/questions/51693306/registering-interrupt-in-16-bit-x86-assembly
; Sample interrupt code adapted from "The 80x86 IBM PC and Compatible Computers..., 4th Ed." -- Mazidi & Mazidi
; https://tiij.org/issues/issues/fall2006/32_Jenkins-PIC/Jenkins-PIC.pdf
; 80286 Hardware Reference Manual, pg. 5-20
; http://www.nj7p.org/Manuals/PDFs/Intel/121500-001.pdf

cpu		286
bits 	16

section .data

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
	RELEASE#	equ		0b1111111111111110
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
											; support for 5 SPI devices (or 10 if using a 3-to-8; 33 if also using port A)
	SPI_CS1     equ		0b10000000			; 8-digit 7-segment display
	SPI_CS2		equ		0b01000000			; Arduino Nano serial output
	SPI_CS3		equ		0b00100000			; tbd
	SPI_CS4		equ		0b00010000			; tbd
	SPI_CS5		equ		0b00001000			; tbd

	spi_state	db		0x0					; track CS state

section .bss
	

section .text	;start=0x8000	;vstart=0x80000	;start=0x80000

org		0x0000		;0xC000
top:				; physically at 0x80000 in physical address space

;*** SETUP REGISTERS **********************************
xor		ax,	ax
mov		ds, ax
mov		es,	ax				; extra segment
mov		sp,	ax				; Start stack pointer at 0. It will wrap around (down) to FFFE.
mov		ax,	0x0040			; First 1K is reserved for interrupt vector table,
mov		ss,	ax				; Start stack segment at the end of the IVT.

;push 	cs 					; push CS onto the stack	
;pop 	ds 					; and pop it into DS so that DS is in ROM
;*** /SETUP REGISTERS *********************************

cli					; disable interrupts
call	lcd_init
call	print_message
call	pic_init
call	spi_init
sti										; Enable interrupts
call	play_sound

.main_loop:
	jmp .main_loop

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

		; mov		ax,				0xFFFF			; display test, all on
		; call	spi_send_LEDcmd
		; ret

	mov		ax,					0b00001001_11111111		; decode mode = code B for all digits
	call	spi_send_LEDcmd
	mov		ax,					0b00001011_00000111		; scan limit = display all digits
	call	spi_send_LEDcmd
	mov		ax,					0b00001010_00001000		; intensity = 17/32
	call	spi_send_LEDcmd
	mov		ax,					0b00001100_00000001		; shutdown mode = normal operation
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

test_via:
	; via at 0x0020 IO map address (IO addresses 20-3F reserved for VIA1)
	;								
	;								shifted	
	; VIA_PORTB = $00		0000	0000.0	00 + x20 = 20
    ; VIA_PORTA = $01		0001	0001.0	02 + x20 = 22
    ; VIA_DDRB  = $02		0010	0010.0	04 + x20 = 24
    ; VIA_DDRA  = $03		0011	0011.0	06 + x20 = 26
    ; VIA_T1C_L = $04		0100	0100.0	08 + x20 = 28
    ; VIA_T1C_H = $05		0101	0101.0	0A + x20 = 2A
    ; VIA_T1L_L = $06		0110	0110.0	0C + x20 = 2C
    ; VIA_T1L_H = $07		0111	0111.0	0E + x20 = 2E
    ; VIA_T2C_L = $08		1000	1000.0	10 + x20 = 30
    ; VIA_T2C_H = $09		1001	1001.0	12 + x20 = 32
    ; VIA_SR    = $0A		1010	1010.0	14 + x20 = 34
    ; VIA_ACR   = $0B		1011	1011.0	16 + x20 = 36
    ; VIA_PCR   = $0C		1100	1100.0	18 + x20 = 38
    ; VIA_IFR   = $0D		1101	1101.0	1A + x20 = 3A
    ; VIA_IER   = $0E		1110	1110.0	1C + x20 = 3C

	; 0x20 = 00100000
	; 0x3C = 00111100

	;lda #%01111111	        ; Disable all interrupts
    ;sta VIA1_IER
	;lda #%11111111 
    ;sta VIA1_DDRB           ; Set all pins on port B to output

	push	ax

	mov		al,				0b01111111			; 0x7f	- disable all interrupts
	out		VIA1_IER,		al
	mov		al,				0b11111111			; 0xff	- set all pins on port b to output
	out		VIA1_DDRB,		al

	.loop:
		mov		al,				0b11110000
		out		VIA1_PORTB,		al

		mov		al,				0b00001111
		out		VIA1_PORTB,		al
		jmp		.loop

	pop		ax

	ret

spi_init:
	; configure the port
	mov		al,			(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_CLK | SPI_MOSI)	; set bits as output -- other bits will be input
	out		VIA1_DDRB,	al

	; set initial values on the port
	mov		al,			(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)	; start with all select lines high and clock high - mode 0, clk low
	out		VIA1_PORTB,	al		; set initial values - not CS's selected

	ret

spi_writebyte:
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
		mov		al,				[spi_state]	; instead of 0, need to keep CS properly set when using multiple SPI devices		
		;or		al,				SPI_MOSI	; if value in carry, set MOSI
		jmp		.clock
	.sendbit:
		mov		al,				[spi_state]	; instead of 0, need to keep CS properly set when using multiple SPI devices		
		and		al,				~SPI_MOSI	;0b11111101	; to do: invert SPI_MOSI instead of 0b... value
	.clock:
		; remove the following line
		and		al,				~SPI_CLK	;0b11111011	 low clock			to do: invert SPI_CLK instead of 0b... value		--use ~
		
		out		VIA1_PORTB,		al			; set MOSI (or not) first with SCK low
		nop
		nop
		nop
		nop
		or		al,				SPI_CLK		; high clock
		out		VIA1_PORTB,		al			; raise CLK keeping MOSI the same, to send the bit

		mov		al,				bl			; restore remaining bits to send
		dec		bp
		jne		.loop						; loop if there are more bits to send

	pop		bp
	pop		bx
	pop		ax
	ret

spi_readbyte:
	; **** not yet tested ***
	
	; Enable the device and tick the clock 8 times with MOSI high, 
	; capturing bits from MISO and returning them

    ; ldx #8                      ; we'll read 8 bits
    ; readByteLoop:
    ;     lda #SPI_MOSI                ; enable card (CS low), set MOSI (resting state), SCK low
    ;     sta VIA1_PORTB
    ;     lda #(SPI_MOSI | SPI_CLK)       ; toggle the clock high
    ;     sta VIA1_PORTB

    ;     lda VIA1_PORTB                   ; read next bit
    ;     and #SPI_MISO

    ;     clc                         ; default to clearing the bottom bit
    ;     beq readByteBitNotSet              ; unless MISO was set
    ;     sec                         ; in which case get ready to set the bottom bit
    ; readByteBitNotSet:
    ;     tya                         ; transfer partial result from Y
    ;     rol                         ; rotate carry bit into read result
    ;     tay                         ; save partial result back to Y

    ;     dex                         ; decrement counter
    ;     bne readByteLoop                   ; loop if we need to read more bits


	push	ax
	push	bx
	push	bp

	mov		bp,		0x08					; send 8 bits
	.loop:
		mov		al,				SPI_MOSI	; enable card (CS low), set MOSI (resting state), SCK low
		out		VIA1_PORTB,		al
		mov		al,				(SPI_MOSI | SPI_CLK)		; toggle the clock high
		out		VIA1_PORTB,		al
		in		al,				VIA1_PORTB	; read next bit
		and		al,				SPI_MISO
		clc									; default to clearing the bottom bit
		je		.readyByteBitNotSet			;	unleess MISO was set
		stc									; in which caes get read to set the bottom bit

		.readyByteBitNotSet:
			mov		al,				bl		; transfer partial result from bl
			rcl		al,				1		; rotate carry bit into read result
			mov		bl,				al		; save partial result back to bl
			dec		bp						; decrement counter
			jne		.loop					; loop if more bits

	pop		bp
	pop		bx
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

spi_send_NanoSerialCmd:
	; using SPI mode 0 (cpol=0, cpha=0)
	push	bx
	push	ax

	mov		al,				(SPI_CS1		| SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; drop SPI_CS1 low to enable, start with MOSI high and CLK low
	mov		[spi_state],		al
	out		VIA1_PORTB,		al		

	pop		ax						; get back original ax
	push	ax						; save it again to stack

	mov		al,				ah		; digit 1
	call	spi_writebyte

	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)		; bring all SPI_CSx high, keep MOSI high, and CLK low
	out		VIA1_PORTB,		al	
	nop
	nop
	nop
	nop
	mov		al,				[spi_state]
	out		VIA1_PORTB,		al	

	pop		ax						; get back original ax
	push	ax						; save it again to stack
	call	spi_writebyte			; using original al

	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)		; bring all SPI_CSx high, keep MOSI high, and CLK low
	out		VIA1_PORTB,		al	

	pop		ax
	pop		bx
	ret
spi_send_LEDcmd:
	push	bx
	push	ax

	mov		al,				(		   SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; drop SPI_CS1 low to enable, start with MOSI high and CLK low
	mov		[spi_state],		al
	out		VIA1_PORTB,		al		

	pop		ax						; get back original ax
	push	ax						; save it again to stack

	mov		al,				ah		; digit 1
	call	spi_writebyte
	pop		ax						; get back original ax
	push	ax						; save it again to stack
	call	spi_writebyte			; using original al

	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)		; bring all SPI_CSx high, keep MOSI and CLK high
	out		VIA1_PORTB,		al	

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
	and		ax,					RELEASE#			; clear the RELEASE flag
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

pic_register_test:
	mov		al,			0x01
	.testloop:
		out		PICM_P1,	al
		mov		al,			0x00		; Clear al
		in		al,			PICM_P1		; Retrieve al from register
		out		0x00A0,		al
		rol		al,			1
		jmp		.testloop
	ret									; Will never get here

pic_register_test2:
	mov		al,			0x01
	.testloop2:
		mov		dl,			al
		out		PICM_P1,	al
		mov		al,			0x00		; Clear al
		in		al,			PICM_P1		; Retrieve al from register
		cmp		al,			dl
		jnz		.fail
		out		0x00A0,		al
		rol		al,			1
		jmp		.testloop2
	.fail:
		mov		al,		'F'
		call	print_char
		jmp		.testloop2
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

print_message2:
	; Send a NUL-terminated string to the LCD display;
	; In: DS:BX -> string to print
	; Return: AX = number of characters printed
	; All other registers preserved or unaffected.
	; **thank you, Damouze!

	push	bx 					; Save BX 
	push	cx 					; and CX onto the sack
	mov		cx, bx 				; Save contents of BX for later use
	
	.loop:
		mov		al, [bx] 		; Read byte from [DS:BX]
		or		al, al 			; Did we encounter a NUL character?
		jz		.return 		; If so, return to the caller
		call	print_char	 	; call our character print routine
		inc		bx 				; Increment the index
		jmp		.loop 			; And loop back
	
	.return: 
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

	mov		bp, 0x00FF
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
	mov		al,		0b10101000		; Go to line 2
	call	lcd_command_write
	ret

string_test db '80286 at 8 MHz!', 0x0

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

;***********************************************************************************************
times 0x3fff0-($-$$) nop	;Fill ROM with NOPs up to startup address
							;This will get to 0xFFFF0 

reset:						; at 0xFFFF0			*Processor starts reading here
	jmp 0xC000:0x0			; Jump to TOP: label

times 0x040000-($-$$) db 1	; Fill the rest of ROM with bytes of 0x01 (256 KB total)