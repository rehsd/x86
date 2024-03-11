isr_int_16h:			;Keyboard BIOS Services	
	push	bp		
	mov		bp, sp
	
	;push	ax
	;mov		al,	0x16
	;call	print_char_hex_spi
	;mov		al, ':'
	;call	print_char_spi
	;pop		ax
	;call	debug_print_interrupt_info_sm
	;call	print_char_newline_spi
	
	.wait_for_keystroke:				;0x00
		cmp		ah,		0x00
		jne		.get_keystroke_status
		
		;on return:
		;AH = keyboard scan code
		;AL = ASCII character or zero if special function key
		
		ds0000
		push	bx
		push	di
		push	si

		;call	debug_keyboard_buffer

		.wait:
			mov		di,	[kbd_buff_tail]
			mov		ax,	[0x400+di]				; get the char
			mov		si,	[kbd_buff_head]
			cmp		ax,	[0x400+si]
			je		.wait

		; if 0x08 (backspace), move cursor left two chars and type a space
		cmp		al,		0x08
		jne		.notback
		call	vga_clear_cursor
		call	backspace_erase
		.notback:

		cmp		al,		0x0d
		jne		.notCR
		call	vga_clear_cursor
		mov		byte [cursor_start_scan_line], 0
		.notCR:
		cmp		al,		0x0a
		jne		.notLF
		call	vga_clear_cursor
		mov		byte [cursor_start_scan_line], 0
		.notLF:

		;sti
		add		word [kbd_buff_tail],	2
		mov		bx,						[kbd_buff_end_offset]
		cmp		word bx,				[kbd_buff_tail]
		jge		.noloop
			push	word [kbd_buff_start_offset]
			pop		word [kbd_buff_tail]
		.noloop:
		
		;call	debug_keyboard_buffer
		;call	debug_print_interrupt_info_sm
		;call	print_char_newline_spi

		pop		si
		pop		di
		pop		bx
		ds0000out
		jmp		.out
	.get_keystroke_status:				;0x01
		cmp		ah,		0x01
		jne		.get_shift_status
		
		;on return:
		;	ZF = 0 if a key pressed (even Ctrl-Break)
		;	AX = 0 if no scan code is available
		;	AH = scan code
		;	AL = ASCII character or zero if special function key

		ds0000
		push	di

		mov		di,	[kbd_buff_tail]
		mov		ax,	[0x400+di]
		mov		di,	[kbd_buff_head]
		cmp		ax,	[0x400+di]
		pop		di
		je		.nothing_toprocess
		

		;sti
		;call	print_text_output_buffer
		
		ds0000out
		or		ax,		ax						; clear zero flag
		jmp		.out

		.nothing_toprocess:
			;sti
			call	print_text_output_buffer
			call	vga_draw_cursor
			
			ds0000out
			mov		ax, 0
			cmp		ax, ax							; set zero flag   (0x40)
			jmp		.out
	.get_shift_status:					;0x02
		cmp		ah,		0x02
		jne		.unsupported
		ds0000
		mov		al,	[keyboard_flags]
		ds0000out
		jmp		.out
	.unsupported:
		mov		al, 0x16
		call	missing_interrupt_tospi
		; fall through
	.out:

		; **** debug int out **********
		;pushf	;push flags, just in case anything in .out modified flags
		;push	ax
		;push	es
		;push	0x00
		;pop		es
		;lahf
		;mov		es:[flags_debug],	ah
		;pop		es
		;pop		ax

		;push	ax
		;mov		al, ' '
		;call	print_char_spi
		;mov		al, ' '
		;call	print_char_spi
		;mov		al, ' '
		;call	print_char_spi
		;call	debug_print_interrupt_info_sm
		;call	print_char_newline_spi
		;pop		ax

		;popf
		; *** /debug int out **********
		
		push ax			; update flags in stack frame for proper return
		lahf
		; bp + 0 = saved bp
		; bp + 2 = ip
		; bp + 4 = cs
		; bp + 6 = fl
		mov byte [bp + 6], ah
		pop ax

		pop bp
		iret
		; *****************************

