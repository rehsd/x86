; Last updated 18 MAR 2023
; Latest update: Onboard BIOS update enhancements, file organization
; Assembler: NASM
; Target clock: Tested PCB v0.20 with 8 MHz CPU clock
;
; *physical memory map*
; -------------------------------
; -       ROM  (256 KB)			-
; -      0xC0000-0xFFFFF		-
; -------------------------------
; -   I/O & Expansion  (64 KB)	-
; -      0xB0000-0xBFFFF		-
; -------------------------------
; -       VIDEO  (64 KB)		-
; -      0xA0000-0xAFFFF		-
; -------------------------------
; -       RAM  (640 KB)			-
; -      0x00000-0x9FFFF		-
; -------------------------------
;
; **************************************
;
;       +--------+ 1FE0:7E00
;       |BOOT SEC|
;       |RELOCATE|
;       |--------| 1FE0:7C00
;       |LBA PKT |
;       |--------| 1FE0:7BC0
;       |--------| 1FE0:7BA0
;       |BS STACK|
;       |--------|
;       |4KBRDBUF| used to avoid crossing 64KB DMA boundary
;       |--------| 1FE0:63A0
;       |        |
;       |--------| 1FE0:3000
;       | CLUSTER|
;       |  LIST  |
;       |--------| 1FE0:2000
;       |        |
;       |--------| 0000:7E00
;       |BOOT SEC| overwritten by max 128k FAT buffer
;       |ORIGIN  | and later by max 134k loaded kernel
;       |--------| 0000:7C00
;       |        |
;       |--------|
;       | KERNEL | also used as max 128k FAT buffer
;       | LOADED | before kernel loading starts
;       |--------| 0060:0000
;       |        |
;       +--------+
;		|		 |
;		| KERNEL |
;		|  	     |
;		|--------| 0060:0000
;		|  BIOS  |
;		|  VARs  |
;		|  512B  |
;		|--------| 0040:0000
;		|	     |	
;		|   IVT  |
;		|  1024B |
;		|	     |
;		+--------+
;
;
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
; RTC uses DS3234 & supports SPI modes 1 or 2 (not 0 or 4). See https://www.analog.com/en/analog-dialogue/articles/introduction-to-spi-interface.html for modes.
; RTC details: https://www.sparkfun.com/products/10160, https://www.sparkfun.com/datasheets/BreakoutBoards/DS3234.pdf

; VGA	640x480x2B (RGB565)
; Two frame buffers (0 & 1)
; Each frame buffer accessed through 64K address space of 0xA0000-0xAFFFF
; Register used to change frame buffers and select active segment of VRAM for address window
; Each frame buffer contains 1 MB of VRAM, with the bottom 0.5 MB of VRAM used by VGA output
; VGA control register at I/O 0x00A0
;		15=Out Active Frame (read-only)
;		14 to 5 not used yet
;		4=System (286) frame number		*VGA Out is opposite frame number (automatically)
;		3=System Segment_bit3
;		2=System Segment_bit2
;		1=System Segment_bit1
;		0=System Segment_bit0

; ! to do !
; -timer to track milliseconds (on VIA)
; -add \n processing to print_char_vga
; -add auto line wrap to print_char_vga
; -vector tables for interrupt handing instead of current branching approach
; -print hex word to SPI Nano (PC)
; -routine to set specific SPI CS low
; -routine to bring all SPI CS high
; -consolidation of similar procedures
; -improved code commenting
; -improved timing - e.g., reduce delays and nops in SPI-related code -- plenty of room for improvement
; -ensure all routines save register state and restore register state properly
; -bounds checks for typing chars -- wrap at end of line & bottom of screen
; -...

%include "macros.mac"

cpu		286
bits 	16

section .data
	%include "_data.asm"
section .bss
	%include "_bss.asm"
