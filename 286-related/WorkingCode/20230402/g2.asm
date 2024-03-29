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
;section .bss
	; nothing here yet
section .text
	top:				; physically at 0xC0000

		;*** SETUP REGISTERS **********************************
		xor		ax,	ax
		mov		ds, ax
		mov		sp,	ax				; Start stack pointer at 0. It will wrap around (down) to FFFE.
		mov		ax,	0x0040			; First 1K is reserved for interrupt vector table,
		mov		ss,	ax				; Start stack segment at the end of the IVT.
		mov		ax, 0xf000			; Read-only data in ROM at 0x30000 (0xf0000 in address space  0xc0000+0x30000). 
									; Move es to this by default to easy access to constants.
		mov		es,	ax				; extra segment
		;*** /SETUP REGISTERS *********************************

		cli										; disable interrupts
		call	setup_interrupts				; populate IVT
		mov		dx, 0x0000						; init vga with black
		call	vga_init
		call	vga_post_screen
		; call	loading
		call	lcd_init						; initialize the two-line 1602 LCD
		mov		bx,	msg_loading
		call	print_message_lcd				; print message pointed to by bx to LCD
		call	keyboard_init					; initialize keyboard (e.g., buffer)
		call	mouse_init
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

		call	test_sound_card

		call	play_sound
		;call	vga_draw_test_pattern
		;call	draw_shapes
		

		mov		bx,	msg_286at10
		call	print_message_lcd				; print message pointed to by bx to LCD
		sti										; enable interrupts

		jmp		main_loop

resume:
		; to do - not all of the following should be necessary -- need to trim down

		;*** SETUP REGISTERS **********************************
		xor		ax,	ax
		mov		ds, ax
		mov		sp,	ax				; Start stack pointer at 0. It will wrap around (down) to FFFE.
		mov		ax,	0x0040			; First 1K is reserved for interrupt vector table,
		mov		ss,	ax				; Start stack segment at the end of the IVT.
		mov		ax, 0xf000			; Read-only data in ROM at 0x30000 (0xf0000 in address space  0xc0000+0x30000). 
									; Move es to this by default to easy access to constants.
		mov		es,	ax				; extra segment
		;*** /SETUP REGISTERS *********************************

		cli										; disable interrupts
		call	setup_interrupts				; populate IVT
		call	keyboard_init					; initialize keyboard (e.g., buffer)
		call	pic_init						; initialize PIC1 and PIC2
		
		add		word	[cursor_pos_v],		9
		mov		word	[cursor_pos_h],		0
		mov		bx,							msg_vga_prompt
		call	print_message_vga

		sti										; enable interrupts

		jmp		main_loop

main_loop:
		cli		; disable interrupts
		mov		al,		[kb_rptr]
		cmp		al,		[kb_wptr]
		sti		; enable interrupts
		jne		process_keyboard_buffer
		jmp		main_loop

%include "sound.asm"
%include "vga.asm"
%include "biosupdate.asm"
%include "post.asm"
%include "spi.asm"
%include "keyboard_mouse.asm"
%include "lcd.asm"
%include "os.asm"

setup_interrupts:
	push	ax

	mov ax, 0xC000
		
	mov word [DIVIDE_ER_IVT_OFFSET],		diverror_isr		; divide error
	mov	word [DIVIDE_ER_IVT_OFFSET+2],		ax

	mov word [OVERFLOW_IVT_OFFSET],			overflow_isr
	mov word [OVERFLOW_IVT_OFFSET+2],		ax

	mov word [INVALID_OP_IVT_OFFSET],		invalidop_isr
	mov word [INVALID_OP_IVT_OFFSET+2],		ax

	mov word [MULTIPLE_XCP_IVT_OFFSET],		multiplexcp_isr
	mov word [MULTIPLE_XCP_IVT_OFFSET+2],	ax

	; mov word [GEN_PROT_IVT_OFFSET],			geneneralprot_isr
	; mov word [GEN_PROT_IVT_OFFSET+2],		ax

	mov word [KBD_IVT_OFFSET],				keyboard_isr		; old version: kbd_isr		
	mov word [KBD_IVT_OFFSET+2],			ax			

	mov word [MOUSE_IVT_OFFSET],			mouse_isr
	mov word [MOUSE_IVT_OFFSET+2],			ax

	mov word [INT10H_IVT_OFFSET],			isr_video	
	mov word [INT10H_IVT_OFFSET+2],			ax		

	mov word [INT21H_IVT_OFFSET],			dos_services_isr
	mov word [INT21H_IVT_OFFSET+2],			ax

	mov word [INT31H_IVT_OFFSET],			mouse_services_isr
	mov word [INT31H_IVT_OFFSET+2],			ax

	pop		ax
	ret

