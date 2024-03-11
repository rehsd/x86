; Last updated 24 November 2023
; Latest update: Keyboard, Mouse, PIC
; Assembler: NASM
; Target CLK2 speed: 24 MHz or 12 MHz
;
; *physical memory map*
; -------------------------------
; -     ROM shadow (128 KB)		-
; -      0xE0000-0xFFFFF		-
; -------------------------------
; ------------future-------------
; -------------------------------
; -       VIDEO  (64 KB)		-				64 KB window to 2 MB physical VRAM
; -      0xA0000-0xAFFFF		-
; -------------------------------
; -       RAM  (640 KB)			-
; -      0x00000-0x9FFFF		-
; -------------------------------
;
; **************************************

; ** I/O **
; PIC		0x0010:0x0017		Uses 0x0010, 0x0014
; 486DLC	0x0022:0x0023		Cache management
; VIA		0x0040:0x007F		16 registers
; IDE		0x0080:0x009F
; VGA_REG	0x00A0:0x00A7		Only uses A0.

; * TO DO *
; -PC speaker tone generation (connect to SPI Nano)
; -Change 1602 LCD debug output to OLED and uncomment ;; lines
; 

%include "macros.asm"

CPU			486
BITS 		16
sectalign	off

section .data align=GLOBAL_ALIGNMENT
	%include "_data.asm"
section .bss align=GLOBAL_ALIGNMENT
	%include "_bss.asm"
section .text align=GLOBAL_ALIGNMENT

top:				; physically at 0xE0000

		;*** SETUP REGISTERS **********************************
		xor		eax,	eax						; zero out eax
		mov		ds,		ax						; data segment to 0000
		mov		ebp,	0x0000fffc				; base pointer to fffc
		mov		ss,		ax						; stack segment to 0000
		mov		esp,	ebp						; set stack pointer to fffc and decrement from there
		mov		eax,	0x0000f000				
		mov		es,		ax						; ROM data (in RAM) at f0000 (see "times" at bottom of this file)
		;*** /SETUP REGISTERS *********************************

		cli

		call	init_bda
		call	setup_interrupts				; populate IVT


		mov		dx, 0x0000						; init vga with black
		mov		word [vga_param_color],	0xffff	; set text color
		call	vga_init

		mov		byte [text_output_wptr],		0x00
		call	clear_text_output_buffer
		call	vga_post_screen

		call	keyboard_init					; initialize keyboard (e.g., buffer)
		;call	mouse_init

		call	spi_init						; initialize SPI communications, including VIA1
		;call	oled_init						; initialize the OLED 128x64 display on the Arduino Nano
		;call	post_tests						; call series of power on self tests
		
		call	print_char_newline_spi
		mov		bx,		msg_386atX
		call	print_string_to_serial
		
		call	pic_init						; initialize PIC1 and PIC2
		call	ide_identify_drive

		mov		word [vga_param_color],		0b11000_110000_11000		; change font color

		;mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_POST_COMPLETE
		;call	spi_send_NanoSerialCmd


		jmp		load_bootloader

blackHole:
	jmp	blackHole

;%includes
%include "via.asm"
%include "vga.asm"
%include "util.asm"
%include "spi.asm"
%include "keyboard_mouse.asm"
%include "disk.asm"
%include "isrs_general.asm"
%include "isrs_empty.asm"

load_bootloader:
	;ds0000
	;call	es_point_to_rom
	;mov		dx, 0x0000						; init vga with black
	;call	vga_init


	;;; load bootloader (copy data)

	push	es

	mov		ax,		0x0000			; es:bx = pointer to buffer / destination
	mov		es,		ax
	mov		bx,		0x7c00
	mov		ah,		0x02			; function 0x02
	mov		al,		0x01			; number of sectors to read
	mov		dl,		0x80			; drive 0
	mov		dh,		0x00			; head 0			; MBR
	;mov		dh,		0x01			; head 1				; DOS boot sector
	mov		cl,		0x01			; sector number, 1-based, bottom six bits; cylinder high, top two bits
	mov		ch,		0x00			; cylinder low
	call	ide_read

	pop		es


	;;; print copied data out to screen
	;mov		cx,		256				; number of words to print
	;mov		bx,		0x7c00
	;call	print_buffer_hex
	;call	print_char_newline_spi

	
	call	via_timer_init					; initialize timer T1 on VIA for IRQ0 (interrupt 8)
	sti

	;to do clear up stuff on stack that won't be used anymore before jumping
	mov		dl,	0x80			;c drive
	jmp		0x0000:0x7c00

