;BIOS Data Area (BDA) = 0000:0000 up to 0050:0030
;https://stanislavs.org/helppc/bios_data_area.html
; VARs
varstart:
	;*** first 1024 bytes ***
	ivt times 256				db		?					; 00:00 - prevent writing in the same space as the IVT
	drive_buffer times 512		db		?					; 10:00 - buffer to hold the drive identification info - only used during post... will get overwritten with upper interrupts (if used)
	resb 256-112											; 30:00 - #112 = see total at bottom of following section

		;up to 512 bytes
		;using
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
								;28

		flags_debug				dw		?			; temporary storage of flags register for debug printing
		keyboard_data			dw		?
		time					dd		?					; used to store current time (temporary)
		date					dd		?					; used to store current date (temporary)
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
								;30

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
		resb 1
								;20

		vga_param_color			dw		?
		vga_rect_start_x		dw		?
		vga_rect_start_y		dw		?
		vga_rect_end_x			dw		?
		vga_rect_end_y			dw		?
		print_char_options		dw		?			;bit0=1=single frame only
		mouse_buttons			dw		?
		mouse_buttons_prev		dw		?
		mouse_pos_x				dw		?			; horizontal position (pixel #) of mouse pointer
		mouse_pos_y				dw		?			; vertical position (pixel #) of mouse pointer 
		mouse_pos_x_prev_e		dw		?
		mouse_pos_y_prev_e		dw		?
		mouse_pos_x_prev_o		dw		?
		mouse_pos_y_prev_o		dw		?
		mouse_flags				dw		?
		AREA					dd		?					; store result of area calculation
								;34
								;===
								;28+30+20+34=112




	com_lpt times 8			dw		?					; 40:00 - com/lpt addresses
	equipment_list			dw		?					; 40:10 - equipment list flags (int 11h)
	resb 1												; 40:12 - infrared keyboard link error count
	memory_size				dw		?					; 40:13 - memory size in KB
	resb 1												; 40:15 - reserved
	resb 1												; 40:16 - PS/2 BIOS control flags
	keyboard_flags			dw		?					; 40:17 - keyboard flags
	resb 1												; 40:19 - Storage for alternate keypad entry
	kbd_buff_head			dw		?					; 40:1a - Offset from 40:00 to keyboard buffer head
	kbd_buff_tail			dw		?					; 40:1c - Offset from 40:00 to keyboard buffer tail
	kbd_buff times 32		db		?					; 40:1e - Keyboard buffer (circular queue buffer)
	resb 11												; 40:3e to 40:48 - floppy drive motor/status
	video_mode				db		?					; 40:49 - Current video mode
	screen_cols				dw		?					; 40:4a - Number of screen columns
	resb 27												; 40:4c to 40:66 - video/cursor info
	resb 5												; 40:67 to 40:6b - cs:ip for 286 return from protected, ...
	clock_counter			dd		?					; 40:6c - Daily timer counter
	clock_rollover			db		?					; 40:70 - clock rollover flag
	bios_break				db		?					; 40:71 - BIOS break flag
	soft_reset_flag			dw		?					; 40:72
	hdd_last_op_status		db		?					; 40:74 - Status of last hard disk operation (see INT 13,1)
	hdd_num_disks			db		?					; 40:75 - Number of hard disks attached
	resb 2												; 40:76 to 40:77 - XT fixed disk drive control byte, Port offset to current fixed disk adapter
	resb 8												; 40:78 to 40:7f - time-outs for lpt/com
	kbd_buff_start_offset	dw		?					; 40:80 - Keyboard buffer start offset (seg=40h,BIOS 10-27-82)
	kbd_buff_end_offset		dw		?					; 40:82 - Keyboard buffer end offset (seg=40h,BIOS 10-27-82)
	screen_rows				db		?					; 40:84 - Rows on the screen (less 1, EGA+)
	resb 2												; 40:85 to 40:86 - 
	video_mode_options		db		?					; 40:87 - video mode options
	resb 6												; 40:88 to 40:8d - 
	hdd_int_control			db		?					; 40:8e - Hard disk interrupt control flag(bit 7=working int)
	resb 7												; 40:8f to 40:95
	kbd_mode				db		?					; 40:96 - Keyboard mode/type
	kbd_led					db		?					; 40:97 - Keyboard LED flags
	resb 68												; 40:98 to 40:ff
	resb 64												; 50:00 to 3f - safety
	resb 128											; space for FreeDOS ??
	



	; ******* less critical... ****
	;kb_buffer times 64		dw      ?					; 128-word keyboard buffer
	;os_buffer times 64		dw      ?					; 128-word buffer for operating system keyboard input (i.e., commands)
	;tile5e_backup times 25	dw		?					; 5x5, word per pixel for color = 25 words (even frame)
	;tile5o_backup times 25	dw		?					; 5x5, word per pixel for color = 25 words (odd frame)

	; line drawing temps
	;temp_w					dw		?
	;pointX					dw		? 
	;pointY					dw		?


	; !!! anything beyond 1536 (addr 0x0600) bytes will be overwritten when kernel is loaded at 0x0600!

	; disk drive
	;drive_buffer times 256	dw		?			; buffer to hold the drive identification inf

	; 0x05e0 - drive info

	last_bss_var			db		?