diverror_isr:
		push	bx
		push	es
		push	0xf000
		pop		es
		call	lcd_clear
		mov		bx,	msg_xcp_diverr
		call	print_message_lcd				; print message pointed to by bx to LCD
		call	play_error_sound
		pop		es
		pop		bx
		iret

overflow_isr:
		push	bx
		push	es
		push	0xf000
		pop		es
		call	lcd_clear
		mov		bx,	msg_xcp_overflow
		call	print_message_lcd				; print message pointed to by bx to LCD
		call	play_error_sound
		pop		es
		pop		bx
		iret

invalidop_isr:
		push	bx
		push	es
		push	0xf000
		pop		es
		call	lcd_clear
		mov		bx,	msg_xcp_invalidop
		call	print_message_lcd				; print message pointed to by bx to LCD
		call	play_error_sound
		pop		es
		pop		bx
		iret

multiplexcp_isr:
		push	bx
		push	es
		push	0xf000
		pop		es
		call	lcd_clear
		mov		bx,	msg_xcp_multi
		call	print_message_lcd				; print message pointed to by bx to LCD
		call	play_error_sound
		pop		es
		pop		bx
		iret

geneneralprot_isr:
		push	bx
		push	es
		push	0xf000
		pop		es
		call	lcd_clear
		mov		bx,	msg_xcp_diverr
		call	msg_xcp_genprot				; print message pointed to by bx to LCD
		call	play_error_sound
		pop		es
		pop		bx
		iret
		
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

es_point_to_rom:
	push	ax
	
	;push	0xf000
	mov		ax, 0xf000			; Read-only data in ROM at 0x30000 (0xf0000 in address space  0xc0000+0c30000). 
								; Move es to this by default to easy access to constants.
	
	;pop		es
	mov		es,	ax				; extra segment
	
	pop		ax
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

strings_equal:
	;compare RAM string to ROM string
	;in ds:si = keyboard input string (in RAM)
	;in es:di = comparison string (lookup in ROM)
	;in cx = length of comparison
	;out ax = 1 when match, 0 when no match

	push	cx
	push	si
	mov		ax	,	0

	cld						;left to right or auto-increment mode 
	.loop:	
		cmpsb  				;compare until equal or cx=0
		jb	.out
		ja	.out
	;so far, matching
		inc	si				; the keyboard buffer is using a word per char, while the data in ROM to compare with is a byte, so skip the high byte of the buffer word
	loop .loop
	
	mov ax, 1	; all match, so set ax to 1
	.out:
		pop	si
		pop	cx
		ret

get_length_w: 
	; in: bx => pointing to string where each char is represented by a word
	; out: dx = length

	push	ax
	push	bx

	mov		dx,	0
	dec		bx
	.loop:  
		inc     bx
		inc		dx
		mov		al,	[bx]
		inc		bx		; skip the high byte of word
        cmp     al, 0
        jne     .loop

	dec		dx
	dec		dx
	pop		bx
	pop		ax
	ret