init_bda:
	push	ds
	push	ax
	push	di
	call	to0000ds

	;40:10  2 bytes	Equipment list flags (see INT 11)
	;
	;	|7|6|5|4|3|2|1|0| 40:10 (value in INT 11 register AL)
	;	 | | | | | | | `- IPL diskette installed
	;	 | | | | | | `-- math coprocessor
	;	 | | | | |-+--- old PC system board RAM < 256K
	;	 | | | | | `-- pointing device installed (PS/2)
	;	 | | | | `--- not used on PS/2
	;	 | | `------ initial video mode
	;	 `--------- # of diskette drives, less 1
	;
	;	|7|6|5|4|3|2|1|0| 40:11  (value in INT 11 register AH)
	;	 | | | | | | | `- 0 if DMA installed
	;	 | | | | `------ number of serial ports
	;	 | | | `------- game adapter
	;	 | | `-------- not used, internal modem (PS/2)
	;	 `----------- number of printer ports
	
		mov		ah,					0b00000000
		mov		al,					0b00100010					;80x25 color & math co
		mov		[equipment_list],	ax
	
	;40:13
	mov		word [memory_size],		640

	;40:17
	mov		word [keyboard_flags], 0x0000

	;40:1a to 40:3d - keyboard buffer
	;mov		ax,					kbd_buff
	mov		word [kbd_buff_head],	0x001e
	;mov		ax,					kbd_buff
	mov		word [kbd_buff_tail],	0x001e
	mov		di,				0
	.clear_kbd_buffer:
		mov		word [kbd_buff+di],		0x0000
		add		di, 2
		cmp		di, 32
		jne		.clear_kbd_buffer


	;40:49 - current video mode
	mov		byte [video_mode],	0x12		;640x480 16 color graphics (VGA)

	;40:4a - Number of screen columns
	mov		word [screen_cols],	640		;or should this be # of columns in chars?

	;40:6c - daily timer counter
	mov		word [clock_counter+2], 0x0000	; zero out clock counter
	mov		word [clock_counter],	0x0000	; 

	;40:80 - keyboard buffer start offset (seg 40h), end offset
	mov		[kbd_buff_start_offset],	word 0x001e
	mov		[kbd_buff_end_offset],		word 0x003d

	;40:84 - Rows on the screen (less 1, EGA+)
	mov		word [screen_rows],		639

	;40:96 - Keyboard mode/type
	mov		byte [kbd_mode], 0

	pop		di
	pop		ax
	pop		ds
	ret

setup_interrupts:
	;assuming ds = 0x0000

	push	ax

	mov ax, ROM_START
		
	mov word [DIVIDE_ER_IVT_OFFSET],		diverror_isr		; divide error					0x00
	mov	word [DIVIDE_ER_IVT_OFFSET+2],		ax

	mov word [IVT_INT_01H],					isr_int_01h			;								0x01
	mov	word [IVT_INT_01H+2],		ax

	mov word [IVT_INT_02H],					isr_int_02h			;								0x02
	mov	word [IVT_INT_02H+2],		ax

	mov word [IVT_INT_03H],					isr_int_03h			;								0x03
	mov	word [IVT_INT_03H+2],		ax

	mov word [OVERFLOW_IVT_OFFSET],			overflow_isr		; overflow						0x04
	mov word [OVERFLOW_IVT_OFFSET+2],		ax

	mov word [IVT_INT_05H],					isr_int_05h			;								0x05
	mov	word [IVT_INT_05H+2],		ax

	mov word [INVALID_OP_IVT_OFFSET],		invalidop_isr		;								0x06
	mov word [INVALID_OP_IVT_OFFSET+2],		ax

	mov word [IVT_INT_07H],					isr_int_07h			;								0x07
	mov	word [IVT_INT_07H+2],		ax

	mov word [IVT_INT_08H],					isr_int_08h			; timer							0x08
	mov word [IVT_INT_08H+2],		ax

	mov word [KBD_IVT_OFFSET],				keyboard_isr		; old version: kbd_isr			0x09	
	mov word [KBD_IVT_OFFSET+2],			ax			

	;mov word [MOUSE_IVT_OFFSET],			mouse_isr			;								0x0a
	;mov word [MOUSE_IVT_OFFSET+2],			ax
	
	mov word [IVT_INT_0BH],					isr_int_0Bh			;								0x0b
	mov	word [IVT_INT_0BH+2],		ax

	mov word [IVT_INT_0CH],					isr_int_0Ch			;								0x0c
	mov	word [IVT_INT_0CH+2],		ax

	mov word [IVT_INT_0DH],					isr_int_0Dh			;								0x0d
	mov	word [IVT_INT_0DH+2],		ax

	mov word [IVT_INT_0EH],					isr_int_0Eh			;								0x0e
	mov	word [IVT_INT_0EH+2],		ax

	mov word [IVT_INT_0FH],					isr_int_0Fh			;								0x0f
	mov	word [IVT_INT_0FH+2],		ax

	mov word [INT10H_IVT_OFFSET],			isr_video			;								0x10
	mov word [INT10H_IVT_OFFSET+2],			ax		

	mov word [IVT_INT_11H],					isr_int_11h			;								0x11
	mov	word [IVT_INT_11H+2],		ax
	mov word [IVT_INT_12H],					isr_int_12h			;								0x12
	mov	word [IVT_INT_12H+2],		ax
	mov word [INT13H_IVT_OFFSET],			isr_int_13h			;								0x13
	mov	word [INT13H_IVT_OFFSET+2], ax
	mov word [IVT_INT_14H],					isr_int_14h			;								0x14
	mov	word [IVT_INT_14H+2],		ax
	mov word [IVT_INT_15H],					isr_int_15h			;								0x15
	mov	word [IVT_INT_15H+2],		ax
	mov word [IVT_INT_16H],					isr_int_16h			;								0x16
	mov	word [IVT_INT_16H+2],		ax
	mov word [IVT_INT_17H],					isr_int_17h			;								0x17
	mov	word [IVT_INT_17H+2],		ax
	mov word [IVT_INT_19H],					isr_int_19h			;								0x19
	mov	word [IVT_INT_19H+2],		ax
	mov word [IVT_INT_1AH],					isr_int_1ah			;								0x1a
	mov	word [IVT_INT_1AH+2],		ax
	mov word [IVT_INT_1BH],					isr_int_1bh			;								0x1b
	mov	word [IVT_INT_1BH+2],		ax
	mov word [IVT_INT_1CH],					isr_int_1ch			;								0x1c
	mov	word [IVT_INT_1CH+2],		ax
	mov word [IVT_INT_1DH],					isr_int_1dh			;								0x1d
	mov	word [IVT_INT_1DH+2],		ax
	mov word [IVT_INT_1EH],					isr_int_1eh			;								0x1e
	mov	word [IVT_INT_1EH+2],		ax
	mov word [IVT_INT_1FH],					isr_int_1fh			;								0x1f
	mov	word [IVT_INT_1FH+2],		ax
	mov word [IVT_INT_20H],					isr_int_20h			;								0x20
	mov	word [IVT_INT_20H+2],		ax
	mov word [INT21H_IVT_OFFSET],			dos_services_isr	;								0x21
	mov word [INT21H_IVT_OFFSET+2],			ax
	mov word [IVT_INT_22H],					isr_int_22h			;								0x22
	mov	word [IVT_INT_22H+2],		ax
	mov word [IVT_INT_23H],					isr_int_23h			;								0x23
	mov	word [IVT_INT_23H+2],		ax
	mov word [IVT_INT_24H],					isr_int_24h			;								0x24
	mov	word [IVT_INT_24H+2],		ax
	mov word [IVT_INT_25H],					isr_int_25h			;								0x25
	mov	word [IVT_INT_25H+2],		ax
	mov word [IVT_INT_26H],					isr_int_26h			;								0x26
	mov	word [IVT_INT_26H+2],		ax
	mov word [IVT_INT_27H],					isr_int_27h			;								0x27
	mov	word [IVT_INT_27H+2],		ax
	mov word [IVT_INT_28H],					isr_int_28h			;								0x28
	mov	word [IVT_INT_28H+2],		ax
	mov word [IVT_INT_29H],					isr_int_29h			;								0x29
	mov	word [IVT_INT_29H+2],		ax
	mov word [IVT_INT_2AH],					isr_int_2ah			;								0x2a
	mov	word [IVT_INT_2AH+2],		ax
	mov word [IVT_INT_2BH],					isr_int_2bh			;								0x2b
	mov	word [IVT_INT_2BH+2],		ax
	mov word [IVT_INT_2CH],					isr_int_2ch			;								0x2c
	mov	word [IVT_INT_2CH+2],		ax
	mov word [IVT_INT_2DH],					isr_int_2dh			;								0x2d
	mov	word [IVT_INT_2DH+2],		ax
	mov word [IVT_INT_2EH],					isr_int_2eh			;								0x2e
	mov	word [IVT_INT_2EH+2],		ax
	mov word [IVT_INT_2FH],					isr_int_2fh			;								0x2f
	mov	word [IVT_INT_2FH+2],		ax

	mov word [INT33H_IVT_OFFSET],			mouse_services_isr	;								0x33
	mov word [INT33H_IVT_OFFSET+2],			ax

	;mov word [INT34H_IVT_OFFSET],			0		; custom mouse button event to c++			0x34
	;mov word [INT34H_IVT_OFFSET+2],			0

	pop		ax
	ret

pic_init:
	push	ax
									; ICW1: 0001 | LTIM (1=level, 0=edge) | Call address interval (1=4, 0=8) | SNGL (1=single, 0=cascade) | IC4 (1=needed, 0=not)
	mov		al,			0b00010111			;0x17		ICW1 - edge, master, ICW4
	out		PICM_P0,	al

									; ICW2: Interrupt assigned to IRQ0 of the 8259 (usually 0x08)
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
	;mov		al,			0b11010000	; Unmask IR7-IR0
	;mov		al,			0b11111101	; Unmask ONLY IR1 keyboard
	;out		PICM_P1,	al

	pop		ax
	ret

oled_init:
	push	eax
	mov		ax,	CMD_OLED_RESET						; cmd06 = OLED init / reset, no param
	call	spi_send_NanoSerialCmd
	call	delay
	pop		eax
	ret

times 0x10000-($-$$) db 0xff	; Fill much of ROM with FFs to allow for faster writing of flash ROMs
section .rodata start=0x10000 align=GLOBAL_ALIGNMENT	
%include "romdata.asm"

times 0x0FF00 - ($-$$) db 0xff		; fill remainder of section with FFs (faster flash ROM writes)
									; very end overlaps .bootvector

; https://www.nasm.us/xdoc/2.15.05/html/nasmdoc7.html#section-7.3

section .bootvector	start=0x1fff0
	reset:						; at 0xFFFF0			*Processor starts reading here
		jmp 0xe000:0x0			; Jump to TOP: label

; times 0x040000-($-$$) db 0xff	; Fill the rest of ROM with bytes of 0x01 (256 KB total)
times 0x10 - ($-$$) db 0xff		; 16 - length of section so far (i.e., fill the rest of the section)