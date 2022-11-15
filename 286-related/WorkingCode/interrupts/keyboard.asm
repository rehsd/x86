;Assembler: NASM
;
; *physical memory map*
;-----------------------
;-    ROM  (0.5 MB)    -
;-   0x80000-0xFFFFF   -
;-----------------------
;-    RAM  (0.5 MB)    -
;-   0x00000-0x7FFFF   -
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
	
	
	;PPI1 Configuration
	;							1=I/O Mode	|	00=Mode 0	|	1=PA In		|	0=PC (upper 4) Out	|	0=Mode 0	|	0=PB Out	|	0=PC (lower 4) Out
	CTL_CFG_PA_IN		equ		0b10010000		;0x90

	;							1=I/O Mode	|	00=Mode 0	|	0=PA Out	|	0=PC (uppper 4) Out	|	0=Mode 0	|	0=PB Out	|	0=PC (lower 4) Out
	CTL_CFG_PA_OUT		equ		0b10000000		;0x80
	

	RS	equ 0b00000001
	RW 	equ 0b00000010
	E 	equ 0b00000100

	;Interrupt Controller
	;Base address: 0x0010		;BUS_A1 connected to pin A0 of PIC
	PICM_P0		equ	0x0010		;PIC Master Port 0		ICW1				OCW2, OCW3
	PICM_P1		equ	0x0012		;PIC Master Port 1		ICW2, ICW3, ICW4	OCW1

	KBD_BUFSIZE equ 32					; Keyboard Buffer length. Must be a power of 2
	KBD_IVT_OFFSET equ 9*4				; Base address of keyboard interrupt (IRQ) in IVT  // 9*4=36=0x24
										; Keyboard: IRQ1, INT number 0x09 (* 4 bytes per INT)


section .bss
section .text	;start=0x8000	;vstart=0x80000	;start=0x80000

org		0x0000		;0x8000
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
mov		al,		0b10101000	; Go to line 2
call	lcd_command_write
mov		al,		'1'
call	lcd_data_write

;push 	cs 					; push CS onto the stack	
;pop 	ds 					; and pop it into DS so that DS is in ROM address space
;mov		bx,	string_test
;call	print_message2
;mov		ax,	0x0
;mov		ds, ax

										; kbd_isr is at physical address 0x80047. The following few lines move segment 8000 and offset 0047 into the IVT
mov word [KBD_IVT_OFFSET], kbd_isr		; DS set to 0x0000 above. These MOVs are relative to DS.
										; 0x0000:0x0024 = IRQ1 offset in IVT
mov		ax, 0x8000
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

								; OCW1: For bits, 0=unmask (enable interrupt), 1=mask
mov		al,			0b11010000	; Unmask IR0-IR7
out		PICM_P1,	al

mov		al,		'2'
call	lcd_data_write

sti										; Enable interrupts

;read out OCW1 - interrupt mask register - read OCW1
in		al,		PICM_P1			; Should retrieve 0b11010000 (set above) - *works - reads 0xFFD0 from the data bus
out		0x00A0,	al				; testing - *works - writes 0x00D0 to IO address 0x00A0 (no actual device on this IO address)

mov		al,		'3'
call	lcd_data_write

.main_loop:
	jmp .main_loop

kbd_isr:
	;to do save registers

	;do stuff
	mov		al,		'!'			;**not getting here
	call	lcd_data_write

	
	;to do restore registers
	mov		al,			0x20		; EOI byte for OCW2 (always 0x20)
	out		PICM_P0,	al			; to port for OCW2
	iret

print_message:
	mov		al,		'R'
	call	lcd_data_write
	mov		al,		'e'
	call	lcd_data_write
	mov		al,		'a'
	call	lcd_data_write
	mov		al,		'd'
	call	lcd_data_write
	mov		al,		'y'
	call	lcd_data_write
	mov		al,		'>'
	call	lcd_data_write
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
		call	lcd_data_write 	; call our character print routine
		inc		bx 				; Increment the index
		jmp		.loop 			; And loop back
	
	.return: 
		sub		bx, cx 			; Calculate our number of characters printed
		mov		ax, bx 			; And load the result into AX
		pop		cx 				; Restore CX
		pop		bx 				; and BX from the stack
		ret 					; Return to our caller

lcd_init:
	mov		al,		0b00111000	;0x38	; Set to 8-bit mode, 2 lines, 5x7 font
	call	lcd_command_write
	mov		al,		0b00001110	;0x0E	; LCD on, cursor on, blink off
	call	lcd_command_write
	mov		al,		0b00000001	;0x01	; clear LCD
	call	lcd_command_write
	mov		al,		0b00000110  ;0x06	; increment and shift cursor, don't shift display
	call	lcd_command_write
	ret

lcd_command_write:
	call	lcd_wait
	push	dx
	mov		dx,		PPI1_PORTA			; Get A port address
	out		dx,		al					; Send al to port A
	mov		dx,		PPI1_PORTB			; Get B port address
	mov		al,		E					; RS=0, RW=0, E=1
	out		dx,		al					; Write to port B
	nop									; wait for high-to-low pulse to be wide enough
	nop
	mov		al,		0x0					; RS=0, RW=0, E=0
	out		dx,		al					; Write to port B
	pop		dx
	ret

lcd_data_write:
	call	lcd_wait
	push	dx
	mov		dx,		PPI1_PORTA			; Get A port address
	out		dx,		al					; Write data (e.g. char) to port A
	mov		al,		(RS | E)			; RS=1, RW=0, E=1
	mov		dx,		PPI1_PORTB			; Get B port address
	out		dx,		al					; Write to port B - enable high
	nop									; wait for high-to-low pulse to be wide enough
	nop
	mov		al,		RS					; RS=1, RW=0, E=0
	out		dx,		al					; Write to port B - enable low
	pop		dx
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
	pusha
	mov		bp, 0x0000
	mov		si, 0x0001
	.delay2:
		dec		bp
		nop
		jnz		.delay2
		dec		si
		cmp		si,0    
		jnz		.delay2
	popa
	ret

string_test db '80286 at 8 MHz!', 0x0

;***********************************************************************************************
times 0x7fff0-($-$$) nop	;Fill ROM with NOPs up to startup address
							;This will get to 0xFFFF0 

reset:						;at 0xFFFF0			*Processor starts reading here
	jmp 0x8000:0x0				;EA	00 00 00 80		Jump to TOP: label

times 0x080000-($-$$) db 1	;Fill the rest of ROM with bytes of 0x01 (512 KB total)