debug_keyboard_buffer:
	push	ds
	push	ax
	push	di
	call	to0000ds

	mov		di,		0
	.loop:
		mov		ax,		[kbd_buff+di]
		call	debug_print_word_hex
		mov		al,		' '
		call	print_char_spi
		add		di,		2
		cmp		di,		32
		jne		.loop

	mov		al,	' '
	call	print_char_spi
	mov		al,	' '
	call	print_char_spi
	mov		al,	' '
	call	print_char_spi
	mov		al,	'b'
	call	print_char_spi
	mov		al,	':'
	call	print_char_spi
	mov		ax,	kbd_buff
	call	debug_print_word_hex
	mov		al,	' '
	call	print_char_spi
	mov		al,	' '
	call	print_char_spi
	mov		al,	' '
	call	print_char_spi
	mov		al,	't'
	call	print_char_spi
	mov		al,	':'
	call	print_char_spi
	mov		ax,	[kbd_buff_tail]
	call	debug_print_word_hex
	mov		al,	' '
	call	print_char_spi
	mov		al,	'h'
	call	print_char_spi
	mov		al,	':'
	call	print_char_spi
	mov		ax,	[kbd_buff_head]
	call	debug_print_word_hex
	call	print_char_newline_spi

	pop		di
	pop		ax
	pop		ds
	ret

keyboard_init:
	push		ds
	call		to0000ds
	mov	word	[kb_flags],		0x0000
	mov word	[kb_wptr],		0x0000
	mov word	[kb_rptr],		0x0000
	;call		clear_os_buffer		
	pop			ds
	ret

;mouse_init:
;	mov		word [mouse_flags],	0			; mouse cursor not visible. use MOUSE_CUROSOR_VISIBLE to make visible.
;	ret

;mouse_isr:		; mouse movement isr
;	pusha
;	push	ds
;	call	to0000ds
;
;	test	word [mouse_flags],	MOUSE_CURSOR_VISIBLE
;	je		.out
;
;	;mov		ax, [mouse_buttons]
;	;mov		[mouse_buttons_prev],	ax
;	call	spi_getKeyboardMouseData
;	call	draw_mouse_pointer
;
;	;cmp		word [INT34H_IVT_OFFSET],	0x0
;	;je		.no_userdef_isr
;	
;		;mov		ax, [mouse_buttons]
;		;cmp		[mouse_buttons_prev], ax
;		;je		.no_userdef_isr
;		;sti
;	
;		;;mov		dx,		[mouse_buttons]
;		;push	es
;		;push	ds
;		;mov		ax,	0x2000
;		;mov		ds, ax
;		;int		0x32		; c++ doesn't return out of isr properly
;		;cli
;		;pop		ds
;	
;	;.no_userdef_isr:
;
;	mov		al,			0x20		; EOI byte for OCW2 (always 0x20)
;	out		PICM_P0,	al			; to port for OCW2
;
;	.out:
;		pop		ds
;		popa
;		iret

mouse_services_isr:		; INT 33H
	; AX = 01	Show mouse cursor
	; AX = 02	Hide mouse cursor

	;call	debug_print_interrupt_info

	push	ds
	push	es

	call	to0000ds

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
	ds0000
	push	ax
	push	di
	push	bx

	call	spi_getKeyboardMouseData		; places keyboard info result in [keyboard_data]

	;adjust data from Nano to BIOS scan code + ASCII format. See https://stanislavs.org/helppc/scan_codes.html.
	;could update the Nano to directly send these expected values

	mov		ax, [keyboard_data]
	;call	lcd_clear
	;call	print_word_hex
	call	print_char_spi				; temporary until FreeDOS is handling keyboard input
	
	.enter:
		cmp		ax,		0x011e		; enter
		jne		.backspace
		mov		ax,		0x000d
		jmp		.cont
	.backspace:
		cmp		ax,		0x011c		; backspace
		jne		.ctrl_c
		mov		ax,		0x0008
		jmp		.cont
	.ctrl_c:
		cmp		ax,		0x2043		; ctrl-c
		jne		.cont
		mov		ax,		0x2e03
		jmp		.cont
	.cont:

	mov		bx,						[kbd_buff_head]
	mov		[0x400+bx],				ax							; place char value in circular buffer
	add		word [kbd_buff_head],	2							; increment head (write) pointer
	
	mov		ax,						[kbd_buff_end_offset]
	cmp		ax,						[kbd_buff_head]
	jge		.noloop
		mov		ax,					[kbd_buff_start_offset]
		mov		[kbd_buff_head],	ax
	.noloop:

	;call	debug_keyboard_buffer

	mov		al,			0x20		; EOI byte for OCW2 (always 0x20)
	out		PICM_P0,	al			; to port for OCW2

	pop		bx
	pop		di
	pop		ax
	ds0000out
	iret

