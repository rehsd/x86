; VARs
varstart:
	;*** first 1024 bytes ***
	ivt times 1024			db		?				; prevent writing in the same space as the IVT (using nop 0x90 for visibility in binary)

	;*** next 356 bytes ***
	kb_buffer times 64		dw      ?					; 128-word keyboard buffer
	;os_buffer times 64		dw      ?					; 128-word buffer for operating system keyboard input (i.e., commands)
	tile5e_backup times 25	dw		?					; 5x5, word per pixel for color = 25 words (even frame)
	tile5o_backup times 25	dw		?					; 5x5, word per pixel for color = 25 words (odd frame)

	;*** next 98 bytes ***
	mem_test_tmp			dw		?					; used for RAM testing
	ppi1_ccfg				db		?					; current config for PPI1
	ppi2_ccfg				db		?					; current config for PPI2
	spi_state_b				db		?					; track CS state for spi on via port b
	spi_state_a				db		?					; track CS state for spi on via port a

	dec_num					db		?
	dec_num100s				db		?
	dec_num10s				db		?
	dec_num1s				db		?

	kb_flags				dw		?					; track status of keyboard input
	kb_wptr					dw		?					; keyboard buffer write pointer
	kb_rptr					dw		?					; keyboard buffer read pointer
	
	;os_buffer_wptr			dw		?					; os keyboard input write pointer

	current_char			dw		?					; current char for VGA output
	cursor_pos_h			dw		?					; horizontal position (pixel #) of text cursor
	cursor_pos_v			dw		?					; vertical position (pixel #) of text cursor
	pixel_offset_h			dw		?
	pixel_offset_v			dw		?
	
	charPixelRowLoopCounter	dw		?					; row pos when processing a char
	charpix_line1			db		?
	charpix_line2			db		?
	charpix_line3			db		?
	charpix_line4			db		?
	charpix_line5			db		?
	charpix_line6			db		?
	charpix_line7			db		?
	sprite_inc				db		?
	vga_param_color			dw		?
	vga_rect_start_x		dw		?
	vga_rect_start_y		dw		?
	vga_rect_end_x			dw		?
	vga_rect_end_y			dw		?
	print_char_options		dw		?			;bit0=1=single frame only
	;50
	mouse_buttons			dw		?
	mouse_buttons_prev		dw		?
	mouse_pos_x				dw		?			; horizontal position (pixel #) of mouse pointer
	mouse_pos_y				dw		?			; vertical position (pixel #) of mouse pointer 
	mouse_pos_x_prev_e		dw		?
	mouse_pos_y_prev_e		dw		?
	mouse_pos_x_prev_o		dw		?
	mouse_pos_y_prev_o		dw		?
	mouse_flags				dw		?

		
	; disk drive info							; [index in identy drive data, in words]
	di_d0_num_cyl			dw		?			; [1] default number of cylinders for disk 0
	di_d0_num_heads			dw		?			; [3] default number of heads
	di_d0_bytes_sect		dw		?			; [5] default number of bytes per sector
	di_d0_sect_track		dw		?			; [56] default sectors per track
	di_d0_curr_num_cyl		dw		?			; [54] current number of cylinders
	di_d0_curr_num_heads	dw		?			; [55] current number of heads
	di_d0_curr_sect_track	dw		?			; [56] current sectors per track
	di_d0_curr_capacity_lo	dw		?			; [57] current capacity in sectors (LBAs) lsw
	di_d0_curr_capacity_hi	dw		?			; [58] current capacity in sectors (LBAs) msw
	di_d0_sectors_addressbl dd		?			; [60-61] total number of sectors addressable in LBA Mode
	di_d0_adj_num_cyl		dw		?			; adjusted number of cylinders
	di_d0_adj_num_heads		dw		?			; adjusted current number of heads
	di_d0_adj_sect_track	dw		?			; adjusted current sectors per track

	chs_adj					dw		?			; power of 2 adjustment if chs cyl > 1023

	flags_debug				dw		?			; temporary storage of flags register for debug printing
	keyboard_data			dw		?
	; line drawing temps
	temp_w					dw		?
	pointX					dw		? 
	pointY					dw		?

	AREA					dd		?					; store result of area calculation

	;98
	; ******************************************
	; Room for 58 more bytes in 'safe' space
	; ******************************************


	; !!! anything beyond 1536 (addr 0x0600) bytes will be overwritten when kernel is loaded at 0x0600!

	; disk drive
	drive_buffer times 256	dw		?			; buffer to hold the drive identification inf

varend:


