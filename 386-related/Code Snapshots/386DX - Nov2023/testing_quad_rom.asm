; Last updated 19 July 2023
; Latest update : Creation
; Assembler: NASM
; Target clock :
;
; *physical memory map*
; ------------------------------ -
; -ROM(256 KB) -
; -0xC0000 - 0xFFFFF - To do: shrink to start at D0000, leaving room for sound card at 0xC0000
; ------------------------------ -
; -RAM Expansion(64 KB) - 64 KB window to 4 MB physical RAM
; -0xB0000 - 0xBFFFF -
; ------------------------------ -
; -VIDEO(64 KB) - 64 KB window to 2 MB physical VRAM
; -0xA0000 - 0xAFFFF -
; ------------------------------ -
; -RAM(640 KB) -
; -0x00000 - 0x9FFFF -
; ------------------------------ -
;
;**************************************
;
; from boot32.asm(can't use boot32lb.asm, as it requires a 386)
	;	+-------- +
	;	|        |
	;	|        |
	; | -------- | 4000:0000
	;	|        |
	; | FAT |
	;	|        |
	; | -------- | 2000:0000
	; | BOOT SEC |
	; | RELOCATE |
	; | -------- | 1FE0:0000
	;	|        |
	;	|        |
	;	|        |
	;	|        |
	; | -------- |
	; | BOOT SEC |
	; | ORIGIN | 07C0:0000
	; | -------- |
	;	|        |
	;	|        |
	;	|        |
	; | -------- |
	; | KERNEL |
	; | LOADED | @ 0070:0000 = I / O drivers
	; | -------- | 0060:0000
	; | BDA | BIOS Data Area(BDA) - https://stanislavs.org/helppc/bios_data_area.html
; | -------- | 0040:0000
;	|        | 0030:0000 - BIOS variables(VGA, SPI, Disk, ...)
;	|        | 0020:0000 - temporary buffer for reading info from CF card
; | IVT |
;	+-------- +
;
;
; Additional Comments
; PPI / LCD code adapted from "The 80x86 IBM PC and Compatible Computers..., 4th Ed." --Mazidi & Mazidi
; Sample interrupt code adapted from https ://stackoverflow.com/questions/51693306/registering-interrupt-in-16-bit-x86-assembly
; Sample interrupt code adapted from "The 80x86 IBM PC and Compatible Computers..., 4th Ed." --Mazidi & Mazidi
; https://tiij.org/issues/issues/fall2006/32_Jenkins-PIC/Jenkins-PIC.pdf
; 80286 Hardware Reference Manual, pg. 5 - 20
; http://www.nj7p.org/Manuals/PDFs/Intel/121500-001.pdf
;
; SPI SD Card routines
; Using HiLetgo Micro SD TF Card Reader - https://www.amazon.com/gp/product/B07BJ2P6X6
; Core logic adapted from George Foot's awesome page at https://hackaday.io/project/174867-reading-sd-cards-on-a-65026522-computer
; https://developpaper.com/sd-card-command-details/
; https://www.kingston.com/datasheets/SDCIT-specsheet-64gb_en.pdf
; RTC uses DS3234& supports SPI modes 1 or 2 (not 0 or 4).See https ://www.analog.com/en/analog-dialogue/articles/introduction-to-spi-interface.html for modes.
; RTC details : https://www.sparkfun.com/products/10160, https://www.sparkfun.com/datasheets/BreakoutBoards/DS3234.pdf

; VGA	640x480x2B(RGB565)
; Two frame buffers(0 & 1)
; Each frame buffer accessed through 64K address space of 0xA0000 - 0xAFFFF
; Register used to change frame buffers and select active segment of VRAM for address window
; Each frame buffer contains 1 MB of VRAM, with the bottom 0.5 MB of VRAM used by VGA output
; VGA control register at I / O 0x00A0
;		15 = Out Active Frame(read - only)
;		14 to 5 not used yet
;		4 = System(286) frame number * VGA Out is opposite frame number(automatically)
;		3 = System Segment_bit3
;		2 = System Segment_bit2
;		1 = System Segment_bit1
;		0 = System Segment_bit0

; !to do !
; -timer to track milliseconds(on VIA)
; -add \n processing to print_char_vga
; -add auto line wrap to print_char_vga
; -vector tables for interrupt handing instead of current branching approach
; -print hex word to SPI Nano(PC)
; -routine to set specific SPI CS low
; -routine to bring all SPI CS high
; -consolidation of similar procedures
; -improved code commenting
; -improved timing - e.g., reduce delays and nops in SPI - related code -- plenty of room for improvement
; -ensure all routines save register state and restore register state properly
; -bounds checks for typing chars -- wrap at end of line & bottom of screen
; -...

times 0x40000 - ($ - $$) db 0xff; not using first half of flash ROM

% include "macros.asm"

CPU			386
; BITS 		16
; sectalign	off

; section.data; align = GLOBAL_ALIGNMENT
; % include "_data.asm"
section.bss; align = GLOBAL_ALIGNMENT
% include "_bss.asm"
section.text; align = GLOBAL_ALIGNMENT

top : ; physically at 0xC0000

; ***SETUP REGISTERS**********************************
; xor eax, eax
; mov		ds, ax
; mov		eax, 0x0000fffe
; mov		ebp, eax
; mov		ss, ax
; mov		esp, ebp
; mov		eax, 0x0000f000; Read - only data in ROM
; mov		es, ax
; ***/ SETUP REGISTERS * ********************************

cli

basic_test_loop :
mov	dword[mem_test_tmp_dd], 0x00000000
.loop :
	mov eax, [mem_test_tmp_dd]
	call inc_test_mem
	jmp.loop

	inc_test_mem :
inc	dword[mem_test_tmp_dd]
ret

; times 0x30000 - ($ - $$) db 0xff; Fill much of ROM with FFs to allow for faster writing of flash ROMs
section.rodata; align = GLOBAL_ALIGNMENT; start = 0x30000
; % include "romdata.asm"

times 0x3ff00 - ($ - $$) db 0xff; fill remainder of section with FFs(faster flash ROM writes)
; very end overlaps.bootvector

; https://www.nasm.us/xdoc/2.15.05/html/nasmdoc7.html#section-7.3

section.bootvector	start = 0x7fff0
reset : ; at 0xFFFF0 * Processor starts reading here
jmp 0xc000:0x0; Jump to TOP : label

; times 0x040000 - ($ - $$) db 0xff; Fill the rest of ROM with bytes of 0x01 (256 KB total)
times 0x10 - ($ - $$) db 0xff; 16 - length of section so far(i.e., fill the rest of the section)