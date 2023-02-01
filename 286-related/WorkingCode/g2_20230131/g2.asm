; Last updated 31 JAN 2023
; Latest update: Shapes & macros
; Assembler: NASM
; Target clock: Tested PCB v0.20 with 8 MHz CPU clock
;
; *physical memory map*
; -----------------------
; -    ROM  (256 KB)    -
; -   0xC0000-0xFFFFF   -
; -----------------------
; -   UNUSED  (64 KB)   -
; -   0xB0000-0xBFFFF   -
; -----------------------
; -   VIDEO  (64 KB)   -
; -   0xA0000-0xAFFFF   -
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
; RTC supports SPI modes 1 or 2 (not 0 or 4). See https://www.analog.com/en/analog-dialogue/articles/introduction-to-spi-interface.html for modes.

; VGA	640x480x1B (RRRGGGBB)
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
; -routine to set specific CS low
; -routine to bring all CS high
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

	; EQU's

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
		;Base address: 0x0010						; BUS_A1 connected to pin A0 of PIC
		PICM_P0				equ	0x0010				; PIC Master Port 0		ICW1				OCW2, OCW3
		PICM_P1				equ	0x0012				; PIC Master Port 1		ICW2, ICW3, ICW4	OCW1
		; ********************************

		; ***** Video register *****
		VGA_REG				equ 0x00a0				; Control register for VGA 640 card
		; **************************

		KBD_BUFSIZE			equ 32					; Keyboard Buffer length. Must be a power of 2
		KBD_IVT_OFFSET		 equ 9*4				; Base address of keyboard interrupt (IRQ) in IVT  // 9*4=36=0x24
													; Keyboard: IRQ1, INT number 0x09 (* 4 bytes per INT)

		RELEASE		equ		0b0000000000000001
		SHIFT		equ		0b0000000000000010

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


		CMD_RESET							equ 0x0000		; General Reset of Nano
		CMD_PRINT_CHAR						equ 0x0100      ; Print to Serial
		CMD_PRINT_HEX8						equ 0x0200      ; Print to Serial
		CMD_PRINT_BINARY8					equ 0x0300      ; Print to Serial
		CMD_PRINT_HEX16						equ 0x0400      ; Print to Serial
		CMD_PRINT_BINARY16					equ 0x0500		; Print to Serial
		CMD_OLED_RESET						equ	0x0600		; Reset OLED
		CMD_PRINT_CHAR_OLED					equ 0x0700		; Print to OLED
		CMD_PRINT_STATUS_OLED				equ 0x0800		; Print to OLED
		CMD_CLEAR_OLED						equ 0x0900		; Clear OLED
		;xxx								equ 0x0A00		; ...

		OLED_STATUS_RAM_TEST_BEGIN			equ	1;
		OLED_STATUS_RAM_TEST_FINISH			equ	2;
		OLED_STATUS_PPI1_TEST_BEGIN			equ 3;
		OLED_STATUS_PPI1_TEST_FINISH		equ 4;
		OLED_STATUS_PPI2_TEST_BEGIN			equ 5;
		OLED_STATUS_PPI2_TEST_FINISH		equ 6;
		OLED_STATUS_VIA1_TEST_BEGIN			equ 7;
		OLED_STATUS_VIA1_TEST_FINISH		equ 8;
		OLED_STATUS_MATHCO_TEST_BEGIN		equ 9;
		OLED_STATUS_MATHCO_TEST_FINISH		equ 10;
		OLED_STATUS_PIC_TEST_BEGIN			equ 11;
		OLED_STATUS_PIC_TEST_FINISH			equ 12;
		OLED_STATUS_VRAM_TEST_BEGIN			equ	13;
		OLED_STATUS_VRAM_TEST_FINISH		equ	14;
		OLED_STATUS_VGA_REG_TEST_BEGIN		equ	15;
		OLED_STATUS_VGA_REG_TEST_FINISH		equ	16;

		OLED_STATUS_RAM_TEST_FAIL			equ 20;
		OLED_STATUS_PPI1_TEST_FAIL			equ 21;
		OLED_STATUS_PPI2_TEST_FAIL			equ 22;
		OLED_STATUS_VIA1_TEST_FAIL			equ 23;
		OLED_STATUS_MATHCO_TEST_FAIL		equ 24;
		OLED_STATUS_PIC_TEST_FAIL			equ 25;
		OLED_STATUS_VRAM_TEST_FAIL			equ 26;
		OLED_STATUS_VGA_REG_TEST_FAIL		equ 27;

		OLED_STATUS_POST_COMPLETE			equ 50;
		OLED_STATUS_EXCEPTION				equ 100;

		PIXEL_COL1							equ	0b10000000
		PIXEL_COL2							equ 0b01000000
		PIXEL_COL3							equ 0b00100000
		PIXEL_COL4							equ 0b00010000
		PIXEL_COL5							equ 0b00001000

	; VARs
	varstart:
		ivt times 1024			db		0xaa				; prevent writing in the same space as the IVT
		mem_test_tmp			dw		0x0					; used for RAM testing
		ppi1_ccfg				db		0x0					; current config for PPI1
		ppi2_ccfg				db		0x0					; current config for PPI2
		spi_state_b				db		0x0					; track CS state for spi on via port b
		spi_state_a				db		0x0					; track CS state for spi on via port a

		AREA					dd		0x0					; store result of area calculation

		dec_num					db		0x0
		dec_num100s				db		0x0
		dec_num10s				db		0x0
		dec_num1s				db		0x0

		kb_flags				dw		0x0					; track status of keyboard input
		kb_wptr					dw		0x0					; keyboard buffer write pointer
		kb_rptr					dw		0x0					; keyboard buffer read pointer
		kb_buffer times 256		dw      0x0					; 256-byte keyboard buffer
		clear_screen_flag		dw		0x0					; if set, need to clear screen

		current_char			dw		0x0					; current char for VGA output
		cursor_pos_h			dw		0x0					; horizontal position (pixel #) of text cursor
		cursor_pos_v			dw		0x0					; vertical position (pixel #) of text cursor
		pixel_offset_h			dw		0x0
		pixel_offset_v			dw		0x0
		charPixelRowLoopCounter	dw		0x0					; row pos when processing a char
		charpix_line1			db		0x0
		charpix_line2			db		0x0
		charpix_line3			db		0x0
		charpix_line4			db		0x0
		charpix_line5			db		0x0
		charpix_line6			db		0x0
		charpix_line7			db		0x0

		sprite_inc				db		0x0
		vga_param_color			dw		0x0
		vga_rect_start_x		dw		0x0
		vga_rect_start_y		dw		0x0
		vga_rect_end_x			dw		0x0
		vga_rect_end_y			dw		0x0
		print_char_options		dw		0x0			;bit0=1=single frame only

		; mouse_pos_h			dw		0x0					; horizontal position (pixel #) of mouse pointer
		; mouse_pos_v			dw		0x0					; vertical position (pixel #) of mouse pointer 
		
		; line drawing temps
		temp_w					dw		0x0
		pointX					dw		0x0 
		pointY					dw		0x0

		marker times 16		db		0xbb				; just for visibility in the rom
	varend:

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
		call	vga_init
		
		call	loading
		call	lcd_init						; initialize the two-line 1602 LCD
		mov		bx,	msg_loading
		call	print_message_lcd				; print message pointed to by bx to LCD
		call	keyboard_init					; initialize keyboard (e.g., buffer)
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
		call	play_sound
		;call	vga_draw_test_pattern

		call	draw_shapes

		call	play_sound
		sti										; enable interrupts

		mov		word [vga_param_color],		0b00000111_11111111		; change font color (vga_init/escape resets to white)

		; fall into main_loop below

main_loop:
		cli		; disable interrupts
		mov		ax,		[kb_rptr]
		cmp		ax,		[kb_wptr]
		sti		; enable interrupts
		jne		key_pressed

		mov		ax,	[clear_screen_flag]
		cmp		ax, 0b00000000_00000011			; request to clear and screen has changes to actually clear
		je		clear
		jmp		main_loop

draw_shapes:
	pusha

	;call	vga_init
	mov		dx, 100
	mov		di, 200
	mov		bx, 10
	mov		ax,	0xffff
	call	vga_draw_circle
		
	mov		dx, 100
	mov		di, 200
	mov		bx, 9
	mov		ax,	0x00ff
	call	vga_draw_circle

	mov		dx, 100
	mov		di, 200
	mov		bx, 8
	mov		ax,	0xff00
	call	vga_draw_circle

	mov		dx, 100
	mov		di, 200
	mov		bx, 7
	mov		ax,	0xffff
	call	vga_draw_circle

	push	500					; rectangle start x
	push	100					; rectangle start y
	push	550					; rectangle end x
	push	250					; rectangle end y
	push	0x0ff0				; pixel color
	call	vga_draw_rect_filled

	push	400					; rectangle start x
	push	300					; rectangle start y
	push	500					; rectangle end x
	push	300					; rectangle end y
	push	0x00ff				; pixel color
	call	vga_draw_rect_filled

	;push	500					; rectangle start x
	;push	400					; rectangle start y
	;push	600					; rectangle end x
	;push	450					; rectangle end y
	;push	0xf0f0				; pixel color
	;call	vga_draw_rect
	DrawRectangle 500,400,600,450,0xf0f0

	mov		dx, 200
	mov		di, 300
	mov		bx, 20
	mov		ax,	0xf0f0
	call	vga_draw_circle_filled

	push	0x33					; rectangle start x
	push	0x44					; rectangle start y
	call	testParams;

	call	vga_swap_frame
	popa
	ret

vga_temp:
	push	ax
	push	cx
	push	bp
	push	si

	mov		cx,	0x0					; segment #
	mov		bp, 0xfffe				; offset within segment  (i.e., 0xfffe down to 0x0000)
	mov		si, 0xa000				; segment start (i.e., 0xa000 as top)
	mov		es, si

	.offset:		; fill frame 0 with black

		mov		word es:[bp],	0x0000			; write a test value to the location

		sub		bp,				2				; drop down a word
		cmp		bp,				0xfffe			; if equal, it wrapped around - done with this segment
		jnz		.offset

		sub		si,	0x1000						; process segment 0xa0000
		mov		es, si

		cmp		si,	0x9000						; if equal, done with all segment
		jnz		.offset

		inc		cx
		mov		si, 0xa000				; segment start (i.e., 0xa000 as top)
		mov		es, si
		
		in		ax,	VGA_REG
		and		ax, 0b1111_1111_1111_0000
		or		ax, cx
		out		VGA_REG,		ax
		cmp		cx, 0x08
		jne		.offset


		mov		ax,				0b1000_0000_0001_0000		; flip frames		
		out		VGA_REG,		ax

		.wait1:
			in		ax,	VGA_REG
			test	ax, 0b1000_0000_0000_0000		; Looking for bit15 to be 0. A 1 indicates frame switch is pending (tied to VSYNC).
			jnz		.wait1							; wait

		mov		cx,	0x0					; segment #
		mov		bp, 0xfffe				; offset within segment - (i.e., 0xfffe down to 0x0000)
		mov		si, 0xa000				; segment start (i.e., 0xa000 as top)
		mov		es, si

	.offset2:		; fill frame 1 with white

		mov		word es:[bp],	0xffff			; write a test value to the location

		sub		bp,				2				; drop down a word
		cmp		bp,				0xfffe			; if equal, it wrapped around - done with this segment
		jnz		.offset2

		sub		si,	0x1000						; process segment 0xa0000
		mov		es, si

		cmp		si,	0x9000						; if equal, done with all segment
		jnz		.offset2

		inc		cx
		mov		si, 0xa000				; segment start (i.e., 0xa000 as top)
		mov		es, si
		
		in		ax,	VGA_REG
		and		ax, 0b1111_1111_1111_0000
		or		ax, cx
		out		VGA_REG,		ax
		cmp		cx, 0x08
		jne		.offset2

	.out:

		mov		ax,				0b1000_0000_0000_0000		; flip frames		
		out		VGA_REG,		ax

		.wait2:
			in		ax,	VGA_REG
			test	ax, 0b1000_0000_0000_0000		; Looking for bit15 to be 0. A 1 indicates frame switch is pending (tied to VSYNC).
			jnz		.wait2							; wait


		call	es_point_to_rom

		pop		si
		pop		bp
		pop		cx
		pop		ax


		ret

testParams:
	;				*old base pointer				= bp
	;				*return address					= bp+2
	;				[in]		p2					= bp+4
	;				[in]		p1					= bp+6
	
	%push		ctx
	%stacksize	large
	%arg		p2:word, p1:word

	push	bp									; save base pointer
	mov		bp,		sp	

	call	lcd_clear
	mov		ax,		[bp+6]	
	call	print_char_hex
	mov		ax,		[p1]	
	call	print_char_hex

	call	lcd_line2

	mov		ax,		[bp+4]
	call	print_char_hex
	mov		ax,		[p2]
	call	print_char_hex

	pop		bp		;or use 'leave'
	ret		4
	%pop

vga_draw_line_2ddy:
	; description:	draws a line, when delta y is greater than delta x
	; params:		(5 params on stack - push params on stack in reverse order of listing below)
	;				*old base pointer				= bp
	;				*return address					= bp+2
	;				[in]		color				= bp+4
	;				[in]		end y				= bp+6
	;				[in]		end x				= bp+8
	;				[in]		start y				= bp+10
	;				[in]		start x				= bp+12
	;				[return]	none
	; comments:		see https://rosettacode.org/wiki/Bitmap/Bresenham%27s_line_algorithm#Assembly

		pusha

		mov		dx,			1
		mov		ax,			[bp+12]
		cmp		ax,			[bp+8]
		jbe		.l1
		neg		dx							; turn delta to -1

		.l1:
			mov		ax,			[bp+6]
			shr		ax,			1			; div by 2
			mov		[temp_w],	ax
			mov		ax,			[bp+12]
			mov		[pointX],	ax
			mov		ax,			[bp+10]
			mov		[pointY],	ax
			mov		bx,			[bp+6]
			sub		bx,			[bp+10]
			abs		bx							; abosolute macro
			mov		cx,			[bp+8]
			sub		cx,			[bp+12]
			abs		cx							; abosolute macro
			mov		ax,			[bp+6]

		popa
	ret

vga_draw_circle:
	; description:	draws an unfilled circle at position x,y with given radius and color
	; params:		[in]	dx = x coordinate of circle center
	;				[in]	di = y coordinate of circle center
	;				[in]	bx = radius
	;				[in]	ax = color
	;				[out]	none
	; notes:		adapted from http://computer-programming-forum.com/45-asm/67a67818aff8a94a.htm

	; TO DO save / return state properly!

	push	es		; to restore es as end of routine

	push	0xa000	; set es to video memory
    pop		es

	mov		bp,		0			; x coordinate
    mov     si,		bx			; y coordinate

	.c00:        
		call	.8pixels            ; Set 8 pixels
		sub     bx,			bp		; D=D-X
		inc     bp                  ; X+1
		sub     bx,			bp      ; D=D-(2x+1)
		jg      .c01                ; >> no step for Y
		add     bx,			si      ; D=D+Y
		dec     si                  ; Y-1
		add     bx,			si      ; D=D+(2Y-1)
	.c01:        
		cmp     si,			bp      ; Check X>Y
		jae     .c00                ; >> Need more pixels
		jmp		.out
	.8pixels:   
		call      .4pixels          ; 4 pixels
	.4pixels:   
		xchg      bp,		si      ; Swap x and y //   bp as x to bp as y  -and- si as y to si as x
		call      .2pixels          ; 2 pixels
	.2pixels:   
		neg		si
		push    di
		push	bp
		add		di,			si
		add		bp,			dx

		push	bp					; pixel x
		push	di					; pixel y
		push	ax					; pixel color
		call	vga_draw_pixel		; pixels for right side of circle

		pop		bp
		push	dx
		sub     dx,			bp

		push	dx					; pixel x
		push	di					; pixel y
		push	ax					; pixel color
		call	vga_draw_pixel		; pixels for left side of circle
		
		pop		dx
		pop     di
		ret
	
	.out:
		pop		es					; switch es back to whatever it was prior to pointing to video memory
		ret

vga_draw_circle_filled:
	; description:	draws an unfilled circle at position x,y with given radius and color
	; params:		[in]	dx = x coordinate of circle center
	;				[in]	di = y coordinate of circle center
	;				[in]	bx = radius
	;				[in]	ax = color
	;				[out]	none
	; notes:		adapted from http://computer-programming-forum.com/45-asm/67a67818aff8a94a.htm

	; TO DO save / return state properly!

	push	es		; to restore es as end of routine
	
	push	0xa000	; set es to video memory
    pop		es

	mov		bp,		0			; x coordinate
    mov     si,		bx			; y coordinate

	.c00:        
		call	.8pixels            ; Set 8 pixels
		sub     bx,			bp		; D=D-X
		inc     bp                  ; X+1
		sub     bx,			bp      ; D=D-(2x+1)
		jg      .c01                ; >> no step for Y
		add     bx,			si      ; D=D+Y
		dec     si                  ; Y-1
		add     bx,			si      ; D=D+(2Y-1)
	.c01:        
		cmp     si,			bp      ; Check X>Y
		jae     .c00                ; >> Need more pixels
		jmp		.out
	.8pixels:   
		call      .4pixels          ; 4 pixels
	.4pixels:   
		xchg      bp,		si      ; Swap x and y //   bp as x to bp as y  -and- si as y to si as x
		call      .2pixels          ; 2 pixels
	.2pixels:   
		neg		si
		push    di
		push	bp
		add		di,			si
		add		bp,			dx

		;push	bp					; pixel x
		mov		cx,			bp		; rectangle end x
		;push	di					; pixel y
		;push	ax					; pixel color
		;call	vga_draw_pixel		; pixels for right side of circle

		pop		bp
		push	dx
		sub     dx,			bp

		;push	dx					; pixel x
		;push	di					; pixel y
		;push	ax					; pixel color
		;call	vga_draw_pixel		; pixels for left side of circle
		
		push	dx					; rectangle start x
		push	di					; rectangle start y & end y
		push	cx					; rectangle end x
		push	di					; rectangle start y & end y
		push	ax					; pixel color
		call	vga_draw_rect_filled
		
		
		pop		dx
		pop     di
		ret
	
	.out:
		pop		es					; switch es back to whatever it was prior to pointing to video memory
		ret

vga_draw_rect:
	; description:	draws a filled rectangle - *currently start vals must be lower than end vals
	; params:		(5 params on stack - push params on stack in reverse order of listing below)
	;				*old base pointer				= bp
	;				*return address					= bp+2
	;				[in]		start_x 			= bp+4
	;				[in]		start_y 			= bp+6
	;				[in]		end_x				= bp+8
	;				[in]		end_y 				= bp+10
	;				[in]		color x				= bp+12
	;				[return]	none
	;
	; TO DO bounds checks

	
	%push		mycontext        ; save the current context 
	%stacksize	large            ; tell NASM to use bp
    %arg		start_x:word, start_y:word, end_x:word, end_y:word, color:word
	
	push	bp									; save base pointer
	mov		bp,				sp					; update base pointer to current stack pointer

	push	ax
	push	bx
	push	cx
	push	dx

	mov		cx,	[end_x]
	inc		word [end_x]	;[vga_rect_end_x]		; param - number is inclusive of rect - add 1 to support loop code strucure below
	mov		dx, [end_y]
	inc		word [end_y] ;[vga_rect_end_y]		; param - number is inclusive of rect - add 1 to support loop code strucure below

	mov		bx,					[start_y]
	mov		ax,					[start_x]
	.row:
		; if x = first or last column, or y = first or last row, then draw pixel
		cmp		ax,	[start_x]
		je		.draw_pixel
		cmp		ax, cx
		je		.draw_pixel
		cmp		bx, [start_y]
		je		.draw_pixel
		cmp		bx, dx
		je		.draw_pixel

		jmp		.skip_pixel			; not first or last colomn or row, so skip this pixel

		.draw_pixel:
		push	ax					; push x position to stack (param for vga_draw_pixel)
		push	bx					; push y position to stack (param for vga_draw_pixel)
		push	word [color]				; push color to stack (param for vga_draw_pixel)
		call	vga_draw_pixel
		
		.skip_pixel:
		inc		ax										; move right a pixel
		cmp		ax,					[end_x]				; compare current x to end of row of rectangle
		jne		.row
	mov		ax,					[start_x]					; start over on x position
	inc		bx											; move down a pixel
	cmp		bx,					[end_y]					; compare current y to end of column of rectangle
	jne		.row

	pop		dx
	pop		cx
	pop		bx
	pop		ax
	
	pop		bp		;or 'leave'
	
	ret		10					; return, pop 10 bytes for 5 params off stack
	%pop

vga_draw_rect_filled:
	; description:	draws a filled rectangle - *currently start vals must be lower than end vals
	; params:		(5 params on stack - push params on stack in reverse order of listing below)
	;				*old base pointer				= bp
	;				*return address					= bp+2
	;				[in]		color				= bp+4
	;				[in]		end y				= bp+6
	;				[in]		end x				= bp+8
	;				[in]		start y				= bp+10
	;				[in]		start x				= bp+12
	;				[return]	none
	;
	; TO DO bounds checks

	push	bp									; save base pointer
	mov		bp,				sp					; update base pointer to current stack pointer

	push	ax
	push	bx
	
	inc		word [bp+8]	;[vga_rect_end_x]		; param - number is inclusive of rect - add 1 to support loop code strucure below
	inc		word [bp+6] ;[vga_rect_end_y]		; param - number is inclusive of rect - add 1 to support loop code strucure below

	mov		bx,					[bp+10]
	mov		ax,					[bp+12]
	.row:
		push	ax					; push x position to stack (param for vga_draw_pixel)
		push	bx					; push y position to stack (param for vga_draw_pixel)
		push	word [bp+4]				; push color to stack (param for vga_draw_pixel)
		call	vga_draw_pixel
		inc		ax										; move right a pixel
		cmp		ax,					[bp+8]				; compare current x to end of row of rectangle
		jne		.row
	mov		ax,					[bp+12]					; start over on x position
	inc		bx											; move down a pixel
	cmp		bx,					[bp+6]					; compare current y to end of column of rectangle
	jne		.row

	pop		bx
	pop		ax

	pop		bp
	ret		10					; return, pop 10 bytes for 5 params off stack

vga_set_segment_from_xy:
	; description:	updates VGA register to set active segment based on y position
	; params:		[in]		dx		= y position
	;				[return]	none

	push	ax
	push	dx

	and		dx,			0b0000_0001_1110_0000		; these bits correspond to the VRAM segment (0-15)
	shr		dx,			5
	in		ax,			VGA_REG						; read the VGA register
	and		ax,			0b11111111_11110000			; read the register, keep all bits except segment
	or		ax,			dx							; update segment bits
	out		VGA_REG,	ax							; update VGA register
	
	pop		dx
	pop		ax
	ret

vga_get_pixel_mem_addr:
	; description:	gets the memory address of a pixel (within a 64K VRAM segment), given its x and y
	;				does not update the VGA register for active segment (use vga_set_segment_from_xy)
	; params:		[in]		dx		= pixel y position
	;				[in]		bx		= pixel x position
	;				[return]	bx		= memory address

	push	ax
	push	dx
	
	and		dx,			0b00000000_00011111
	shl		dx,			11							; the lower 5 y bits correspond with the line number within VRAM segment
	shl		bx,			1							; each x position = 2 bytes, so double bx
	or		bx,			dx							; yyyyyxxx_xxxxxxxx = address within VRAM 64K segment
	
	pop		dx
	pop		ax
	ret

vga_init:
	; Video RAM  (64 KB window) = 0xA0000-0xAFFFF

	push	ax
	push	bx
	push	cx
	push	bp
	push	si

	mov		cx,	0x0					; segment #
	mov		bp, 0xfffe				; offset within segment  (i.e., 0xfffe down to 0x0000)
	mov		si, 0xa000				; segment start (i.e., 0xa000 as top)
	mov		es, si
	mov		bx, 0b00000000_00000001					; color shift

	mov		ax, 0b0000_0000_0000_0000		; reset register
	out		VGA_REG,		ax

	.offset:		; fill frame 0 with black
		mov		word es:[bp],	0x0000			; write a test value to the location
		;mov		word es:[bp],	bx					; write a test value to the location

		sub		bp,				2				; drop down a word
		cmp		bp,				0xfffe			; if equal, it wrapped around - done with this segment
		jnz		.offset

		sub		si,	0x1000						; process segment 0xa0000
		mov		es, si

		cmp		si,	0x9000						; if equal, done with all segment
		jnz		.offset

		rol		bx, 1

		inc		cx
		mov		si, 0xa000				; segment start (i.e., 0xa000 as top)
		mov		es, si
		
		in		ax,	VGA_REG
		and		ax, 0b1111_1111_1111_0000
		or		ax, cx
		out		VGA_REG,		ax
		cmp		cx, 16			; fill all 16 segments
		jne		.offset

		mov		ax,				0b1000_0000_0001_0000		; flip frames		
		out		VGA_REG,		ax

		.wait1:
			in		ax,	VGA_REG
			test	ax, 0b1000_0000_0000_0000		; Looking for bit15 to be 0. A 1 indicates frame switch is pending (tied to VSYNC).
			jnz		.wait1							; wait

		mov		cx,	0x0					; segment #
		mov		bp, 0xfffe				; offset within segment - (i.e., 0xfffe down to 0x0000)
		mov		si, 0xa000				; segment start (i.e., 0xa000 as top)
		mov		es, si

	.offset2:		; fill frame 1 with black
		mov		word es:[bp],	0x0000			; write a test value to the location
		;mov		word es:[bp],	bx			; write a test value to the location

		sub		bp,				2				; drop down a word
		cmp		bp,				0xfffe			; if equal, it wrapped around - done with this segment
		jnz		.offset2

		sub		si,	0x1000						; process segment 0xa0000
		mov		es, si

		cmp		si,	0x9000						; if equal, done with all segment
		jnz		.offset2

		rol		bx, 1

		inc		cx
		mov		si, 0xa000				; segment start (i.e., 0xa000 as top)
		mov		es, si
		
		in		ax,	VGA_REG
		and		ax, 0b1111_1111_1111_0000
		or		ax, cx
		out		VGA_REG,		ax
		cmp		cx, 16			; fill all 16 segments
		jne		.offset2

		; ** no need to swap it at this point
		mov		ax,				0b1000_0000_0000_0000		; flip frames, resetting all register bits to defaults		
		out		VGA_REG,		ax
		.wait2:
			in		ax,	VGA_REG
			test	ax, 0b1000_0000_0000_0000		; Looking for bit15 to be 0. A 1 indicates frame switch is pending (tied to VSYNC).
			jnz		.wait2							; wait

	.out:

		mov		word [cursor_pos_h],	0x0
		mov		word [cursor_pos_v],	0x0
		mov		word [pixel_offset_h],	0x0
		mov		word [pixel_offset_v],	0x0
		mov		word [vga_param_color],	0xffff
		mov		word [clear_screen_flag],	0x0
		call	es_point_to_rom

		pop		si
		pop		bp
		pop		cx
		pop		bx
		pop		ax

		ret

vga_swap_frame:
	; swaps frames on VGA card

	push	ax
	in		ax,			VGA_REG
	xor		ax,			0b0000_0000_0001_0000	; bit4 = 286 active frame (VGA out active frame is opposite automatically)
	out		VGA_REG,	ax

	; TO DO implement interrupt support on VGA card as alternative to the following status polling
	.wait:
		in		ax,	VGA_REG
		test	ax, 0b1000_0000_0000_0000		; Looking for bit15 to be 0. Value 1 = frame switch is pending (tied to VSYNC).
		jnz		.wait							; wait
		
	pop		ax
	ret

gfx_draw_sprite:
	pusha
	push	ds
	push	es
	;		DS:SI -> source data
	;		ES:DI -> target buffer
	;		CX     = Number of words to copy

	; destination - start at 0xa00000
	mov		si, 0xa000
	mov		es, si
	mov		di, 0x0
	mov		dx, 0x0

	; source	  - start at 0xf0000 + offset for sprint_ship
	mov		si, 0xf000
	mov		ds, si
	mov		si, sprite_ship

	mov		cx, 40	; sprite is 40 pixels wide (8 black pixels on left edge), but each pixel is 2 bytes --> copy 40 words
	
	.loop:
		call	memcpy_w			; copy the row of the sprite (one word / pixel at a time)
		add		si,	80				; move over 80 pixels in sprite source data
		add		di, 2048			; move to next row on VGA
		inc		dx
		cmp		dx, 32				; if=32, done with this sprite instance
		jne		.loop

		call vga_swap_frame			; show the sprite

		add		di, bx				; shift sprite over bx/2 pixels

		mov		si, 0xf000			; reset source to beginning of sprite
		mov		ds, si
		mov		si, sprite_ship

		mov		dx, 0x0				; reset sprite row counter

		mov		ax, di
		cmp		ax, 1320
		jne		.loop

	.out:
		;popa does not include DS or ES
		pop		es
		pop		ds
		popa
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

vga_draw_test_pattern:
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	
	mov		di,	2

	mov		word [print_char_options], 0b00000000_00000001		; no frame swap

	.frame:
		.msgs:
			mov		word [cursor_pos_h],		200
			mov		word [cursor_pos_v],		20
			mov		bx,							msg_vga_test_header
			call	print_message_vga

			mov		word [cursor_pos_h],		250
			mov		word [cursor_pos_v],		75
			mov		bx,							msg_vga_test_red
			call	print_message_vga
	
			mov		word [cursor_pos_h],		250
			mov		word [cursor_pos_v],		115
			mov		bx,							msg_vga_test_green
			call	print_message_vga

			mov		word [cursor_pos_h],		250
			mov		word [cursor_pos_v],		155
			mov		bx,							msg_vga_test_blue
			call	print_message_vga

			mov		word [cursor_pos_h],		180
			mov		word [cursor_pos_v],		440
			mov		bx,							msg_vga_test_footer
			call	print_message_vga

		; dx => vga_rect_start_x
		; cx => vga_rect_start_y
		; si => color

		.red:
			mov		si,		0
			mov		dx,		50		; x
			mov		cx,		50		; y
			.redloop:
				push	dx				; start x
				push	cx				; start y
				
				mov		ax,		dx
				add		ax,		15
				push	ax				; end x

				mov		ax,		cx
				add		ax,		21
				push	ax				; end y

				mov		ax,		si
				shl		ax,		11		; shift bits left 11 bits to be in red portion of RGB
				push	ax				; color

				call	vga_draw_rect_filled

				add		dx,		16		; start x => move right 16 pixels
				inc		si				; next shade of color
				cmp		si,		32		; stop after 32 shades (5-bit color)
				jne		.redloop

		.green:
			mov		si,		0
			mov		dx,		50		; x
			mov		cx,		90		; y
			.greenloop:
				push	dx				; start x
				push	cx				; start y
				
				mov		ax,		dx
				add		ax,		7
				push	ax				; end x

				mov		ax,		cx
				add		ax,		21
				push	ax				; end y

				mov		ax,		si
				shl		ax,		5		; shift bits left 5 bits to be in green portion of RGB
				push	ax				; color

				call	vga_draw_rect_filled

				add		dx,		8		; start x => move right 16 pixels
				inc		si				; next shade of color
				cmp		si,		64		; stop after 64 shades (6-bit color)
				jne		.greenloop

		.blue:
			mov		si,		0
			mov		dx,		50		; x
			mov		cx,		130		; y
			.blueloop:
				push	dx				; start x
				push	cx				; start y
				
				mov		ax,		dx
				add		ax,		15
				push	ax				; end x

				mov		ax,		cx
				add		ax,		21
				push	ax				; end y

				mov		ax,		si
				push	ax				; color

				call	vga_draw_rect_filled

				add		dx,		16		; start x => move right 16 pixels
				inc		si				; next shade of color
				cmp		si,		32		; stop after 32 shades (5-bit color)
				jne		.blueloop				

		.full:
			; dx => x
			; cx => y
			; bx => color

			push	di
			mov		si,		0						; column counter
			mov		di,		0						; row counter
			mov		cx,		180
			mov		dx, 	64
			mov		bx,		0b00000_000000_00000

			.full_loop_columns:
				mov			ax,		di
				shl			ax,		9
				or			ax,		si
				mov			bx,		ax
				
				push		dx
				push		cx
				push		bx
				call		vga_draw_pixel	
				
				inc			si
				inc			dx
				cmp			si,		512
				jne			.full_loop_columns

			.full_loop_rows:
				mov			si,		0
				mov			dx,		64
				inc			cx
				inc			di						
				cmp			di,		128
				jne			.full_loop_columns

			pop		di

		call	vga_swap_frame
		dec		di
		jne		.frame

	.ship_loop:
		in		ax,				VGA_REG
		and		ax,				0b1111_1111_1111_0000	
		or		ax,				0b0000_0000_0000_1011		; set target segment in VRAM, 32 lines per segment
		out		VGA_REG,		ax


		mov		word bx, 6									; move 3 pixels (6 bytes) at a time
		call	gfx_draw_sprite
			
		mov		word bx, 8									; move 4 pixels (8 bytes) at a time
		call	gfx_draw_sprite

	.out:
		mov		ax,			0x0										; reset VGA register to defaults
		out		VGA_REG,	ax
		mov		word [print_char_options], 0b00000000_00000000		; restore default of frame swap
		call	vga_swap_frame
		pop		di
		pop		si
		pop		dx
		pop		cx
		pop		bx
		pop		ax
		ret

print_char_vga:
	pusha
	; to do
	;	-register save/restore
	;	-...


	; al has ascii value of char to print

	and		ax,								0x00ff							; only care about lower byte (this line should not be needed... safety for now)

	mov		word [charPixelRowLoopCounter],	0x00							; init to zero
	mov		word [pixel_offset_v],			0x0000							; init to zero
	mov		word [pixel_offset_h],			0x0000							; init to zero

	mov		[current_char],					al								; store current char ascii value
	sub		al,								0x20							; translate from ascii value to address in ROM   ;example: 'a' 0x61 minus 0x20 = 0x41 for location in charmap
	
	mov		bx,								0x0008							; multiply by 8 (8 bits per byte)
	mul		bx								

	; add		ax,								[charPixelRowLoopCounter]				; for each loop through rows of pixel, increase this by one, so that following logic fetches the correct char pixel row 
	
	; ax should now be a relative address within charmap to the char to be printed
	
	mov		bx,								ax
	mov		al,								es:[charmap+bx]					; remember row 1 of pixels for char
	mov		[charpix_line1],				ax	
	mov		al,								es:[charmap+bx+1]				; remember row 2
	mov		[charpix_line2],				ax							
	mov		al,								es:[charmap+bx+2]				; remember row 3
	mov		[charpix_line3],				ax						
	mov		al,								es:[charmap+bx+3]				; remember row 4
	mov		[charpix_line4],				ax							
	mov		al,								es:[charmap+bx+4]				; remember row 5
	mov		[charpix_line5],				ax							
	mov		al,								es:[charmap+bx+5]				; remember row 6
	mov		[charpix_line6],				ax							
	mov		al,								es:[charmap+bx+6]				; remember row 7
	mov		[charpix_line7],				ax							
	

	.rows:
		mov		si,									[charPixelRowLoopCounter]	; to track current row in char - init to zero
		mov		di,									0x0000						; to track current col in char -  init to zero
		mov		word [pixel_offset_h],				0x0003
		.charpix_col1:
			mov		al,								[charpix_line1+si]
			test	al,								PIXEL_COL1
			je		.charpix_col2											; pixel not set, go to the next column
			call	draw_pixel
		
		.charpix_col2:
			inc		word [pixel_offset_h]
			mov		al,								[charpix_line1+si]
			test	al,								PIXEL_COL2
			je		.charpix_col3											; pixel not set, go to the next column
			call	draw_pixel
		
		.charpix_col3:
			inc		word [pixel_offset_h]
			mov		al,								[charpix_line1+si]
			test	al,								PIXEL_COL3
			je		.charpix_col4											; pixel not set, go to the next column
			call	draw_pixel
		
		.charpix_col4:
			inc		word [pixel_offset_h]
			mov		al,								[charpix_line1+si]
			test	al,								PIXEL_COL4
			je		.charpix_col5											; pixel not set, go to the next column
			call	draw_pixel
		
		.charpix_col5:
			inc		word [pixel_offset_h]
			mov		al,								[charpix_line1+si]
			test	al,								PIXEL_COL5
			je		.charpix_rowdone										; pixel not set, go to the next column
			call	draw_pixel
		
		.charpix_rowdone:
			;add		word [pixel_offset_v],			2048					; next row = +2048 memory locations (i.e., pixels)
			inc		word [pixel_offset_v]
			inc		word [charPixelRowLoopCounter]
			cmp		word [charPixelRowLoopCounter],	0x08
			jne		.rows


	; add		word [cursor_pos_h], 6

	mov		ax,		[print_char_options]
	test	ax,		0b00000000_00000001
	jne		.out

	call	vga_swap_frame			; make updates visible on VGA output
	;jmp		.out

	; repeat for other frame (need to factor / optimize at some point)
	
	mov		word [charPixelRowLoopCounter],	0x00							; init to zero
	mov		word [pixel_offset_v],			0x0000							; init to zero
	mov		word [pixel_offset_h],			0x0003							; init to zero

	.rows2:
		mov		si,								[charPixelRowLoopCounter]	; to track current row in char - init to zero
		mov		di,								0x0000						; to track current col in char -  init to zero
		mov		word [pixel_offset_h],				0x0003
		.charpix_col1b:
			mov		al,								[charpix_line1+si]
			test	al,								PIXEL_COL1
			je		.charpix_col2b											; pixel not set, go to the next column
			call	draw_pixel
		
		.charpix_col2b:
			inc		word [pixel_offset_h]
			mov		al,								[charpix_line1+si]
			test	al,								PIXEL_COL2
			je		.charpix_col3b											; pixel not set, go to the next column
			call	draw_pixel
		
		.charpix_col3b:
			inc		word [pixel_offset_h]
			mov		al,								[charpix_line1+si]
			test	al,								PIXEL_COL3
			je		.charpix_col4b											; pixel not set, go to the next column
			call	draw_pixel
		
		.charpix_col4b:
			inc		word [pixel_offset_h]
			mov		al,								[charpix_line1+si]
			test	al,								PIXEL_COL4
			je		.charpix_col5b											; pixel not set, go to the next column
			call	draw_pixel
		
		.charpix_col5b:
			inc		word [pixel_offset_h]
			mov		al,								[charpix_line1+si]
			test	al,								PIXEL_COL5
			je		.charpix_rowdone2										; pixel not set, go to the next column
			call	draw_pixel
		
		.charpix_rowdone2:
			;add		word [pixel_offset_v],			2048					; next row = +2048 memory locations (i.e., pixels)
			inc		word [pixel_offset_v]
			inc		word [charPixelRowLoopCounter]
			cmp		word [charPixelRowLoopCounter],	0x08
			jne		.rows2



	; * don't need to swap right now - change is already visible on the current frame
	; call	vga_swap_frame			; make updates visible on VGA output


	.out:
	add		word [cursor_pos_h], 6
	;call	es_point_to_rom
	popa
	ret

vga_draw_pixel:
	; description:	draws a pixel at x,y pixel position with specified 2-byte color
	; params:		(3 params on stack - push params on stack in reverse order of listing below)
	;				*old base pointer				= bp
	;				*return address					= bp+2
	;				[in]		color				= bp+4
	;				[in]		y position			= bp+6
	;				[in]		x position			= bp+8
	;				[return]	none

	push	bp									; save base pointer
	mov		bp,				sp					; update base pointer to current stack pointer
	
	push	ax
	push	bx
	push	dx
	push	si
	push	es


	mov		dx,				[bp+6]				; pass y position in dx
	call	vga_set_segment_from_xy				; update VGA segment based on y position
	mov		bx,				[bp+8]				; pass x position in bx (y already be in dx)
	call	vga_get_pixel_mem_addr				; get address within selected 64K VRAM segment, returned in bx

	mov		si,				0xa000
	mov		es,				si
	mov		ax,				[bp+4]				; fill pixel with color

	mov		word es:[bx],	ax				; fill pixel with color
	
	pop		es
	pop		si
	pop		dx
	pop		bx
	pop		ax
	pop		bp
	ret		6									; return, pop 6 bytes for 3 params off stack

draw_pixel:
	; description:	draws a pixel at x,y with specified color. used by vga_print_char.
	;				this is an older version that can probably be consolidated with vga_draw_pixel
	; params:		[in]		memory address [cursor_pos_h]
	;				[in]		memory address [cursor_pos_v]
	;				[in]		memory address [pixel_offset_h]
	;				[in]		memory address [pixel_offset_v]
	;				[in]		memory address [vga_param_color]
	;				[return]	none
	;				* using memory addresses for easy & execution speed (vs. stack)

	push	es
	push	si
	push	ax
	push	bx
	push	dx
	
	mov		si, 0xa000				; segment start (i.e., 0xa000 as beginning of VRAM window)
	mov		es, si

	mov		bx,				[cursor_pos_h]
	add		bx,				[pixel_offset_h]	; pass x position in bx

	mov		dx,				[cursor_pos_v]
	add		dx,				[pixel_offset_v]	; pass y position in dx

	call	vga_set_segment_from_xy				; register updated in called routine, pass y position in dx
	call	vga_get_pixel_mem_addr				; address within selected 64K VRAM segment, returned in bx

	mov		ax,				[vga_param_color]
	mov		es:[bx],		ax

	pop		dx
	pop		bx
	pop		ax
	pop		si
	pop		es
	ret

keyboard_init:
	mov	word	[kb_flags],		0
	mov word	[kb_wptr],		0
	mov word	[kb_rptr],		0
	ret

oled_init:
	mov		ax,	CMD_OLED_RESET						; cmd06 = OLED init / reset, no param
	call	spi_send_NanoSerialCmd
	call	delay
	ret

post_tests:
	call	post_RAM
	;call	post_VideoRegister
	;call	post_VRAM
	;call	post_PPIs
	call	post_VIA
	call	post_MathCo
	call	post_PIC
	call	post_Complete

	ret

post_VideoRegister:
	push	ax

	mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_VGA_REG_TEST_BEGIN
	call	spi_send_NanoSerialCmd

	mov		ax,				0b0000_1111_1110_0000			
	out		VGA_REG,		ax
	in		ax,				VGA_REG
	and		ax,				0b0111_1111_1111_1111	; ignore first bit - it is read only from the 286
	cmp		ax,				0b0000_1111_1110_0000
	je		.pass

	.fail:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_VGA_REG_TEST_FAIL
		call	spi_send_NanoSerialCmd
		jmp		.out
	.pass:
		mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_VGA_REG_TEST_FINISH
		call	spi_send_NanoSerialCmd
		; fall into .out
	.out:
		mov		ax,				0b1000_0000_0000_0000			; set proper starter values (bit 15 is read only)
		out		VGA_REG,		ax
		pop		ax
		ret

post_VRAM:
	; VRAM		Accessed through 0xA0000-0xAFFFF segment
	;			Two frames - each at 1 MB,	with lower 0.5 MB of each used by VGA output
	;										upper 0.5 MB can be used as general memory
	;			Each frame contains 16 segments of 64 KB
	;			Active frame set via I/O register at A0
	;			Active segment also set via I/O register at A0. Register bits:
	;				5=System Frame Number
	;				4=VGA Out Frame Number (5#)
	;				3=Segment_bit3
	;				2=Segment_bit2
	;				1=Segment_bit1
	;				0=Segment_bit0

	; !! Currently testing the first 64 KB of VRAM frame 1 only !!

	push	ax
	push	bp
	push	si

	mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_VRAM_TEST_BEGIN
	call	spi_send_NanoSerialCmd


	; TO DO - Set VRAM frame & segment with register (I/O 0xA0)
		; assuming frame 0 and segment 0 for now

	mov		bp, 0xfffe				; offset within segment - will start by subtracting 0x01 (i.e., 0xffff down to 0x0000)
	mov		si, 0xa000				; segment start (i.e., 0x9000 as top)
	mov		es, si

	.offset:
		mov		ax,				es:[bp]			; backup test location
		mov		[mem_test_tmp],	ax

		mov		word es:[bp],	0xdbdb			; write a test value to the location
		mov		ax,				es:[bp]			; read the test value back
		cmp		ax,				0xdbdb			; make sure the value read matches what was written
		mov		ax,				[mem_test_tmp]	; put the original value back in the location being tested
		mov		es:[bp],		ax				; -
		jne		.fail							; if no match, fail

		sub		bp,				2				; if pass, drop down a word
		cmp		bp,				0xfffe			; if equal, it wrapped around - done with this segment
		jnz		.offset

		sub		si,	0x1000						; process segment 0xa0000
		mov		es, si

		cmp		si,	0x9000						; if equal, done with all segment
		jnz		.offset
		jmp		.pass

	.fail:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_VRAM_TEST_FAIL
		call	spi_send_NanoSerialCmd
		jmp		.out
	.pass:
		mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_VRAM_TEST_FINISH
		call	spi_send_NanoSerialCmd
	.out:
		call	es_point_to_rom

		pop		si
		pop		bp
		pop		ax
		ret

post_RAM:
	; RAM  (640 KB) = 0x00000-0x9FFFF
	push	ax
	push	bx
	push	bp
	push	si

	mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_RAM_TEST_BEGIN
	call	spi_send_NanoSerialCmd

	mov		bx,	0x0009				; counter for LED output
	mov		bp, 0xfffe				; offset within segment - will start by subtracting 0x01 (i.e., 0xffff down to 0x0000)
	mov		si, 0x9000				; segment start (i.e., 0x9000 as top)
	mov		es, si

	mov		ax,						0b00000101_00001001			; digit (0-)4 = '9'
	call	spi_send_LEDcmd

	.offset:
		mov		ax,				es:[bp]			; backup test location
		mov		[mem_test_tmp],	ax

		mov		word es:[bp],	0xdbdb			; write a test value to the location
		mov		ax,				es:[bp]			; read the test value back
		cmp		ax,				0xdbdb			; make sure the value read matches what was written
		mov		ax,				[mem_test_tmp]	; put the original value back in the location being tested
		mov		es:[bp],		ax				; -
		jne		.fail							; if no match, fail

		sub		bp,				2				; if pass, drop down a word
		cmp		bp,				0xfffe			; if equal, it wrapped around - done with this segment
		jnz		.offset

		dec		bx								; shift to the next segment
		sub		si,	0x1000						; process segments 0x9000 down to 0x0000
		mov		es, si

		mov		ax,				0x0500			; desired LED character position
		add		ax,	bx							; add value to display (in al)
		call	spi_send_LEDcmd

		;cmp		si,	0xf000						; if equal, it wrapped around- done with all segments
		cmp		si,	0x8000						; only testing one segment for now
		jnz		.offset
		jmp		.pass

	.fail:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_RAM_TEST_FAIL
		call	spi_send_NanoSerialCmd
		jmp		.out
	.pass:
		mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_RAM_TEST_FINISH
		call	spi_send_NanoSerialCmd
	.out:
		mov		ax,				0b00000101_00001010	; desired LED character position
		call	spi_send_LEDcmd
		mov		ax,				0b00000100_00001010	; desired LED character position
		call	spi_send_LEDcmd

		call	es_point_to_rom

		pop		si
		pop		bp
		pop		bx
		pop		ax
		ret

es_point_to_rom:
	push	ax
	mov		ax, 0xf000			; Read-only data in ROM at 0x30000 (0xf0000 in address space  0xc0000+0c30000). 
								; Move es to this by default to easy access to constants.
	mov		es,	ax				; extra segment
	pop		ax
	ret

post_PPIs:
	; this testing requires a PPI that supports reading the configuration
	; Intersil 82c55a - yes
	; OKI 82c55a - no
	; NEC pd8255a - no

	push	ax
	push	dx

	; *** PPI1 ***
	mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_PPI1_TEST_BEGIN
	call	spi_send_NanoSerialCmd
	
	; do not currently have a PPI that supports reading control register
	jmp		.pass1

	mov		dx,			PPI1_CTL			; Get control port address
	mov		al,			CTL_CFG_PA_IN		; 0b10010000
	call	print_char_hex					; for debugging
	out		dx,			al					; Write control register on PPI
	in		al,			dx					; Read control register on PPI
	call	print_char_hex					; for debugging
	cmp		al,			CTL_CFG_PA_IN		; Compare to latest config
	
	mov		al,			[ppi1_ccfg]			; Restore value from prior to testing

	jne		.fail1
	jmp		.pass1

	.fail1:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_PPI1_TEST_FAIL
		call	spi_send_NanoSerialCmd
		jmp		.out1
	.pass1:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_PPI1_TEST_FINISH
		call	spi_send_NanoSerialCmd
	.out1:


	; *** PPI2 ***
	mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_PPI2_TEST_BEGIN
	call	spi_send_NanoSerialCmd

	; do not currently have a PPI that supports reading control register
	jmp		.pass2

	mov		dx,			PPI2_CTL			; Get control port address
	in		al,			dx					; Read control register on PPI
	cmp		al,			[ppi2_ccfg]			; Compare to latest config
	jne		.fail2
	jmp		.pass2

	jmp		.pass2
	.fail2:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_PPI2_TEST_FAIL
		call	spi_send_NanoSerialCmd
		jmp		.out2
	.pass2:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_PPI2_TEST_FINISH
		call	spi_send_NanoSerialCmd
	.out2:
		pop		dx
		pop		ax
		ret

post_VIA:
	push	ax

	mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_VIA1_TEST_BEGIN
	call	spi_send_NanoSerialCmd

	mov		al,				0b11111111			
	out		VIA1_IER,		al					; enable all interrupts on VIA
	in		al,				VIA1_IER			
	add		al,				0x01				; should be all ones... add one, should be all zeros
	jnz		.fail								; if not all zeros, fail
	mov		al,				0b01111111			
	out		VIA1_IER,		al					; disable all interrupts on VIA
	in		al,				VIA1_IER			; bit 7 will be 1, then 1 for all bits enabled
	cmp		al,				0b10000000			; if all interrupts disabled, should be 0b10000000
	jne		.fail
	jmp		.pass

	.fail:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_VIA1_TEST_FAIL
		call	spi_send_NanoSerialCmd
		jmp		.out
	.pass:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_VIA1_TEST_FINISH
		call	spi_send_NanoSerialCmd
	.out:
		pop		ax
		ret

post_MathCo:
	push	ax
	
	mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_MATHCO_TEST_BEGIN						; cmd08 = print status, 9 = MathCo test begin
	call	spi_send_NanoSerialCmd

	; To test the math coprocessor, calculate the area of a circle
	; R = radius, stored in .rodata =  91.67 = 42b7570a (0a57b742 in ROM)
	
	;mov		ax,		ES:[R+3]				; 42
	;mov		ax,		ES:[R+2]				; b7
	;mov		ax,		ES:[R+1]				; 57
	;mov		ax,		ES:[R]					; 0a

	finit									; Initialize math coprocessor
	fld		dword ES:[R]					; Load radius
	fmul	st0,st0							; Square radius
	fldpi									; Load pi
	fmul	st0,st1							; Multiply pi by radius squared
	
	fstp	dword [AREA]					; Store calculated area
											; Should be 26400.0232375 = 46ce400c (0c40ce46 in RAM)
	
	call	delay							; Some delay required here
	call	delay							; Some delay required here

	; Compare actual result with expected result
	mov		ax,		[AREA+2]
	cmp		ax,		0x46ce
	jne		.fail

	mov		ax,		[AREA]
	cmp		ax,		0x400c
	jne		.fail

	jmp		.pass
	
	.fail:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_MATHCO_TEST_FAIL			; cmd08 = print status, 24 = MathCo test fail
		call	spi_send_NanoSerialCmd
		jmp		.out
	.pass:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_MATHCO_TEST_FINISH		; cmd08 = print status, 10 (0x0A) = MathCo test finish
		call	spi_send_NanoSerialCmd
	.out:
		pop		ax
		ret

post_PIC:
	push	dx
	push	ax

	mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_PIC_TEST_BEGIN
	call	spi_send_NanoSerialCmd

	; write/read warm-up
	mov		dx,		PICM_P1			; address for port 1 (will use ocw1)
	mov		al,		0x0				; set IMR to zero (unmask all interrupts)
	out		dx,		al		
	in		al,		dx				; read IMR
	mov		al,		0xff			; set IMR to zero (unmask all interrupts)
	out		dx,		al		
	in		al,		dx				; read IMR

	
	; *** Test procedure from IBM BIOS Technical Reference
	mov		dx,		PICM_P1			; address for port 1 (will use ocw1)
	mov		al,		0x0				; set IMR to zero (unmask all interrupts)
	out		dx,		al		
	in		al,		dx				; read IMR
	or		al,		al
	jnz		.fail					; if not zero, error
	mov		al,		0xff			
	out		dx,		al				; mask (disable) all interrupts
	in		al,		dx				; read IMR
	add		al,		0x01			; should be all ones... +1 = all zeros
	jnz		.fail					; if not all zeros, error
	jmp		.pass

	.fail:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_PIC_TEST_FAIL
		call	spi_send_NanoSerialCmd
		jmp		.out
	.pass:
		mov		ax,	CMD_PRINT_STATUS_OLED + OLED_STATUS_PIC_TEST_FINISH
		call	spi_send_NanoSerialCmd
	.out:
		; to do: restore IMR to pre-test state (currently, enabling all interrupts -- could change in the future)
		pop		ax
		pop		dx
		ret

post_Complete:
	mov		ax, CMD_PRINT_STATUS_OLED + OLED_STATUS_POST_COMPLETE
	call	spi_send_NanoSerialCmd
	ret

spi_sdcard_init:
	mov		bx,		msg_sdcard_init
	call	print_string_to_serial

	call	delay			;remove? ...test
	call	delay


	; using SPI mode 0 (cpol=0, cpha=0)
	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; SPI_CS2 high (not enabled), start with MOSI high and CLK low
	out		VIA1_PORTB,		al	
	
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

    .try00:													; GO_IDLE_STATE
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

	.try08:													; SEND_IF_COND

		mov		bx,		msg_sdcard_try08
		call	print_string_to_serial

		mov		bx,		cmd8_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

        ; Expect status response 0x01 (not initialized)
		cmp		al,		0x01
		jne		.try08

		mov		bx,		msg_sdcard_try08_done
		call	print_string_to_serial
		
		call	spi_readbyte_port_b							; read four bytes
		call	spi_readbyte_port_b
		call	spi_readbyte_port_b
		call	spi_readbyte_port_b

	.try55:													; APP_CMD
		mov		bx,		msg_sdcard_try55
		call	print_string_to_serial

		mov		bx,		cmd55_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

        ; Expect status response 0x01 (not initialized)
		cmp		al,		0x01
		jne		.try55

		mov		bx,		msg_sdcard_try55_done
		call	print_string_to_serial

	.try41:													; SD_SEND_OP_COND
		mov		bx,		msg_sdcard_try41
		call	print_string_to_serial

		mov		bx,		cmd41_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

        ; Expect status response 0x01 (not initialized)
		cmp		al,		0x00
		jne		.try55

		mov		bx,		msg_sdcard_try41_done
		call	print_string_to_serial

	.try18:													; READ_MULTIPLE_BLOCK, starting at 0x0
		mov		bx,		msg_sdcard_try18
		call	print_string_to_serial

		mov		bx,		cmd18_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand_noclose				; start reading SD card at 0x0


		; ** to do --	read bytes until 0xfe is returned
		;				this is where the actual data begins
		;call	spi_readbyte_port_b	
		;cmp		al,		0xfe							; 0xfe = have data
		;jne		.nodata									; if data avail, continue, otherwise jump to .nodata

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
	; when changing CS in SPI, a byte of (any) data should be sent just prior to and just following the CS change -- calling this a garbage byte
	; this might possibly only apply to SD Card CS  (?)
	
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
	; same as spi_sdcard_sendcommand, but leaves SPI_CS2 low (enabled)
	; used in cases such as READ_MULTIPLE_BLOCK, where CS should not be brought high until done reading blocks

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

test_8char7seg:
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

	mov		al,				0b01111111			; disable all interrupts on VIA
	out		VIA1_IER,		al

	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_CLK | SPI_MOSI)	; set bits as output -- other bits will be input
	out		VIA1_DDRB,		al
	nop
	nop
	nop
	nop
	nop
	nop
	out		VIA1_DDRA,	al
	
	; set initial values on the port
	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)	; start with all select lines high and clock low - mode 0
	mov		[spi_state_b],	al
	mov		[spi_state_a],	al
	out		VIA1_PORTB,		al		; set initial values - not CS's selected		;(this causes a low blip on port B lines)
	nop
	nop
	nop
	nop
	nop
	out		VIA1_PORTA,		al		; set initial values - not CS's selected
	
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
		out		VIA1_PORTA,		al			; raise CLK keeping MOSI the same, to send the bit
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

	;bring clock low
	mov		al,				[spi_state_a]			
	out		VIA1_PORTA,		al		

	pop		bp
	pop		bx
	pop		ax
	ret

spi_writebyte_port_a_mode_1:
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
		jmp		.clock
	.sendbit:
		mov		al,				[spi_state_a]	; instead of 0, need to keep CS properly set when using multiple SPI devices		
		and		al,				~SPI_MOSI	;0b11111101	; to do: invert SPI_MOSI instead of 0b... value
	.clock:
		; remove the following line
		or		al,				SPI_CLK		; high clock
		
		out		VIA1_PORTA,		al			; set MOSI (or not) first with SCK low
		nop
		nop
		and		al,				~SPI_CLK	; low clock
		out		VIA1_PORTA,		al			; lower CLK keeping MOSI the same, to send the bit
		nop
		nop
		
		mov		al,				bl			; restore remaining bits to send
		dec		bp
		jne		.loop						; loop if there are more bits to send


	;bring clock low
	;mov		al,				[spi_state_a]			
	;out		VIA1_PORTA,		al		

	pop		bp
	pop		bx
	pop		ax
	ret

spi_readbyte_port_b:
	push	bp
	push	bx

	mov		bp,		0x08					; send 8 bits
	.loop:
		mov		al,				[spi_state_b]		; MOSI already high and CLK low
		out		VIA1_PORTB,		al

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

	push	ax		;save read value
	; end clock high
	mov		al,				[spi_state_b]		; MOSI already high and CLK low
	out		VIA1_PORTB,		al
	pop		ax		;retrieve read value

	pop		bx
	pop		bp

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

	; bring clock low
	mov		al,				[spi_state_a]			
	out		VIA1_PORTA,		al	

	pop		bp
	pop		bx
	;pop		ax

	ret

spi_readbyte_port_a_mode_1:
	;push	ax
	push	bx
	push	bp

	mov		bp,		0x08					; send 8 bits
	.loop:
		
		mov		al,				[spi_state_a]		; MOSI already high and CLK low
		or		al,				SPI_CLK			; toggle the clock high
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
		and		al,				~SPI_CLK		; toggle the clock low
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


	; bring clock low
	push	ax
	mov		al,				[spi_state_a]			
	out		VIA1_PORTA,		al	
	pop		ax
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

spi_send_LEDcmd:
	push	bx
	push	ax

	mov		al,				(		   SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)		; drop SPI_CS1 low to enable, start with MOSI high and CLK low
	mov		[spi_state_b],		al
	out		VIA1_PORTB,		al		

	pop		ax						; get back original ax
	push	ax						; save it again to stack

	mov		al,				ah		; digit 1
	call	spi_writebyte_port_b

	pop		ax						; get back original ax
	push	ax						; save it again to stack
	call	spi_writebyte_port_b			; using original al


	mov		al,				(		SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)			; CLK low
	out		VIA1_PORTB,		al	

	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)		; bring all SPI_CSx high
	out		VIA1_PORTB,		al	


	pop		ax
	pop		bx
	ret

spi_write_RTC:
	; ah = address
	; al = data

	push	bx
	push	ax

	mov		al,				( SPI_CS1 |			SPI_CS3	| SPI_CS4 | SPI_CS5 | SPI_MOSI)			; drop SPI_CS3 low to enable, start with MOSI high and CLK low
	mov		[spi_state_a],		al
	out		VIA1_PORTA,		al		

	pop		ax								; get back original ax
	push	ax								; save it again to stack

	mov		al,				ah				; hi byte
	call	spi_writebyte_port_a_mode_1

	pop		ax								; get back original ax
	push	ax								; save it again to stack
	call	spi_writebyte_port_a_mode_1		; using original al = lo byte


	mov		al,				( SPI_CS1 |			SPI_CS3	| SPI_CS4 | SPI_CS5 | SPI_MOSI)			; CLK low
	out		VIA1_PORTA,		al	

	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)		; bring all SPI_CSx high
	out		VIA1_PORTA,		al	

	pop		ax
	pop		bx
	ret

spi_read_RTC:
	; al = address

	push	ax

	mov		al,				( SPI_CS1 |			SPI_CS3	| SPI_CS4 | SPI_CS5 | SPI_MOSI)			; drop SPI_CS3 low to enable, start with MOSI high and CLK low
	mov		[spi_state_a],		al
	out		VIA1_PORTA,			al	

	pop		ax								; get back original ax
	;push	ax								; save it again to stack
	call	spi_writebyte_port_a_mode_1		; using original al

	nop
	nop
	nop
	nop
	nop
	nop


	call	spi_readbyte_port_a_mode_1	
	push	ax
	; call	print_char_hex

	mov		al,				( SPI_CS1 |			SPI_CS3	| SPI_CS4 | SPI_CS5 | SPI_MOSI)			; CLK low
	out		VIA1_PORTA,		al	

	mov		al,				(SPI_CS1| SPI_CS2 |	SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)			; bring SPI_CS3 high to disable
	out		VIA1_PORTA,		al	

	pop		ax
	ret

kbd_isr:
	pusha

	; if releasing a key, don't read PPI, but reset RELEASE flag
	mov		ax,					[kb_flags]
	and		ax,					RELEASE
	je		read_key								; if equal, releasing flag is not set, so continue reading the PPI
	mov		ax,					[kb_flags]
	and		ax,					~RELEASE			; clear the RELEASE flag
	mov		word [kb_flags],	ax

	call	kbd_get_scancode						; read scancode from PPI2 into al (for the key being released)
	cmp		al,						0x12			; left shift
	je		shift_up
	cmp		al,						0x59			; right shift
	je		shift_up

	; fall into kbd_isr_done below


kbd_isr_done:
	mov		al,			0x20		; EOI byte for OCW2 (always 0x20)
	out		PICM_P0,	al			; to port for OCW2
	popa
	iret

read_key:
	call	kbd_get_scancode		; read scancode from PPI2 into al
	call	print_char_hex
	.release:
		cmp		al,					0xf0		; key release
		je		key_release

	.shift:
		cmp		al,					0x12		; left shift
		je		shift_down
		cmp		al,					0x59		; right shift
		je		shift_down

	.filter:									; Filter out some noise scancodes
		cmp		al,					0x01		; esc related
		je		kbd_isr_done

		cmp		al,					0x7e		; Microsoft Ergo keyboard init? - not using
		je		kbd_isr_done

		cmp		al,					0xfe		; ?		to do: identify
		je		kbd_isr_done	

		cmp		al,					0x0e		; ?		to do: identify
		je		kbd_isr_done

		cmp		al,					0xaa		; ?		to do: identify
		je		kbd_isr_done	

		cmp		al,					0xf8		; ?		to do: identify
		je		kbd_isr_done

		cmp		al,					0xe0		; key up for F1, ...
		je		kbd_isr_done


	
	.esc:
		cmp		al,			0x76		; ESC
		jne		.f1
		mov		ax,		word [clear_screen_flag]
		or		ax,		0b00000000_00000001				; toggle request to clear screen
		mov		word [clear_screen_flag],	ax
		jmp		kbd_isr_done

	.f1:
		cmp		al,			0x05		; F1
		jne		.f2
		
		call	lcd_clear
		call	rtc_getTemp						; get temperature from RTC
		call	rtc_getTime						; get time from RTC
		call	lcd_line2

		jmp		kbd_isr_done

	.f2:
		cmp		al,			0x06		; F2
		jne		.f5
		
		call	lcd_clear
		call	rtc_setTime						; get temperature from RTC
		mov		al,	's'
		call	print_char
		mov		al,	'e'
		call	print_char
		mov		al,	't'
		call	print_char
		call	lcd_line2
		call	rtc_getTime						; get time from RTC

		jmp		kbd_isr_done

	.f5:
		cmp		al,			0x03		; F12
		jne		.f12
		call	load_image_from_sdcard
		jmp		kbd_isr_done


	.f12:
		cmp		al,			0x07		; F12
		jne		.ascii
		
		call	vga_swap_frame

		call	delay

		jmp		kbd_isr_done


	; to do - check for other non-ascii
	; http://www.philipstorr.id.au/pcbook/book3/scancode.htm

	.ascii:
		call	kbd_scancode_to_ascii			; convert scancode to ascii
		push	di
		mov		di,				[kb_wptr]
		mov		[kb_buffer+di],	ax
		pop		di
		call	keyboard_inc_wptr
		mov		word [clear_screen_flag],	0b00000000_00000010		; set dirty flag and unset clear screen flag
		jmp		kbd_isr_done

load_image_from_sdcard:
	mov		bx,		msg_sdcard_init
	call	print_string_to_serial

	call	delay			;remove? ...test
	call	delay


	; using SPI mode 0 (cpol=0, cpha=0)
	mov		al,				(SPI_CS1 | SPI_CS2 | SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; SPI_CS2 high (not enabled), start with MOSI high and CLK low
	out		VIA1_PORTB,		al	
	
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

    .try00:													; GO_IDLE_STATE
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

	.try08:													; SEND_IF_COND

		mov		bx,		msg_sdcard_try08
		call	print_string_to_serial

		mov		bx,		cmd8_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

        ; Expect status response 0x01 (not initialized)
		cmp		al,		0x01
		jne		.try08

		mov		bx,		msg_sdcard_try08_done
		call	print_string_to_serial
		
		call	spi_readbyte_port_b							; read four bytes
		call	spi_readbyte_port_b
		call	spi_readbyte_port_b
		call	spi_readbyte_port_b

	.try55:													; APP_CMD
		mov		bx,		msg_sdcard_try55
		call	print_string_to_serial

		mov		bx,		cmd55_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

        ; Expect status response 0x01 (not initialized)
		cmp		al,		0x01
		jne		.try55

		mov		bx,		msg_sdcard_try55_done
		call	print_string_to_serial

	.try41:													; SD_SEND_OP_COND
		mov		bx,		msg_sdcard_try41
		call	print_string_to_serial

		mov		bx,		cmd41_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

        ; Expect status response 0x01 (not initialized)
		cmp		al,		0x00
		jne		.try55

		mov		bx,		msg_sdcard_try41_done
		call	print_string_to_serial

	.try18:													; READ_MULTIPLE_BLOCK, starting at 0x0
		mov		bx,		msg_sdcard_try18
		call	print_string_to_serial

		mov		bx,		cmd18_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand_noclose				; start reading SD card at 0x0


		; ** to do --	read bytes until 0xfe is returned
		;				this is where the actual data begins
		;call	spi_readbyte_port_b	
		;cmp		al,		0xfe							; 0xfe = have data
		;jne		.nodata									; if data avail, continue, otherwise jump to .nodata

		call	spi_sdcard_readimage	

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

spi_sdcard_readimage:
	pusha

	call	send_garbage
	mov		al,				(SPI_CS1|			SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; drop SPI_CS2 low to enable, start with MOSI high and CLK low
	mov		[spi_state_b],	al
	out		VIA1_PORTB,		al		
	call	send_garbage


	.filehdr:					
		; first real data from card is the byte after 0xfe is read... usually the first byte
		call	spi_readbyte_port_b	
		mov		ah,	0x02		; cmd02 = print hex
		call	spi_send_NanoSerialCmd
		cmp		al,	0xfe
		jne		.filehdr		; keep reading until 0xfe init value is found

		mov		ax,	0x010a		; cmd01 = print char - newline
		call	spi_send_NanoSerialCmd
		mov		ax,	0x010a		; cmd01 = print char - newline
		call	spi_send_NanoSerialCmd

	mov		bp, 0x0
	mov		cx, 0x0
	mov		dx, 0x0
	mov		si, 0xa000				; segment start (i.e., 0xa000 as top of video ram)
	mov		es, si
	mov		si, 32768

	in		ax,	VGA_REG
	and		ax, 0b1111_1111_1111_0000
	or		ax, cx
	out		VGA_REG,		ax

	.loop:
		cmp		dx,		512
		jne		.cont
			call	spi_readbyte_port_b			; read byte into al		; token & CRC every 512 bytes - read and ignore
			call	spi_readbyte_port_b			; read byte into al
			call	spi_readbyte_port_b			; read byte into al
			call	spi_readbyte_port_b			; read byte into al
			call	spi_readbyte_port_b			; read byte into al
			mov		dx, 0

		.cont:

		call	spi_readbyte_port_b			; read byte into al
		xchg	al,		ah					; put al into ah
		call	spi_readbyte_port_b			; read another byte into al
		xchg	al,		ah					; TO DO update graphic conversion util to swap order of lo/hi bytes so this line of code isn't needed

		mov		word es:[bp],	ax
		add		bp, 2
		
		;mov		ah,	0x02		; cmd02 = print hex
		;call	spi_send_NanoSerialCmd

		add		dx, 2

		dec		si
		jnz		.loop

		mov		si, 32768
		inc		cx

		in		ax,	VGA_REG
		and		ax, 0b1111_1111_1111_0000
		or		ax, cx
		out		VGA_REG,		ax
		cmp		cx, 15
		jne		.loop

		call	vga_swap_frame
		call	es_point_to_rom

	.out:
		call	send_garbage
		mov		al,				(SPI_CS1| SPI_CS2 |	SPI_CS3 | SPI_CS4 | SPI_CS5 | SPI_MOSI)					; drop SPI_CS2 low to enable, start with MOSI high and CLK low
		mov		[spi_state_b],	al
		mov		bx,		cmd12_bytes							; place address of cmd data in bx
		call	spi_sdcard_sendcommand

		mov		bx,		msg_sdcard_read_done
		call	print_string_to_serial
	popa
	ret

keyboard_inc_wptr:
	push		ax
	mov			ax,				[kb_wptr]
	cmp			ax,				500
	jne			.inc
	mov word	[kb_wptr],		0
	jmp			.out

	.inc:
		add	word [kb_wptr],	2
		; fall into .out
	.out:
		pop		ax
		ret

keyboard_inc_rptr:
	push		ax
	mov			ax,				[kb_rptr]
	cmp			ax,				500
	jne			.inc
	mov word	[kb_rptr],		0
	jmp			.out

	.inc:
		add word	[kb_rptr],	2
		; fall into .out
	.out:
		pop		ax
		ret

shift_up:
	mov		ax,					[kb_flags]
	xor		ax,					SHIFT		; clear the shift flag
	mov		word [kb_flags],	ax
	jmp		kbd_isr_done

shift_down:
  	mov		ax,					[kb_flags]
	or		ax,					SHIFT		; set the shift flag
	mov		word [kb_flags],	ax
	jmp		kbd_isr_done

key_release:
	mov		ax,					[kb_flags]
	or		ax,					RELEASE		; set release flag
	mov		word [kb_flags],	ax
	jmp		kbd_isr_done

key_pressed:
	push	ax

	mov		bx,		[kb_rptr]
	;and		bx,		0x00ff

	mov		ax,		[kb_buffer + bx]
		
	cmp		al,		0x0a		; enter
	je		enter_pressed
	;cmp		al,		0x1b		; escape
	;je		esc_pressed

	;call	print_char
	call	print_char_vga

	jmp		key_pressed_done

esc_pressed:
	;mov		word [clear_screen_flag],	0x1	
	mov		ax, [clear_screen_flag]
	or		ax, 0b00000000_00000001		; reqest to clear screen
	; call	lcd_clear
	; call	vga_init

	jmp		key_pressed_done

clear:
	;call	lcd_clear
	call	vga_init
	mov		word [clear_screen_flag],	0x0
	jmp		main_loop

enter_pressed:
	call	lcd_line2

	; mov		ah,							0x01			; spi cmd 1 - print char
	; call	spi_send_NanoSerialCmd

	;add		word	[cursor_pos_v],		16384
	add		word	[cursor_pos_v],		9
	mov		word	[cursor_pos_h],		0
	
	jmp		key_pressed_done

key_pressed_done:
	call	keyboard_inc_rptr
	pop		ax
	jmp		main_loop
	
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

print_message_old:
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

print_message_lcd:
	; Send a NUL-terminated string to the LCD display;
	; In: DS:BX -> string to print
	; Return: AX = number of characters printed
	; All other registers preserved or unaffected.
	; **thank you, Damouze!

	push	bx 					; Save BX 
	push	cx 					; and CX onto the sack
	mov		cx, bx 				; Save contents of BX for later use
	
	.loop:
		mov		al, es:[bx]		; Read byte from [DS:BX]
		or		al, al 			; Did we encounter a NUL character?
		jz		.return 		; If so, return to the caller
		call	print_char 		; call our character print routine
		inc		bx 				; Increment the index
		jmp		.loop 			; And loop back
	
	.return: 
		sub		bx, cx 			; Calculate our number of characters printed
		mov		ax, bx 			; And load the result into AX
		pop		cx 				; Restore CX
		pop		bx 				; and BX from the stack
		ret 					; Return to our caller

print_message_vga:
	; Send a NUL-terminated string to the LCD display;
	; In: DS:BX -> string to print
	; Return: AX = number of characters printed
	; All other registers preserved or unaffected.
	; **thank you, Damouze!

	push	bx 					; Save BX 
	push	cx 					; and CX onto the sack
	mov		cx, bx 				; Save contents of BX for later use
	
	.loop:
		mov		al, es:[bx]		; Read byte from [DS:BX]
		or		al, al 			; Did we encounter a NUL character?
		jz		.return 		; If so, return to the caller
		call	print_char_vga
		inc		bx 				; Increment the index
		jmp		.loop 			; And loop back
	
	.return: 
		sub		bx, cx 			; Calculate our number of characters printed
		mov		ax, bx 			; And load the result into AX
		pop		cx 				; Restore CX
		pop		bx 				; and BX from the stack
		ret 					; Return to our caller

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

	; mov		al,		'x'
	; call	print_char
	; pop		ax
	; push	ax
	
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

print_char_dec:
	; al contains the binary value that will be converted to ascii and printed to the 2-line LCD
	push	ax
	push	bx

	mov	[dec_num],				al
	mov	byte [dec_num100s],		0
	mov	byte [dec_num10s],		0
	mov	byte [dec_num1s],		0

	.hundreds_loop:
		mov	al,			[dec_num]
		cmp	al,			100				; compare to 100
		jb				.tens_loop
		mov	al,			[dec_num]
		stc								; set carry
		sbb	al,			100				; subtract 100
		mov	[dec_num],	al
		inc	byte [dec_num100s]
		jmp .hundreds_loop

	.tens_loop:
		mov	al,			[dec_num]
		cmp	al,			10				; compare to 10
		jb				.ones_loop
		mov	al,			[dec_num]
		stc								; set carry
		sub	al,			10				; subtract 10
		mov	[dec_num],	al
		inc	byte [dec_num10s]
		jmp .tens_loop
		
	.ones_loop:
		mov	al,				[dec_num]
		mov [dec_num1s],	al

	;mov	si,		[dec_num100s]						; should this work??
	;mov	al,		byte ES:[hexOutLookup,si]			;
	;call		print_char_hex

	mov		al,		[dec_num100s]
	cmp		al,		0
	je		.print_10s
	call	print_char_dec_digit
	.print_10s:
	mov		al,		[dec_num10s]
	call	print_char_dec_digit
	mov		al,		[dec_num1s]
	call	print_char_dec_digit

	pop		bx
	pop		ax

	ret

print_char_dec_digit:
	push	ax
	cmp		al,		0x0a
	sbb		al,		0x69
	das
	call	print_char
	pop		ax
	ret

kbd_get_scancode:
	; Places scancode into al

	push	dx

	mov		al,				CTL_CFG_PB_IN
	mov		dx,				PPI2_CTL
	out		dx,				al
	; mov		[ppi2_ccfg],	al					; Remember current (latest) config
	mov		dx,				PPI2_PORTB			; Get B port address
	in		al,				dx					; Read PS/2 keyboard scancode into al
	mov		ah,				0					; testing - saftey

	pop		dx
	ret

kbd_scancode_to_ascii:
	; ax is updated with the ascii value of the scancode originally in ax
	push	bx
	
	test	word [kb_flags],		SHIFT
	jne		.shifted_key			; if shift is down, jump to .shifted_key, otherwise, process as not shifted key

	.not_shifted_key:
		;and		ax,		0x00FF		; needed?
		mov		bx,		ax
		mov		ax,		ES:[ keymap + bx]			; can indexing be done with bl? "invalid effective address"
		mov		ah,		0
		;and		ax,		0x00FF		; needed?
		jmp		.out

	.shifted_key:
		;and		ax,		0x00FF		; needed?
		mov		bx,		ax
		mov		ax,		ES:[ keymap_shifted + bx]			; can indexing be done with bl? "invalid effective address"
		mov		ah,		0
		;and		ax,		0x00FF		; needed?
		; fall into .out

	.out:
		pop		bx
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
	mov		al,					CTL_CFG_PA_IN		; Get config value
	mov		dx,					PPI1_CTL			; Get control port address
	out		dx,					al					; Write control register on PPI
	;mov		[ppi1_ccfg],		al					; Remember current config
	.again:	
		mov		al,				(RW)				; RS=0, RW=1, E=0
		mov		dx,				PPI1_PORTB			; Get B port address
		out		dx,				al					; Write to port B
		mov		al,				(RW|E)				; RS=0, RW=1, E=1
		out		dx,				al					; Write to port B
	
		mov		dx,				PPI1_PORTA			; Get A port address

		in		al,				dx				; Read data from LCD (busy flag on D7)
		rol		al,				1				; Rotate busy flag to carry flag
		jc		.again							; If CF=1, LCD is busy
		mov		al,				CTL_CFG_PA_OUT	; Get config value
		mov		dx,				PPI1_CTL		; Get control port address
		out		dx,				al				; Write control register on PPI
		;mov		[ppi1_ccfg],	al					; Remember current config

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
	nop
	pop		ax
	ret

lcd_line2:
	push	ax
	mov		al,		0b10101000		; Go to line 2
	call	lcd_command_write
	pop		ax
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
		
play_sound:
	push	ax
	push	dx

	mov		al,				CTL_CFG_PA_OUT				; Get config value - PA_OUT includes PB_OUT also
	mov		dx,				PPI1_CTL					; Get control port address
	out		dx,				al							; Write control register on PPI
	;mov		[ppi1_ccfg],	al							; Remember current config

	mov		bp, 0x01FF									; Number of "sine" waves (-1) - duration of sound
	.wave:
		.up:
			mov		al,		0x1
			mov		dx,		PPI1_PORTC					; Get C port address
			out		dx,		al							; Write data to port C
			mov		si,		0x0060						; Hold duration of "up"

			.uploop:
				nop
				dec		si
				cmp		si,	0
				jnz		.uploop

		.down:
			mov		al,		0x0
			mov		dx,		PPI1_PORTC					; Get C port address
			out		dx,		al							; Write data to port C
			mov		si,		0x0060						; Hold duration of "down"

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

times 0x30000-($-$$)-0x0800 db 0xff	; Fill much of ROM with FFs to allow for faster writing of flash ROMs


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

	; strings
		msg_286at8					db	'80286 at 8 MHz!', 0x0
		msg_loading					db	'Loading...', 0x0
		msg_vga_test_header			db	'Dynamically-generated Test Pattern', 0x0
		msg_vga_test_red			db	'Red 0-31 (5 bits)', 0x0
		msg_vga_test_green			db	'Green 0-63 (6 bits)', 0x0
		msg_vga_test_blue			db	'Blue 0-31 (5 bits)', 0x0
		msg_vga_test_footer			db	'640x480x2B  RGB565  --  5x7 fixed width font', 0x0
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

	hexOutLookup:					db	'0123456789ABCDEF'

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
		db "?CXDE$#?? VFTR%?"          ; 20-2F			; had to swap # and $ on new keyboard (???)
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

	R			dd		91.67			; 42b7570a				In ROM: 0a57b742
	
	charmap:							; ASCII 0x20 to 0x7F	Used in VGA character output
		%include "charmap.asm"

	sprite_ship:
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x18C3,0x62EB,0x630C,0x5B2C,0x4A68,0x3185,0x3185,0x2965,0x2944,0x2924,0x2124,0x2104,0x2965,0x0841,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x2964,0xA532,0xA4D1,0xAC2F,0x730A,0x39A6,0x31A6,0x31A6,0x3185,0x3185,0x3185,0x3185,0x4207,0x18C2,0x0820,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x1040,0x3100,0x4080,0x7000,0x6962,0x4227,0x31A6,0x31A6,0x3165,0x2965,0x2965,0x4228,0x18A2,0x0020,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x2060,0x6163,0x8266,0xBCD0,0x8BAC,0x18E3,0x10A2,0x10A2,0x1082,0x1082,0x1082,0x2124,0x0861,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x62A8,0xA42E,0xA46F,0xB5D5,0x840E,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0020,0x9490,0xAD73,0xA512,0xAD32,0x7BAC,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x2124,0xBDF6,0xCE78,0xC616,0xC637,0x8C4F,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x31A5,0xD6B9,0xD6B9,0xDEDA,0xD6D9,0x8C4F,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0882,0x1166,0x2A08,0x630B,0x5AA9,0x736C,0xC616,0xCE58,0xD679,0xD658,0xA42E,0x20E3,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x08C4,0x226B,0x4BAF,0xB574,0xA4F2,0x7BAD,0x9470,0xD6BA,0xE71B,0xDEDA,0xBC90,0x3164,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0020,0x0000,0x39A6,0x7BAD,0x8C2E,0x8C0E,0x8C0E,0x9C4F,0x738D,0x4208,0x0861,0x0820,0x0820,0x0020,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x3185,0x8C0D,0x6B2A,0x6AE9,0x734A,0x9CB0,0xB594,0xCE77,0xD698,0x7B2B,0x4944,0x59C6,0x6A68,0x6AA9,0x6AEA,0x5A88,0x4A27,0x41E6,0x3985,0x3144,0x3144,0x39A6,0x2124,0x0861,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x41E6,0x4A06,0x20A1,0x3122,0x49C4,0x4A05,0x49E4,0x5A66,0x6B09,0x40E3,0x2861,0x2040,0x2861,0x4124,0x83AC,0x9CAF,0x946E,0x944D,0x942D,0x93EC,0x8BAB,0x9C8F,0xAD53,0x9CB1,0x3165,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x3164,0x5246,0x4A05,0x5A66,0x5246,0x5226,0x5226,0x5A66,0x5A66,0x38E2,0x2861,0x2860,0x2881,0x30A1,0x49A4,0x51C4,0x4984,0x4163,0x3123,0x28E2,0x28E2,0x3143,0x3164,0x2103,0x0020,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0820,0x4A26,0x49E5,0x41A4,0x41A4,0x4183,0x49E5,0x5A67,0x4A06,0x20A1,0x1820,0x1840,0x1840,0x0820,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0041,0x08E4,0x2186,0x5289,0x4A28,0x41E6,0x736C,0x9CD1,0xA512,0xA4F2,0x8B8C,0x3164,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0020,0x1105,0x22CD,0x5411,0xBDB4,0xAD53,0x946F,0x9CB1,0xE71B,0xEF7D,0xEF3C,0xC4F1,0x39C5,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0841,0x0020,0x2944,0x944F,0xA4F2,0xA512,0xA4F2,0x838C,0x0020,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x2103,0x944F,0x9470,0x944F,0xBDD5,0x9490,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x1061,0x734A,0x83CD,0xA4F1,0xBDD5,0x83EE,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x62C8,0x9C90,0xA512,0xAD32,0x7BAD,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x6206,0xA309,0x9B8B,0xC656,0x842E,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x30E1,0x7222,0x71A1,0x91C5,0x7A87,0x4227,0x39E7,0x31A6,0x31A6,0x3185,0x2965,0x4A28,0x18E3,0x0020,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x2943,0x8C6C,0x8B69,0xA143,0x6984,0x2985,0x2104,0x20E3,0x20E3,0x20E3,0x18E3,0x2944,0x18E3,0x0841,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x31A6,0xBDD6,0xB5B5,0xB5B5,0x83CD,0x4A48,0x4A68,0x4A48,0x4A48,0x4A28,0x4207,0x41E7,0x52A9,0x18E3,0x0820,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0841,0x0841,0x0841,0x0841,0x0020,0x0020,0x0020,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
		dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000



times 0x0fff0 - ($-$$) db 0xff		; fill remainder of section with FFs (faster flash ROM writes)
									; very end overlaps .bootvector

; https://www.nasm.us/xdoc/2.15.05/html/nasmdoc7.html#section-7.3
section .bootvector	start=0x3fff0
	reset:						; at 0xFFFF0			*Processor starts reading here
		jmp 0xc000:0x0			; Jump to TOP: label

; times 0x040000-($-$$) db 0xff	; Fill the rest of ROM with bytes of 0x01 (256 KB total)
times 0x10 - ($-$$) db 0xff		; 16 - length of section so far (i.e., fill the rest of the section)