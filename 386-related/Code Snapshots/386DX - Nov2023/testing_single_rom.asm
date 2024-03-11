; Last updated 12 November 2023
; Latest update: VIA init/test
; Assembler: NASM
; Target clock: sloooooow
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
;

%include "macros.asm"

CPU			386
;BITS 		16
;sectalign	off

section .data ;align=GLOBAL_ALIGNMENT
	%include "_data.asm"
section .bss ;align=GLOBAL_ALIGNMENT
	%include "_bss.asm"
section .text ;align=GLOBAL_ALIGNMENT

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

		call	spi_init						; initialize SPI communications, including VIA1


		mov		al, '$'
		call	print_char_spi
		call	print_char_newline_spi
		mov		bx,		msg_386atX
		call	print_string_to_serial
		
		mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_POST_COMPLETE
		call	spi_send_NanoSerialCmd

		mov		dx, 0x0000						; init vga with black
		mov		word [vga_param_color],	0xffff	; set text color
		call	vga_init


		hlt

;%includes
%include "via.asm"
%include "vga.asm"
%include "util.asm"
%include "spi.asm"

basic_test_loop:
	mov	dword [mem_test_tmp_dd], 0x00000000
	.loop:
		mov eax, [mem_test_tmp_dd]
		call inc_test_mem
	jmp .loop

inc_test_mem:
	inc	dword [mem_test_tmp_dd]
	ret


times 0x10000-($-$$) db 0xff	; Fill much of ROM with FFs to allow for faster writing of flash ROMs
section .rodata ;align=GLOBAL_ALIGNMENT	; start=0x10000	
%include "romdata.asm"

times 0x0FF00 - ($-$$) db 0xff		; fill remainder of section with FFs (faster flash ROM writes)
									; very end overlaps .bootvector

; https://www.nasm.us/xdoc/2.15.05/html/nasmdoc7.html#section-7.3

section .bootvector	start=0x1fff0
	reset:						; at 0xFFFF0			*Processor starts reading here
		jmp 0xe000:0x0			; Jump to TOP: label

; times 0x040000-($-$$) db 0xff	; Fill the rest of ROM with bytes of 0x01 (256 KB total)
times 0x10 - ($-$$) db 0xff		; 16 - length of section so far (i.e., fill the rest of the section)