keyboard_init:
	mov	word	[kb_flags],		0x0000
	mov word	[kb_wptr],		0x0000
	mov word	[kb_rptr],		0x0000
	call		clear_os_buffer		
	ret

mouse_init:
	mov		word [mouse_flags],	0			; mouse cursor not visible. use MOUSE_CUROSOR_VISIBLE to make visible.
	ret

mouse_isr:		; mouse movement isr
	pusha
	push	ds
	call	to0000ds

	test	word [mouse_flags],	MOUSE_CURSOR_VISIBLE
	je		.out

	;mov		ax, [mouse_buttons]
	;mov		[mouse_buttons_prev],	ax
	call	spi_getKeyboardMouseData
	call	draw_mouse_pointer

	;cmp		word [INT34H_IVT_OFFSET],	0x0
	;je		.no_userdef_isr
	
		;mov		ax, [mouse_buttons]
		;cmp		[mouse_buttons_prev], ax
		;je		.no_userdef_isr
		;sti
	
		;;mov		dx,		[mouse_buttons]
		;push	es
		;push	ds
		;mov		ax,	0x2000
		;mov		ds, ax
		;int		0x32		; c++ doesn't return out of isr properly
		;cli
		;pop		ds
	
	;.no_userdef_isr:

	mov		al,			0x20		; EOI byte for OCW2 (always 0x20)
	out		PICM_P0,	al			; to port for OCW2

	.out:
		pop		ds
		popa
		iret