get_length_w2: 
	; in: bx => pointing to string where each char is represented by a word
	; out: dx = length

	push	ax
	push	bx

	mov		dx,	0
	dec		bx
	.loop:  
		inc     bx
		inc		dx
		mov		al,	[bx]
		inc		bx		; skip the high byte of word
        cmp     al, 0
        jne     .loop

	dec		dx
	;dec		dx
	pop		bx
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
	;mov		al,			0b11010000	; Unmask IR0-IR7
	;out		PICM_P1,	al

	pop		ax
	ret

print_string_to_serial:
	; Assuming string is in ROM .rodata section
	; Send a NUL-terminated string;
	; In: DS:BX -> string to print
	; Return: AX = number of characters printed
	; All other registers preserved or unaffected.

	push	bx 					; Save BX 
	push	cx 					; and CX onto the sack
	mov		cx, bx 				; Save contents of BX for later use
	
	.loop:
		mov		al, ES:[bx]		; Read byte from [DS:BX]
		or		al, al 			; Did we encounter a NUL character?
		jz		.return 		; If so, return to the caller
		mov		ah,		0x01	; spi cmd 1 - print char

		call	spi_send_NanoSerialCmd

		inc		bx 				; Increment the index
		jmp		.loop 			; And loop back
	
	.return: 
		sub		bx, cx 			; Calculate our number of characters printed
		mov		ax, bx 			; And load the result into AX
		pop		cx 				; Restore CX
		pop		bx 				; and BX from the stack
		ret 					; Return to our caller

nibble_to_hex:
	; Convert nibble to ASCII hex character
	; In:           AL = nibble
	; Return:       AL = hex character ('0' through '9', 'A' through 'F')
	; thank you, @Damouze
    
	and     al, 0x0f
    add     al, 0x90
    daa
    adc     al, 0x40
    daa
    ret

ToROM:
	push 	cs 					; push CS onto the stack	
	pop 	ds 					; and pop it into DS so that DS is in ROM address space
	ret

ToRAM:
	;push	ax
	;mov		ax,	0x0				; return DS back to 0x0
	;mov		ds, ax
	;pop		ax
	
	push		0x0
	pop			ds
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

delay_configurable:
	.loop:
		dec		bp
		nop
		jnz		.loop
		dec		si
		cmp		si,0    
		jnz		.loop
	ret

memcpy_b:
	; thank you, @Damouze!
	; memcpy(): copy data from DS:SI to ES:DI
	;
	; In:
	;		DS:SI -> source data
	;		ES:DI -> target buffer
	;		CX     = Number of bytes to copy
	; Return:
	;		All registers preserved
	;

	;
	; Preserve some registers first
	push	ds
	push	es
	push	si
	push	di
	push	cx

	rep		movsb

	.return:
		pop		cx
		pop		di
		pop		si
		pop		es
		pop		ds
		ret

memcpy_w:
	; thank you, @Damouze!
	; memcpy(): copy data from DS:SI to ES:DI
	;
	; In:
	;		DS:SI -> source data
	;		ES:DI -> target buffer
	;		CX     = Number of words to copy
	; Return:
	;		All registers preserved
	;

	;
	; Preserve some registers first
	push	ds
	push	es
	push	si
	push	di
	push	cx

	rep		movsw

	.return:
		pop		cx
		pop		di
		pop		si
		pop		es
		pop		ds
		ret



times 0x10000-($-$$)-2000 db 0xff	; Fill much of ROM with FFs to allow for faster writing of flash ROMs
section .wincom start=0x10000
times 0x0100 db 0x00
incbin "win.com"

times 0xA000 db 0xff	; Fill much of ROM with FFs to allow for faster writing of flash ROMs
section .doscomc start=0x20000
times 0x0100 db 0x00
incbin "hello_c.com"

times 0x05800 db 0xff	; Fill much of ROM with FFs to allow for faster writing of flash ROMs
section .commandcom start=0x28000
times 0x0100 db 0x00
incbin "hello_cpp.com"

		
times 0x3800 db 0xff	; Fill much of ROM with FFs to allow for faster writing of flash ROMs
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