section .text
	top:				; physically at 0xC0000

		;*** SETUP REGISTERS **********************************
		xor		ax,	ax
		mov		ds, ax
		;mov		sp,	ax				; Start stack pointer at 0. It will wrap around (down) to FFFE.
		mov		bp, 0x0060
		mov		ax,	0x0040			; First 1K is reserved for interrupt vector table,
		mov		ss,	ax				; Start stack segment at the end of the IVT.
		mov		sp,	bp
		mov		ax, 0xf000			; Read-only data in ROM at 0x30000 (0xf0000 in address space  0xc0000+0x30000). 
									; Move es to this by default to easy access to constants.
		mov		es,	ax				; extra segment
		;*** /SETUP REGISTERS *********************************

		cli										; disable interrupts
		call	setup_interrupts				; populate IVT
		mov		dx, 0x0000						; init vga with black
		mov		word [vga_param_color],	0xffff	; set text color
		call	vga_init
		call	vga_post_screen
		; call	loading
		call	lcd_init						; initialize the two-line 1602 LCD
		mov		bx,	msg_loading
		call	print_message_lcd				; print message pointed to by bx to LCD
		call	keyboard_init					; initialize keyboard (e.g., buffer)
		;call	mouse_init
		call	spi_init						; initialize SPI communications, including VIA1
		call	spi_sdcard_init					; initialize the SD Card (SPI)
		;call	spi_8char7seg_init				; initialize the 8-char 7-seg LED display
		call	oled_init						; initialize the OLED 128x64 display on the Arduino Nano
		call	post_tests						; call series of power on self tests
		call	pic_init						; initialize PIC1 and PIC2
		call	lcd_clear
		call	rtc_getTemp						; get temperature from RTC
		call	rtc_getTime						; get time from RTC
		call	lcd_line2

		;call	test_sound_card


		mov		bx,	msg_286at11
		call	print_message_lcd				; print message pointed to by bx to LCD

		mov		al, '$'
		call	print_char_spi

		call	ide_identify_drive
		call	print_char_newline_spi

		mov		al, '>'
		call	print_char_spi
		sti										; enable interrupts

		call	play_sound

		call	load_bootloader

		jmp		main_loop

;resume:
;		; to do - not all of the following should be necessary -- need to trim down
;
;		;*** SETUP REGISTERS **********************************
;		xor		ax,	ax
;		mov		ds, ax
;		mov		sp,	ax				; Start stack pointer at 0. It will wrap around (down) to FFFE.
;		mov		ax,	0x0040			; First 1K is reserved for interrupt vector table,
;		mov		ss,	ax				; Start stack segment at the end of the IVT.
;		mov		ax, 0xf000			; Read-only data in ROM at 0x30000 (0xf0000 in address space  0xc0000+0x30000). 
;									; Move es to this by default to easy access to constants.
;		mov		es,	ax				; extra segment
;		;*** /SETUP REGISTERS *********************************
;
;		cli										; disable interrupts
;		call	setup_interrupts				; populate IVT
;		call	keyboard_init					; initialize keyboard (e.g., buffer)
;		call	pic_init						; initialize PIC1 and PIC2
;		
;		add		word	[cursor_pos_v],		9
;		mov		word	[cursor_pos_h],		0
;		mov		bx,							msg_vga_prompt
;		call	print_message_vga
;
;		sti										; enable interrupts
;
;		jmp		main_loop

main_loop:
	push	ds
	call	to0000ds
	cli		; disable interrupts
	mov		al,		[kb_rptr]
	cmp		al,		[kb_wptr]
	pop		ds
	sti		; enable interrupts
	jne		process_keyboard_buffer
	jmp		main_loop

%include "sound.asm"
%include "vga.asm"
;%include "biosupdate.asm"
%include "post.asm"
%include "spi.asm"
%include "keyboard_mouse.asm"
%include "lcd.asm"
;%include "os.asm"				;replace with freeDOS
%include "disk.asm"
%include "isrs_general.asm"
%include "isrs_empty.asm"
%include "util.asm"
%include "debug.asm"

load_bootloader:
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

	mov		al,		'}'
	call	print_char_spi
	call	print_char_newline_spi


	;;; print copied data out to screen
	mov		cx,		256				; number of words to print
	mov		bx,		0x7c00
	call	print_buffer_hex

	call	print_char_newline_spi
	;mov		al,		':'
	;call	print_char_spi
	;mov		al,		')'
	;call	print_char_spi
	;call	print_char_newline_spi

	;mov		al,		ds:[0x7c00]
	;call	print_char_hex_spi
	;mov		al,		ds:[0x7c01]
	;call	print_char_hex_spi
	;mov		al,		ds:[0x7c02]
	;call	print_char_hex_spi
	;mov		al,		ds:[0x7c03]
	;call	print_char_hex_spi

	mov		dl,	0x80			;c drive
	jmp		0x0000:0x7c00