;draw_mouse_pointer:
;	; just using a filled circle for now
;	push	dx
;	push	di
;	push	bx
;	push	ax
;	push	es
;	push	ds
;
;	call	to0000ds
;
;	in		ax,			VGA_REG
;	
;	mov		dx, 0xa000		; video memory window
;	mov		es, dx
;
;	test	ax,			0b0000_0000_0001_0000
;	je		.odd
;
;	.even:
;		;mov	ax,	'e'
;		;call	print_char
;
;		; restore previous screen data
;			mov		ax,				[mouse_flags]
;			test	ax,				CURSOR_INITIALIZED_EVEN
;			je		.backup_e									; if first cursor draw, nothing to restore
;
;			mov	di, 0x0000
;			mov	si, 0x0000
;			mov		cx,	[mouse_pos_x_prev_e]
;			mov		dx,	[mouse_pos_y_prev_e]
;			sub		cx, 2
;			sub		dx, 2
;
;			.row_e_r:			; even restore
;
;				; get old pixel color
;				mov		word ax,	[tile5e_backup+si]		
;
;				; params for vga_draw_pixel to be pushed onto stack
;				push	cx					; pixel x
;				push	dx					; pixel y
;				push	ax					; pixel color
;				call	vga_draw_pixel		; 
;			
;				add		di,		2
;				add		si,		2
;				inc		cx
;				cmp		di,		10
;				jne		.row_e_r
;				
;				mov		cx,		[mouse_pos_x_prev_e]
;				sub		cx,		2
;				mov		di,		0
;				inc		dx
;				cmp		si,		50
;				jne		.row_e_r
;		; backup screen data where mouse pointer will be drawn - 
;		.backup_e:
;			mov		ax,				[mouse_flags]
;			or		ax,				CURSOR_INITIALIZED_EVEN		; set flag
;			mov		[mouse_flags],	ax
;			mov	di, 0x0000
;			mov	si, 0x0000
;			mov		cx,	[mouse_pos_x]
;			mov		dx,	[mouse_pos_y]
;			sub		cx, 2
;			sub		dx, 2
;
;			.row_e_s:			; even save
;				; params for vga_read_pixel to be pushed onto stack
;				push	cx					; pixel x
;				push	dx					; pixel y
;				call	vga_read_pixel		; 
;				; save pixel color
;				mov		word [tile5e_backup+si],	ax
;			
;				add		di,		2
;				add		si,		2
;				inc		cx
;				cmp		di,		10
;				jne		.row_e_s
;				
;				mov		cx,		[mouse_pos_x]
;				sub		cx,		2
;				mov		di,		0
;				inc		dx
;				cmp		si,		50
;				jne		.row_e_s			
;		; save latest location as prev location so that it can be erased next time
;		mov		ax, [mouse_pos_x]
;		mov		[mouse_pos_x_prev_e], ax
;		mov		ax, [mouse_pos_y]
;		mov		[mouse_pos_y_prev_e], ax
;		jmp		.out	
;		
;	.odd:
;		;mov	ax,	'o'
;		;call	print_char
;
;		; restore previous screen data
;			mov		ax,				[mouse_flags]
;			test	ax,				CURSOR_INITIALIZED_ODD
;			je		.backup_o									; if first cursor draw, nothing to restore
;
;			mov	di, 0x0000
;			mov	si, 0x0000
;			mov		cx,	[mouse_pos_x_prev_o]
;			mov		dx,	[mouse_pos_y_prev_o]
;			sub		cx, 2
;			sub		dx, 2
;
;			.row_o_r:			; odd restore
;				
;				; get old pixel color
;				mov		word ax,	[tile5o_backup+si]		
;
;				; params for vga_draw_pixel to be pushed onto stack
;				push	cx					; pixel x
;				push	dx					; pixel y
;				push	ax					; pixel color
;				call	vga_draw_pixel		; 
;			
;				add		di,		2
;				add		si,		2
;				inc		cx
;				cmp		di,		10
;				jne		.row_o_r
;				
;				mov		cx,		[mouse_pos_x_prev_o]
;				sub		cx,		2
;				mov		di,		0
;				inc		dx
;				cmp		si,		50
;				jne		.row_o_r
;		; backup screen data where mouse pointer will be drawn - 
;		.backup_o:
;			mov		ax,				[mouse_flags]
;			or		ax,				CURSOR_INITIALIZED_ODD		; set flag
;			mov		[mouse_flags],	ax
;			mov	di, 0x0000
;			mov	si, 0x0000
;			mov		cx,	[mouse_pos_x]
;			mov		dx,	[mouse_pos_y]
;			sub		cx, 2
;			sub		dx, 2
;
;			.row_o_s:			; odd save
;				; params for vga_read_pixel to be pushed onto stack
;				push	cx					; pixel x
;				push	dx					; pixel y
;				call	vga_read_pixel		; 
;				; save pixel color
;				mov		word [tile5o_backup+si],	ax
;			
;				add		di,		2
;				add		si,		2
;				inc		cx
;				cmp		di,		10
;				jne		.row_o_s
;				
;				mov		cx,		[mouse_pos_x]
;				sub		cx,		2
;				mov		di,		0
;				inc		dx
;				cmp		si,		50
;				jne		.row_o_s			
;		; save latest location as prev location so that it can be erased next time
;		mov		ax, [mouse_pos_x]
;		mov		[mouse_pos_x_prev_o], ax
;		mov		ax, [mouse_pos_y]
;		mov		[mouse_pos_y_prev_o], ax
;		jmp		.out		
;	
;	.out:
;		; draw on new frame
;		mov		dx, [mouse_pos_x]
;		mov		di, [mouse_pos_y]
;		mov		bx, 2
;		mov		ax,	0xffff
;		call	vga_draw_circle_filled
;		call	vga_swap_frame
;		
;		pop		ds
;		pop		es
;		pop		ax
;		pop		bx
;		pop		di
;		pop		dx
;		ret

