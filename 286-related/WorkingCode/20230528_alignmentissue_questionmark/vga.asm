isr_video:						; INT10H
	; in: ah = function
	; https://en.wikipedia.org/wiki/INT_10H
	; 640/(5+1) = 106 character columns of 5x7 font with one pixel between chars (cols)
	; 480/(8) = 60 character rows of 5x7 font with one pixel between chars (rows)

	; to do switch to jump table

	push	es
	
	;push	ax
	;mov		al,	'1'
	;call	print_char_spi
	;mov		al,	'0'
	;call	print_char_spi
	;mov		al,	':'
	;call	print_char_spi
	;pop		ax
	;push	ax
	;call	debug_print_interrupt_info_sm
	;mov		al,	'-'
	;call	print_char_spi
	;pop		ax

	push	0xf000			; Read-only data in ROM at 0x30000 (0xf0000 in address space  0xc0000+0c30000). 
	pop		es

	.setcursorposition:		; 0x02
		cmp		ah,		0x02
		jne		.readcursorposition
		; BX = x pos in pixels
		; CX = y pos in pixels
		push	ds
		call	to0000ds
		mov		[cursor_pos_h],		bx
		mov		[cursor_pos_v],		cx
		pop		ds
		jmp		.out
	.readcursorposition:	; 0x03
		cmp		ah,		0x03
		jne		.writechar
		; OUT BX = x pos in pixels
		; OUT CX = y pos in pixels
		push	ds
		call	to0000ds
		mov		bx,				[cursor_pos_h]
		mov		cx,				[cursor_pos_v]
		pop		ds
		jmp		.out
	.writechar:				; 0x0a			; 123
		; al = char
		; bh = page number						-ignore page number and write to both pages
		; cx = num times to print				-ignore for now
		
		cmp		ah,		0x0a
		jne		.writepixel
		push	ds
		call	to0000ds
		
		mov		word [vga_param_color],	0b0000011111100000
		call	print_char_vga
		call	print_char_spi
		
		pop		ds
		jmp		.out
	.writepixel:			; 0x0c
		; AH = 0C
		; AL = color value (XOR'ED with current pixel if bit 7=1)		; !! only have 8 bits for color, instead of 16 -- to do: scale 16 down to 8
		; BH = page number
		; CX = column number (zero based)
		; DX = row number (zero based)
	
		cmp		ah,		0x0c
		jne		.writetext
		; temp hack - just duplicate al to ah (need to scale 16 to 8 bit instead, using highest bits of each color in 8-bit)
		mov		ah,		al			; e.g., 00000000_11111111 ==> 11111111_11111111  (RGB565)
	
		; params for vga_draw_pixel to be pushed onto stack
		push	cx					; pixel x
		push	dx					; pixel y
		push	ax					; pixel color
		call	vga_draw_pixel		; 
	
		jmp		.out
	.writetext:				; 0x0e
		;AL = ASCII character to write
		;BH = page number (text modes)
		;BL = foreground pixel color (graphics modes)
		
		cmp		ah,		0x0e
		jne		.get_video_state
		push	ds
		call	to0000ds

		mov		word [vga_param_color],	0xffff
		call	print_char_vga
		call	print_char_spi
		
		pop		ds
		jmp		.out
	.get_video_state:		; 0x0f
		;on return:
		;AH = number of screen columns
		;AL = mode currently set
		;BH = current display page
		
		cmp		ah,		0x0f
		jne		.char_gen_routine
		mov		ah,		106				; 106 columns
		mov		al,		0x12			; 640x480 16 color graphics (VGA)
		mov		bh,		0
		jmp		.out
	.char_gen_routine:		;0x11
	;!!!!!!!!!!!!! TO DO IMPLEMENT:
		cmp		ah,		0x11
		jne		.swapframe

		.chargen12:
			cmp		al,		0x12		;ROM 8x8 double dot character definitions
			jne		.chargen_unsupported

			;BL = table in character generator RAM
			;on return:
			;	CX = bytes per character (points)
			;	DL = rows (less 1)
			;	ES:BP = pointer to table

			mov		cx,		0x0008
			mov		dl,		0x0008
			;es should already be 0xf000, don't pop original incoming value
			pop		es		;throw away original es
			push	0xf000
			pop		es
			mov		bp,		charmap				;not the right charmap but pointing here for now...
			
			iret
		.chargen_unsupported:
			push	ax
			mov		al, 0x10	; current interrupt #
			call	missing_interrupt_tospi
			mov		al, ' '
			call	print_char_spi
			pop		ax
			call	print_char_hex_spi
			jmp		.out

	.swapframe:				; 0xb0
		cmp		ah,		0xb0
		jne		.setprintcharoptions
		call	vga_swap_frame
		jmp		.out
	.setprintcharoptions:	; 0xb1
		cmp		ah,		0xb1
		jne		.readprintcharoptions
		; BX = print char options
		push	ds
		call	to0000ds
		mov		[print_char_options],	bx
		pop		ds
		jmp		.out
	.readprintcharoptions:	; 0xb2
		cmp		ah,		0xb2
		jne		.writepixel_extended
		; OUT BX = print char options
		push	ds
		call	to0000ds
		mov		bx,		[print_char_options]
		pop		ds
		jmp		.out
	.writepixel_extended:	; 0xb3
		; Supports 16-bit color
		; AH = 0C
		; BX = 16-bit color
		; CX = column number (zero based)
		; DX = row number (zero based)
	
		cmp		ah,		0xb3
		jne		.clearscreen
	
		; params for vga_draw_pixel to be pushed onto stack
		push	cx					; pixel x
		push	dx					; pixel y
		push	bx					; pixel color
		call	vga_draw_pixel		; pixels for right side of circle
	
		jmp		.out
	.clearscreen:			; 0xb4
		cmp		ah,		0xb4
		jne		.draw_rect_filled
		call	vga_init	; color in DX
		jmp		.out
	.draw_rect_filled:		; 0xb5
		cmp		ah,		0xb5
		jne		.print_char_hex
		; BX = start x
		; CX = start y
		; DX = end x
		; DI = end y
		; SI = color
		
		;push	bx
		;push	cx
		;push	dx
		;push	di
		;push	si
		;call	vga_draw_rect_filled
		jmp		.out
    .print_char_hex:		; 0xb6
		cmp		ah,		0xb6
		jne		.unimplemented

		push	ds
		call	to0000ds
		
		call	print_char_hex_spi
		call	print_char_hex_vga

		pop		ds
		jmp		.out
	.unimplemented:
		push	ax
		mov		ax,	0000
		mov		dx, ax
		mov		ax, 0xf000
		mov		es, ax
		call	lcd_clear
		mov		al, '!'
		call	print_char
		mov		al, 'I'
		call	print_char
		mov		al, 'N'
		call	print_char
		mov		al, 'T'
		call	print_char
		mov		al, '1'
		call	print_char
		mov		al, '0'
		call	print_char
		mov		al, ':'
		call	print_char
		pop		ax
		xchg	ah, al
		call	print_char_hex
		xchg	ah, al
		call	print_char_hex
		call	debug_print_interrupt_info_sm
		call	play_error_sound
		call	delay
		call	play_error_sound
		call	delay
		call	play_error_sound
		call	delay
		call	play_error_sound
		call	delay
		call	play_error_sound
		call	delay
		call	play_error_sound
		hlt		; temporary
	.out:
		pop		es

		;call	debug_print_interrupt_info_sm
		;call	print_char_newline_spi

		iret

_debug_print_interrupt_info_10:
	push	ax		; save ax

	xchg	ah, al
	mov		ah, CMD_PRINT_INTERRUPT_10>>8
	call	spi_send_NanoSerialCmd
	;call	delay

	;call	debug_print_newline
	
	mov		ah, 0x01			; spi cmd 1 - print char
	mov		al, 0x09			; horizontal tab
	call	spi_send_NanoSerialCmd

	pop		ax		; retrieve ax
	push	ax		; save ax again

	call	debug_print_word_hex		; print ax
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd

	mov		ax, bx
	call	debug_print_word_hex		; print bx
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd

	mov		ax, cx
	call	debug_print_word_hex		; print cx
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd

	mov		ax, dx
	call	debug_print_word_hex		; print dx
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd

	mov		ax, cs
	call	debug_print_word_hex		; print cs
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd

	mov		ax, ds
	call	debug_print_word_hex		; print ds
	mov		ah, 0x01					; spi cmd 1 - print char
	mov		al, '|'						; horizontal tab
	call	spi_send_NanoSerialCmd

	mov		ax, es
	call	debug_print_word_hex		; print es

	;call	debug_print_newline
	mov		ah, 0x01			; spi cmd 1 - print char
	mov		al, 0x09			; horizontal tab
	call	spi_send_NanoSerialCmd

	pop		ax
	ret

vga_post_screen:
	push	ds
	push	es
	push	ax
	push	bx
	push	di

	call	to0000ds
	mov		bx, 0xf000
	mov		es, bx

	mov		bx,	sprite_rehsd
	mov		di, 1212					; 2bpp - at position 1214/2 = 606
	call	gfx_draw_sprite_32x32

	mov		di,	2
	mov		word [print_char_options], 0b00000000_00000001		; no frame swap

	.frame:
		mov		word [vga_param_color],		0b11111_111111_00000		; change font color
		mov		word [cursor_pos_h],		0
		mov		word [cursor_pos_v],		2
		mov		bx,							msg_vga_post_version
		call	print_message_vga

		mov		word [vga_param_color],		0b00000111_11111111		; change font color (vga_init/escape resets to white)
		;mov		word [vga_param_color],		0b11111_111111_11111		; change font color
		mov		word [cursor_pos_h],		0
		mov		word [cursor_pos_v],		20
		mov		bx,							msg_vga_prompt
		call	print_message_vga

	call	vga_swap_frame
	dec		di
	jne		.frame


	.out:
		mov		ax,			0x0										; reset VGA register to defaults
		out		VGA_REG,	ax
		mov		word [print_char_options], 0b00000000_00000000		; restore default of frame swap
		call	vga_swap_frame
		pop		di
		pop		bx
		pop		ax
		pop		es
		pop		ds
	ret

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
	; Take screen init color in as dx

	push	ds
	push	ax
	push	cx
	push	si
	push	di
	push	es
	call	to0000ds
	
	mov		cx,	0x0000				; segment #
	mov		di, 0xfffe				; offset within segment  (i.e., 0xfffe down to 0x0000)
	mov		si, 0xa000				; segment start (i.e., 0xa000 as top)
	mov		es, si
	;mov		bx, 0b00000000_00000001					; color shift

	in		ax,	VGA_REG						; reset register
	and		ax, 0b1111_1111_1111_0000		; last four bits control active page - reset to 0000
	out		VGA_REG,		ax

	.offset:		; fill frame 0 with black
		mov		word es:[di],	dx				; write color

		sub		di,				2				; drop down a word
		cmp		di,				0xfffe			; if equal, it wrapped around - done with this segment
		jnz		.offset

		inc		cx
		cmp		cx, 16
		je		.next

		and		ax, 0b1111_1111_1111_0000
		or		ax, cx
		out		VGA_REG,		ax
		cmp		cx, 16			; fill all 16 segments
		jne		.offset

	.next:
		call	vga_swap_frame
		in		ax,	VGA_REG						; reset register
		and		ax, 0b1111_1111_1111_0000		; last four bits control active page - reset to 0000
		out		VGA_REG,		ax
		mov		cx,	0x0000						; segment #

	.offset2:		; fill frame 1 with black
		mov		word es:[di],	dx			; write color

		sub		di,				2				; drop down a word
		cmp		di,				0xfffe			; if equal, it wrapped around - done with this segment
		jnz		.offset2

		inc		cx
		cmp		cx,	16
		je		.out
		
		in		ax,	VGA_REG
		and		ax, 0b1111_1111_1111_0000
		or		ax, cx
		out		VGA_REG,		ax
		cmp		cx, 16			; fill all 16 segments
		jne		.offset2

		; ** no need to swap it at this point

	.out:

		in		ax,	VGA_REG						; reset register to 0
		and		ax, 0b1111_1111_1111_0000		; last four bits control active page - reset to 0000
		out		VGA_REG,		ax

		mov		word [cursor_pos_h],	0x0
		mov		word [cursor_pos_v],	0x0
		mov		word [pixel_offset_h],	0x0
		mov		word [pixel_offset_v],	0x0
		;mov		word [vga_param_color],	0xffff
		;mov		word [clear_screen_flag],	0x0

		pop		es
		pop		di
		pop		si
		pop		cx
		pop		ax
		pop		ds

		ret

vga_swap_frame:
	; swaps frames on VGA card
	push	ax
	push	ds
	call	to0000ds

	in		ax,			VGA_REG		;0x00a0	;VGA_REG
	xor		ax,			0b0000_0000_0001_0000	; bit4 = 286 active frame (VGA out active frame is opposite automatically)
	out		VGA_REG,	ax		;0x00a0, ax	;VGA_REG,	ax

	; TO DO implement interrupt support on VGA card as alternative to the following status polling
	.wait:
		in		ax,	VGA_REG		;0x00a0 ;VGA_REG
		test	ax, 0b1000_0000_0000_0000		; Looking for bit15 to be 0. Value 1 = frame switch is pending (tied to VSYNC).
		jnz		.wait							; wait
	
	pop		ds
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
		add		si,	80				; move over 40 pixels (80 bytes) in sprite source data
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

gfx_draw_sprite_32x32:
	;		in: bx -> pointer to sprite
	;		in: di -> location within segment for sprite destination (memory offset from A0000)
	pusha
	push	ds

	push	es

	;		ds:si	-> source data
	;		es:di	-> target buffer
	;		cx		= Number of words to copy
	;		bx		-> 32x32 sprite (offset)
	push	di		; save for re-use
	mov		cx, 32	; sprite width = 32


	; destination - start at 0xa00000
	mov		si, 0xa000
	mov		es, si

	;mov		di, 0x0			;passed in
	mov		dx, 0x0
	; source	  - start at 0xf0000 + offset for sprite
	mov		si, 0xf000
	mov		ds, si
	mov		si, bx
	.loop:
		call	memcpy_w			; copy the row of the sprite (one word / pixel at a time)
		add		si,	64				; move over 32 (64 bytes) pixels in sprite source data
		add		di, 2048			; move to next row on VGA
		inc		dx
		cmp		dx, 32				; if=32, done with this sprite instance
		jne		.loop

	call vga_swap_frame			; show the sprite

	;mov		di, 0x0
	pop		di
	mov		dx, 0x0				; reset sprite row counter
	; source	  - start at 0xf0000 + offset for sprite
	mov		si, 0xf000			; reset source to beginning of sprite
	mov		ds, si
	mov		si, bx				; bx points to sprite
	.loop2:
		call	memcpy_w			; copy the row of the sprite (one word / pixel at a time)
		add		si,	64				; move over 32 (64 bytes) pixels in sprite source data
		add		di, 2048			; move to next row on VGA
		inc		dx
		cmp		dx, 32				; if=32, done with this sprite instance
		jne		.loop2

	.out:
		;popa does not include DS or ES
		pop		es
		pop		ds
		popa
		ret

print_char_vga:
	pusha
	push	ds
	push	es
	call	to0000ds
	call	es_point_to_rom
	; al has ascii value of char to print

	and		ax,								0x00ff							; only care about lower byte (this line should not be needed... safety for now)
	
	cmp		word [cursor_pos_v], 470
	jle		.cont
		;since the cursor is near the bottom edge of the screen, clear the screen
		push	dx
		mov		dx, 0x0000						; init vga with black
		call	vga_init
		pop		dx
		mov		word [cursor_pos_v],	0x05
	.cont:

	; if 0x0a (line feed), move cursor down and get out
		cmp		al,		0x0a
		jne		.notlinefeed
		add		word	[cursor_pos_v],		9
		pop		es
		pop		ds
		popa
		ret
	.notlinefeed:
	; if 0x0d (carriage return), move cursor left and get out
		cmp		al,		0x0d
		jne		.notcr
		mov		word	[cursor_pos_h],		0
		;add		word	[cursor_pos_v],		9		;****
		pop		es
		pop		ds
		popa
		ret
	.notcr:

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
	mov		[charpix_line1],				al	
	mov		al,								es:[charmap+bx+1]				; remember row 2
	mov		[charpix_line2],				al							
	mov		al,								es:[charmap+bx+2]				; remember row 3
	mov		[charpix_line3],				al						
	mov		al,								es:[charmap+bx+3]				; remember row 4
	mov		[charpix_line4],				al							
	mov		al,								es:[charmap+bx+4]				; remember row 5
	mov		[charpix_line5],				al							
	mov		al,								es:[charmap+bx+5]				; remember row 6
	mov		[charpix_line6],				al							
	mov		al,								es:[charmap+bx+6]				; remember row 7
	mov		[charpix_line7],				al							
	

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
			cmp		word [charPixelRowLoopCounter],	0x07
			jne		.rows


	; add		word [cursor_pos_h], 6

	mov		ax,		[print_char_options]
	test	ax,		0b00000000_00000001
	jne		.out

	call	vga_swap_frame			; make updates visible on VGA output
	;jmp		.out

	; repeat for other frame (need to factor / optimize at some point)
	
	mov		word [charPixelRowLoopCounter],	0x0000							; init to zero
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
			cmp		word [charPixelRowLoopCounter],	0x07
			jne		.rows2


	; * don't need to swap right now - change is already visible on the current frame

	.out:
	add		word [cursor_pos_h], 6
	cmp		word [cursor_pos_h], 630
	jle		.out2
		;since the cursor is near the right edge, CRLF
		call	vga_nextline
	.out2:
		pop		es
		pop		ds
		popa
		ret

vga_draw_pixel:
	; description:	draws a pixel at x,y pixel position with specified 2-byte color
	;				*this is a NEWER version of the procedure
	; params:		(3 params on stack - push params on stack in reverse order of listing below)
	;				*old base pointer				= bp
	;				*return address					= bp+2
	;				[in]		color				= bp+4
	;				[in]		y position			= bp+6
	;				[in]		x position			= bp+8
	;				[return]	none

	push	bp									; save base pointer
	mov		bp,				sp					; update base pointer to current stack pointer
	
	push	ds
	push	ax
	push	bx
	push	dx
	push	si
	push	es
	call	to0000ds

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
	pop		ds
	pop		bp
	ret		6									; return, pop 6 bytes for 3 params off stack

vga_read_pixel:
	; description:	reads a pixel at x,y pixel position
	; params:		(3 params on stack - push params on stack in reverse order of listing below)
	;				*old base pointer				= bp
	;				*return address					= bp+2
	;				[in]		y position			= bp+4
	;				[in]		x position			= bp+6
	;				[return]	ax with color

	push	bp									; save base pointer
	mov		bp,				sp					; update base pointer to current stack pointer
	
	push	bx
	push	dx
	push	si
	push	es


	mov		dx,				[bp+4]				; pass y position in dx
	call	vga_set_segment_from_xy				; update VGA segment based on y position
	mov		bx,				[bp+6]				; pass x position in bx (y already be in dx)
	call	vga_get_pixel_mem_addr				; get address within selected 64K VRAM segment, returned in bx

	mov		si,				0xa000
	mov		es,				si

	mov		word ax,		es:[bx]				; get pixelcolor
	pop		es
	pop		si
	pop		dx
	pop		bx
	pop		bp
	ret		4

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

	push	ds
	push	es
	push	si
	push	ax
	push	bx
	push	dx
	call	to0000ds
	
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
	pop		ds
	ret

vga_nextline:
	push	ds
	call	to0000ds
	add		word	[cursor_pos_v],		9
	mov		word	[cursor_pos_h],		0
	pop		ds
	ret

print_message_vga:
	; Send a NUL-terminated string to the VGA display;
	; In: ES:BX -> string to print
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
			;instead:
			;mov		ah,		0x0a		; write character at current cursor position, no color specified
										; al=char to write
			;int		0x10				; call interrupt 0x10


		inc		bx 				; Increment the index
		jmp		.loop 			; And loop back
	
	.return: 
		sub		bx, cx 			; Calculate our number of characters printed
		mov		ax, bx 			; And load the result into AX
		pop		cx 				; Restore CX
		pop		bx 				; and BX from the stack
		ret 					; Return to our caller

print_RAMmessage_vga:
	; In: DS:BX -> string to print
	; Return: AX = number of characters printed
	; All other registers preserved or unaffected.
	; **thank you, Damouze!

	push	bx 					; Save BX 
	push	cx 					; and CX onto the sack
	mov		cx, bx 				; Save contents of BX for later use
	
	.loop:
		mov		al, ds:[bx]		; Read byte from [DS:BX]
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

print_CSmessage_vga:
	; In: CS:BX -> string to print
	; Return: AX = number of characters printed
	; All other registers preserved or unaffected.
	; **thank you, Damouze!

	push	bx 					; Save BX 
	push	cx 					; and CX onto the sack
	mov		cx, bx 				; Save contents of BX for later use
	
	.loop:
		mov		al, [bx]		; Read byte from [CS:BX]
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

print_char_hex_vga:
	push	ax

	and		al,		0xf0		; upper nibble of lower byte
	shr		al,		4
	cmp		al,		0x0a
	sbb		al,		0x69
	das
	call	print_char_vga

	pop		ax
	push	ax
	and		al,		0x0f		; lower nibble of lower byte
	cmp		al,		0x0a
	sbb		al,		0x69
	das
	call	print_char_vga

	pop		ax
	ret

;print_char_hex_vga:
;	; Print the byte in AL as hex digits to the screen
;	; In:	AL = byte to print
;	; Return: Nothing
;	; thank you, @Damouze
;    
;	rol     al, 4
;    call    nibble_to_hex
;    call    print_char_vga
;    rol     al, 4 
;    call    print_char_vga
;    ret