setup_interrupts:
	;assuming ds = 0x0000

	push	ax

	mov ax, 0xC000
		
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

	mov word [MULTIPLE_XCP_IVT_OFFSET],		multiplexcp_isr		;								0x08
	mov word [MULTIPLE_XCP_IVT_OFFSET+2],	ax

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
	
loading:
	push	bx
	mov		word [print_char_options], 0b00000000_00000001		; no frame swap
	mov		word [cursor_pos_h],		290
	mov		word [cursor_pos_v],		200
	mov		bx,							msg_loading
	call	print_message_vga
	call	vga_swap_frame
	mov		word [print_char_options], 0b00000000_00000000		; restore default of frame swap
	pop		bx
	ret

reboot:
	mov		ax,	CMD_RESET_286						; Reset entire 286 system
	call	spi_send_NanoSerialCmd
	
	; the following lines shouldn't be reachable, as the system should now be restarting
	call	delay
	ret

oled_init:
	mov		ax,	CMD_OLED_RESET						; cmd06 = OLED init / reset, no param
	call	spi_send_NanoSerialCmd
	call	delay
	ret

rtc_getTemp:
	; addr 0x11 = temp msb
	; addr 0x12 = temp lsb

	mov		al,			0x11
	call	spi_read_RTC
	
	call	print_char_dec
	
	; decimal portion - skipping for now
	; mov		al,			0x12
	; call	spi_read_RTC

	mov		al,			' '
	call	print_char

	mov		al,			'C'
	call	print_char

	ret

rtc_setTime:
	; addr 0x82 = hours
	; addr 0x81 = minutes
	; addr 0x80 = seconds

	; ** HOURS **
	mov		ax,			0x8208		; Set to 08:00:00 for testing
	call	spi_write_RTC			; bit 4 = 10s, low nibble 1s

	ret

rtc_getTime:
	; addr 0x02 = hours
	; addr 0x01 = minutes
	; addr 0x00 = seconds

	mov		al,			' '
	call	print_char
	mov		al,			' '
	call	print_char
	mov		al,			' '
	call	print_char
	mov		al,			' '
	call	print_char

	; ** HOURS **
	mov		al,			0x02
	call	spi_read_RTC			; bit 4 = 10s, low nibble 1s
	and		al,			0b00111111
	call	print_char_hex

	; ** MINUTES **
	mov		al,			':'
	call	print_char
	mov		al,			0x01		; high nibble 10s, low nibble 1s
	call	spi_read_RTC
	call	print_char_hex
	
	; ** SECONDS **
	mov		al,			':'
	call	print_char
	mov		al,			0x00		; high nibble 10s, low nibble 1s
	call	spi_read_RTC
	call	print_char_hex
	
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
	;mov		al,			0b11010000	; Unmask IR0-IR7
	;out		PICM_P1,	al

	pop		ax
	ret


;section .bootloader start=0x7c00
;bootloader_loc:

;times 0x10000-($-$$)-3000 db 0xff	; Fill much of ROM with FFs to allow for faster writing of flash ROMs
;section .wincom start=0x10000
;times 0x0100 db 0x00
;incbin "win.com"

;times 0xA000 db 0xff	; Fill much of ROM with FFs to allow for faster writing of flash ROMs
;section .doscomc start=0x20000
;times 0x0100 db 0x00
;incbin "hello_c.com"

;times 0x05800 db 0xff	; Fill much of ROM with FFs to allow for faster writing of flash ROMs
;section .commandcom start=0x28000
;times 0x0100 db 0x00
;incbin "command.com"
		
;times 0x3800 db 0xff	; Fill much of ROM with FFs to allow for faster writing of flash ROMs

times 0x30000-($-$$) db 0xff	; Fill much of ROM with FFs to allow for faster writing of flash ROMs
section .rodata start=0x30000
%include "romdata.asm"

times 0x0fff0 - ($-$$) db 0xff		; fill remainder of section with FFs (faster flash ROM writes)
									; very end overlaps .bootvector

; https://www.nasm.us/xdoc/2.15.05/html/nasmdoc7.html#section-7.3
section .bootvector	start=0x3fff0
	reset:						; at 0xFFFF0			*Processor starts reading here
		jmp 0xc000:0x0			; Jump to TOP: label

; times 0x040000-($-$$) db 0xff	; Fill the rest of ROM with bytes of 0x01 (256 KB total)
times 0x10 - ($-$$) db 0xff		; 16 - length of section so far (i.e., fill the rest of the section)