keyboard_inc_wptr:
	push		ds
	call		to0000ds
	push		ax

	mov			ax,				[kb_wptr]
	cmp			ax,				120					; buffer is 64 words, so 128 max here
	jne			.inc
	mov			word [kb_wptr],	0
	jmp			.out

	.inc:
		add	word [kb_wptr],	2
	.out:
		pop		ax
		pop		ds
		ret

keyboard_inc_rptr:
	push		ds
	call		to0000ds
	push		ax
	mov			ax,				[kb_rptr]
	cmp			ax,				120					; buffer is 64 words, so 128 max here
	jne			.inc
	mov		word	[kb_rptr],		0
	jmp			.out

	.inc:
		add word	[kb_rptr],	2
	.out:
		pop		ax
		pop		ds
		ret

;adjust_char:
;	; ax in (from Nano) - high byte describes char (shift, control, ...), low byte is ascii value (for ascii values)
;	ret

enter_pressed:
	ds0000
	push	bx
	;call	process_os_command

	;call	lcd_line2

	; mov		ah,							0x01			; spi cmd 1 - print char
	; call	spi_send_NanoSerialCmd

	add		word	[cursor_pos_v],		9
	mov		word	[cursor_pos_h],		0
	
	mov		bx,							msg_vga_prompt
	call	print_message_vga

	pop		bx
	ds0000out
	ret