mouse_services_isr:		; INT 33H
	; AX = 01	Show mouse cursor
	; AX = 02	Hide mouse cursor

	;call	debug_print_interrupt_info

	push	ds
	push	es

	push	0x0
	pop		ds

	.show:
		cmp		ax,		0x0100
		jne		.hide
		or		word [mouse_flags],		MOUSE_CURSOR_VISIBLE			; set flag
		jmp		.out
	.hide:
		cmp		ax,		0x0200
		jne		.getmousebuttonpressinfo
		and		word [mouse_flags],		~MOUSE_CURSOR_VISIBLE			; clear flag
		and		word [mouse_flags],		~CURSOR_INITIALIZED_ODD
		and		word [mouse_flags],		~CURSOR_INITIALIZED_EVEN
		jmp		.out
	.getmousebuttonpressinfo:
		cmp		ax,		0x0500
		jne		.out
		;BX = 0	left button
		;	  1	right button
		;on return:
		;	BX = count of button presses (0-32767), set to zero after call
		;	CX = horizontal position at last press
		;	DX = vertical position at last press
		;	AX = status:
		;		|F-8|7|6|5|4|3|2|1|0|  Button Status
		;		  |  | | | | | | | `---- left button (1 = pressed)
		;		  |  | | | | | | `----- right button (1 = pressed)
		;		  `------------------- unused
		mov	ax,		[mouse_buttons]
		mov	cx,		[mouse_pos_x]
		mov	dx,		[mouse_pos_y]
		jmp		.out
	.out:
		pop		es
		pop		ds
		iret

keyboard_isr:
	pusha

	call	spi_getKeyboardMouseData

	; add 2-byte key data to buffer and let main_loop handle it
	; msb is extra data like ctl,shift status
	; lsb is char
	
	call	lcd_clear
	mov		ax,			[keyboard_data]
	xchg	ah,			al
	call	print_char_hex
	xchg	ah,			al
	call	print_char_hex

	; place word into buffer to be called during normal looping, outside of interrupt
	mov		bx,				[kb_wptr]
	mov		di,				bx
	mov		[kb_buffer+di],	ax
	mov		di,				[os_buffer_wptr]
	mov		[os_buffer+di], ax

	call	keyboard_inc_wptr
	call	os_buffer_inc_wptr

	mov		al,			0x20		; EOI byte for OCW2 (always 0x20)
	out		PICM_P0,	al			; to port for OCW2

	popa
	iret

kbd_isr_doscom:
	;check for Enter, call osr enter
	;put char data into buffers (kbd, os)
	;print char right away

	pusha

	mov		ax,					0x0000
	mov		ds,					ax
	
	call	spi_getKeyboardMouseData
	call	lcd_clear
	mov		ax,			[keyboard_data]



	;xchg	ah,			al
	;call	print_char_hex
	;xchg	ah,			al
	;call	print_char_hex

	; to do - adjust based on high byte 
	;call	adjust_char
	
	.esc:
		cmp		ax,		0x011b		; esc
		jne		.esc_shift
		call	lcd_clear
		jmp		.out
	.esc_shift:
		cmp		ax,		0x411b		; shift esc
		jne		.enter
		mov		dx,		0x0000		; black screen
		call	vga_init
		jmp		.out
	.enter:
		cmp		ax,		0x011e		; enter
		jne		.f1
		call	enter_pressed_doscom
		jmp		.out
	.f1:
		cmp		ax,		0x0161		; f1
		jne		.f2
		; do something here
		jmp		.out
	.f2:
		cmp		ax,		0x0162		; f2
		jne		.f3
		; do something here
		jmp		.out
	.f3:
		cmp		ax,		0x0163		; f3
		jne		.f4
		; do something here
		jmp		.out
	.f4:
		cmp		ax,		0x0164		; f4
		jne		.f5
		; do something here
		jmp		.out
	.f5:
		cmp		ax,		0x0165		; f5
		jne		.f6
		; do something here
		jmp		.out
	.f6:
		cmp		ax,		0x0166		; f6
		jne		.f7
		; do something here
		jmp		.out
	.f7:
		cmp		ax,		0x0167		; f7
		jne		.f8
		; do something here
		jmp		.out
	.f8:
		cmp		ax,		0x0168		; f8
		jne		.f9
		; do something here
		jmp		.out
	.f9:
		cmp		ax,		0x0169		; f9
		jne		.f10
		; do something here
		jmp		.out
	.f10:
		cmp		ax,		0x016a		; f10
		jne		.f11
		; do something here
		jmp		.out
	.f11:
		cmp		ax,		0x016b		; f11
		jne		.f12
		; do something here
		jmp		.out
	.f12:
		cmp		ax,		0x016c		; f12
		jne		.ascii
		; do something here
		jmp		.out
	.ascii:

		push	di
		push	bx

		mov		bx,				[kb_wptr]
		mov		di,				bx
		mov		[kb_buffer+di],	ax
		mov		di,				[os_buffer_wptr]
		mov		[os_buffer+di], ax
		
		pop		bx
		pop		di
		call	keyboard_inc_wptr
		call	os_buffer_inc_wptr

		mov		ah,		0x0a		; write character at current cursor position, no color specified
									; al=char to write
		int		0x10				; call interrupt 0x10

		jmp		.out

	.out:
		mov		al,			0x20		; EOI byte for OCW2 (always 0x20)
		out		PICM_P0,	al			; to port for OCW2
		popa
		iret
	
clear_os_buffer:
	push	cx
	push	di

	mov		cx,	255
	.top:
		mov		di,							cx
		mov		byte [os_buffer+di],		0x0
	loop	.top
	mov		word [os_buffer_wptr],		0x0
	
	pop		di
	pop		cx

	ret

draw_mouse_pointer:
	; just using a filled circle for now
	push	dx
	push	di
	push	bx
	push	ax
	push	es
	push	ds

	call	to0000ds

	in		ax,			VGA_REG
	
	mov		dx, 0xa000		; video memory window
	mov		es, dx

	test	ax,			0b0000_0000_0001_0000
	je		.odd

	.even:
		;mov	ax,	'e'
		;call	print_char

		; restore previous screen data
			mov		ax,				[mouse_flags]
			test	ax,				CURSOR_INITIALIZED_EVEN
			je		.backup_e									; if first cursor draw, nothing to restore

			mov	di, 0x0000
			mov	si, 0x0000
			mov		cx,	[mouse_pos_x_prev_e]
			mov		dx,	[mouse_pos_y_prev_e]
			sub		cx, 2
			sub		dx, 2

			.row_e_r:			; even restore

				; get old pixel color
				mov		word ax,	[tile5e_backup+si]		

				; params for vga_draw_pixel to be pushed onto stack
				push	cx					; pixel x
				push	dx					; pixel y
				push	ax					; pixel color
				call	vga_draw_pixel		; 
			
				add		di,		2
				add		si,		2
				inc		cx
				cmp		di,		10
				jne		.row_e_r
				
				mov		cx,		[mouse_pos_x_prev_e]
				sub		cx,		2
				mov		di,		0
				inc		dx
				cmp		si,		50
				jne		.row_e_r
		; backup screen data where mouse pointer will be drawn - 
		.backup_e:
			mov		ax,				[mouse_flags]
			or		ax,				CURSOR_INITIALIZED_EVEN		; set flag
			mov		[mouse_flags],	ax
			mov	di, 0x0000
			mov	si, 0x0000
			mov		cx,	[mouse_pos_x]
			mov		dx,	[mouse_pos_y]
			sub		cx, 2
			sub		dx, 2

			.row_e_s:			; even save
				; params for vga_read_pixel to be pushed onto stack
				push	cx					; pixel x
				push	dx					; pixel y
				call	vga_read_pixel		; 
				; save pixel color
				mov		word [tile5e_backup+si],	ax
			
				add		di,		2
				add		si,		2
				inc		cx
				cmp		di,		10
				jne		.row_e_s
				
				mov		cx,		[mouse_pos_x]
				sub		cx,		2
				mov		di,		0
				inc		dx
				cmp		si,		50
				jne		.row_e_s			
		; save latest location as prev location so that it can be erased next time
		mov		ax, [mouse_pos_x]
		mov		[mouse_pos_x_prev_e], ax
		mov		ax, [mouse_pos_y]
		mov		[mouse_pos_y_prev_e], ax
		jmp		.out	
		
	.odd:
		;mov	ax,	'o'
		;call	print_char

		; restore previous screen data
			mov		ax,				[mouse_flags]
			test	ax,				CURSOR_INITIALIZED_ODD
			je		.backup_o									; if first cursor draw, nothing to restore

			mov	di, 0x0000
			mov	si, 0x0000
			mov		cx,	[mouse_pos_x_prev_o]
			mov		dx,	[mouse_pos_y_prev_o]
			sub		cx, 2
			sub		dx, 2

			.row_o_r:			; odd restore
				
				; get old pixel color
				mov		word ax,	[tile5o_backup+si]		

				; params for vga_draw_pixel to be pushed onto stack
				push	cx					; pixel x
				push	dx					; pixel y
				push	ax					; pixel color
				call	vga_draw_pixel		; 
			
				add		di,		2
				add		si,		2
				inc		cx
				cmp		di,		10
				jne		.row_o_r
				
				mov		cx,		[mouse_pos_x_prev_o]
				sub		cx,		2
				mov		di,		0
				inc		dx
				cmp		si,		50
				jne		.row_o_r
		; backup screen data where mouse pointer will be drawn - 
		.backup_o:
			mov		ax,				[mouse_flags]
			or		ax,				CURSOR_INITIALIZED_ODD		; set flag
			mov		[mouse_flags],	ax
			mov	di, 0x0000
			mov	si, 0x0000
			mov		cx,	[mouse_pos_x]
			mov		dx,	[mouse_pos_y]
			sub		cx, 2
			sub		dx, 2

			.row_o_s:			; odd save
				; params for vga_read_pixel to be pushed onto stack
				push	cx					; pixel x
				push	dx					; pixel y
				call	vga_read_pixel		; 
				; save pixel color
				mov		word [tile5o_backup+si],	ax
			
				add		di,		2
				add		si,		2
				inc		cx
				cmp		di,		10
				jne		.row_o_s
				
				mov		cx,		[mouse_pos_x]
				sub		cx,		2
				mov		di,		0
				inc		dx
				cmp		si,		50
				jne		.row_o_s			
		; save latest location as prev location so that it can be erased next time
		mov		ax, [mouse_pos_x]
		mov		[mouse_pos_x_prev_o], ax
		mov		ax, [mouse_pos_y]
		mov		[mouse_pos_y_prev_o], ax
		jmp		.out		
	
	.out:
		; draw on new frame
		mov		dx, [mouse_pos_x]
		mov		di, [mouse_pos_y]
		mov		bx, 2
		mov		ax,	0xffff
		call	vga_draw_circle_filled
		call	vga_swap_frame
		
		pop		ds
		pop		es
		pop		ax
		pop		bx
		pop		di
		pop		dx
		ret

os_buffer_inc_wptr:
	push		ax
	
	mov			ax, 0x0000
	mov			ds, ax

	mov			ax,				[os_buffer_wptr]
	cmp			ax,				200				; rolling -- need to improve this
	jne			.inc
	mov word	[os_buffer_wptr],		0
	jmp			.out

	.inc:
		add	word [os_buffer_wptr],	2
		; fall into .out
	.out:
		pop		ax
		ret
	
keyboard_inc_wptr:
	push		ax
	mov			ax,				[kb_wptr]
	cmp			ax,				200
	jne			.inc
	mov		word		[kb_wptr],		0
	jmp			.out

	.inc:
		add	word [kb_wptr],	2
	.out:
		pop		ax
		ret

keyboard_inc_rptr:
	push		ax
	mov			ax,				[kb_rptr]
	cmp			ax,				200
	jne			.inc
	mov		word	[kb_rptr],		0
	jmp			.out

	.inc:
		add word	[kb_rptr],	2
	.out:
		pop		ax
		ret

process_keyboard_buffer:
	;called from main_loop: when the write and read pointers of the keyboard buffer don't match

	push	ax
	push	bx

	mov		bl,		[kb_rptr]
	mov		bh,		0
	mov		ax,		[kb_buffer + bx]		; get the key data from the keyboad buffer

	; to do - process non-ascii keys here

	mov		word [print_char_options], 0b00000000_00000000		; restore default of frame swap
	
	; to do - adjust based on high byte 
	;call	adjust_char
	
	.esc:
		cmp		ax,		0x011b		; esc
		jne		.esc_shift
		call	lcd_clear
		jmp		.out
	.esc_shift:
		cmp		ax,		0x411b		; shift esc
		jne		.enter
		mov		dx,		0x0000		; black screen
		call	vga_init
		jmp		.out
	.enter:
		cmp		ax,		0x011e		; enter
		jne		.f1
		call	enter_pressed
		jmp		.out
	.f1:
		cmp		ax,		0x0161		; f1
		jne		.f2
		call	lcd_clear
		call	rtc_getTemp						; get temperature from RTC
		call	rtc_getTime						; get time from RTC
		call	lcd_line2
		jmp		.out
	.f2:
		cmp		ax,		0x0162		; f2
		jne		.f3
		; do something here
		jmp		.out
	.f3:
		cmp		ax,		0x0163		; f3
		jne		.f4
		; do something here
		jmp		.out
	.f4:
		cmp		ax,		0x0164		; f4
		jne		.f5
		; do something here
		jmp		.out
	.f5:
		cmp		ax,		0x0165		; f5
		jne		.f6
		mov		dx,			0x0000
		call	vga_init
		jmp		.out
	.f6:
		cmp		ax,		0x0166		; f6
		jne		.f7
		mov		dx,			0xffff
		call	vga_init
		jmp		.out
	.f7:
		cmp		ax,		0x0167		; f7
		jne		.f8
		mov		dx,			0x0000
		call	vga_init
		call	vga_draw_test_pattern
		jmp		.out
	.f8:
		cmp		ax,		0x0168		; f8
		jne		.f9
		mov		dx,			0x0
		call	vga_init
		call	draw_shapes
		jmp		.out
	.f9:
		cmp		ax,		0x0169		; f9
		jne		.f10
		call	load_image_from_sdcard
		jmp		.out
	.f10:
		cmp		ax,		0x016a		; f10
		jne		.f11
		; do something here
		jmp		.out
	.f11:
		cmp		ax,		0x016b		; f11
		jne		.f12
		; do something here
		jmp		.out
	.f12:
		cmp		ax,		0x016c		; f12
		jne		.ascii
		call	vga_swap_frame
		; call	delay
		; do something here
		jmp		.out
	.ascii:

	call	print_char
	mov		ah,		0x0a		; write character at current cursor position, no color specified
								; al=char to write
	int		0x10				; call interrupt 0x10
	;call	print_char_vga		; replaced with int call above
	
	.out:
		call	keyboard_inc_rptr
		pop		bx
		pop		ax
		jmp		main_loop			

adjust_char:
	; ax in (from Nano) - high byte describes char (shift, control, ...), low byte is ascii value (for ascii values)

	ret

enter_pressed:
	push	bx
	call	process_os_command

	call	lcd_line2

	; mov		ah,							0x01			; spi cmd 1 - print char
	; call	spi_send_NanoSerialCmd

	add		word	[cursor_pos_v],		9
	mov		word	[cursor_pos_h],		0
	
	mov		bx,							msg_vga_prompt
	call	print_message_vga

	pop		bx
	;jmp		key_pressed_done
	ret

enter_pressed_doscom:
	mov		ax, 'M'
	call	debug_print_function_info_char

	push	ds
	mov		ax, 0x0000			;***************
	mov		ds, ax
		
	; flip bit to indicate line ready for DOS COM
	mov		ax,					[kb_flags]
	or		ax,					KBD_DOS_LINE_READY
	mov		[kb_flags],			ax

	pop		ds
	ret



