
; Base IO Address Selection // Default: 01 (A7..A6) = 0x0040 (using addresses 0x0040 to 0x007F 
; A7 = 0	(set with jumper)
; A6 = 1	(set with jumper)
; A5=DA2
; A4=DA1
; A3=DA0
; A2=CS3FX
; A1=CS1FX

; https://stanislavs.org/helppc/int_13.html
; https://wiki.osdev.org/ATA_PIO_Mode
; https://forum.osdev.org/viewtopic.php?t=12268

ide_identify_drive:
	; reference:	https://lateblt.tripod.com/atapi.htm
	;				https://www.farnell.com/datasheets/39782.pdf
	push	ax
	push	cx
	push	dx
	push	di
	push	bp
	push	si
	push	es

	mov		bp,	0xffff					; low word of counter
	mov		si,	0x000f					; high word of counter
	call	delay_configurable			; counts down from dword to zero	
	
	call	ide_reset_disk
	
	mov		bp,	0xffff					; low word of counter
	mov		si,	0x000f					; high word of counter
	call	delay_configurable			; counts down from dword to zero
	
	cli
	
	mov	al,		0xa0									;selects device 0 (primary) -- use 0x10 device 1 (secondary)
	out	IDE_REG_DRIVE_HEAD,		al

	mov	al,						0xec					;cmd:identify drive
	out	IDE_REG_COMMAND,		al

	call	print_char_newline_spi

	.loop_drq:
		mov		al,		'q'
		call	print_char_spi

		in	al,		IDE_REG_STATUS
		and	al,		0b00001000			;If b3=0, no data, loop and try again
		je	.loop_drq

	mov ax, 0x0000
	mov	es,	ax

	mov dx,		IDE_REG_DATA
	mov di,		drive_buffer
	mov cx,		128						;128 word reads
	cld									;clear the direction flag so INSW increments DI (not decrement it)
	rep			insw 
	
	sti

	mov	al,		's'
	call	print_char_spi
	
	mov		ax,	[drive_buffer+2]
	mov		[di_d0_num_cyl], ax	
	mov		ax,	[drive_buffer+6]
	mov		[di_d0_num_heads], ax	
	mov		ax,	[drive_buffer+10]
	mov		[di_d0_bytes_sect], ax	
	mov		ax, [drive_buffer+12]					; sectors per track (default)
	mov		[di_d0_sect_track], ax
	mov		ax,	[drive_buffer+108]					; cylinders (current)
	mov		[di_d0_curr_num_cyl], ax	
	mov		ax,	[drive_buffer+110]					; heads (current)
	mov		[di_d0_curr_num_heads], ax	
	mov		ax, [drive_buffer+112]					; sectors per track (current)
	mov		[di_d0_curr_sect_track], ax				
	mov		ax,	[drive_buffer+114]					; capacity in sectors -low
	mov		[di_d0_curr_capacity_lo], ax	
	mov		ax,	[drive_buffer+116]					; capacity in sectors -high
	mov		[di_d0_curr_capacity_hi], ax	
	mov		ax,	[drive_buffer+120]
	mov		[di_d0_sectors_addressbl], ax	
	mov		ax,	[drive_buffer+122]
	mov		[di_d0_sectors_addressbl+2], ax

	mov		ax,	[di_d0_curr_num_cyl]
	mov		[di_d0_adj_num_cyl], ax
	;and		word [di_d0_adj_num_cyl], 0b00000011_11111111		;space above 10-bit cyl not available (~512 MB limit)

	mov		ax, [di_d0_curr_num_heads]
	mov		[di_d0_adj_num_heads], ax

	mov		ax, [di_d0_curr_sect_track]		; ******* don't add one
	mov		[di_d0_adj_sect_track], ax


	
	call	print_buffer
	call	print_char_newline_spi
	call	print_char_newline_spi
	
	pop	es

	call	print_drive_info

	pop	si
	pop	bp
	pop	di
	pop	dx
	pop	cx
	pop	ax

	ret

print_drive_info:
	push	ax
	push	bx

	mov		bx,		msg_diskinfo_bytes_sect
	call	print_string_to_serial
	mov		ax,		[di_d0_bytes_sect]
	call	print_word_hex_spi
	call	print_char_newline_spi
	call	print_char_newline_spi

	mov		bx,		msg_diskinfo_num_cyl
	call	print_string_to_serial
	mov		ax,		[di_d0_num_cyl]
	call	print_word_hex_spi
	call	print_char_newline_spi

	mov		bx,		msg_diskinfo_num_heads
	call	print_string_to_serial
	mov		ax,		[di_d0_num_heads]
	call	print_word_hex_spi
	call	print_char_newline_spi

	mov		bx,		msg_diskinfo_sect_track
	call	print_string_to_serial
	mov		ax,		[di_d0_sect_track]
	call	print_word_hex_spi
	call	print_char_newline_spi
	call	print_char_newline_spi

	mov		bx,		msg_diskinfo_curr_num_cyl
	call	print_string_to_serial
	mov		ax,		[di_d0_curr_num_cyl]
	call	print_word_hex_spi
	call	print_char_newline_spi

	mov		bx,		msg_diskinfo_curr_num_heads
	call	print_string_to_serial
	mov		ax,		[di_d0_curr_num_heads]
	call	print_word_hex_spi
	call	print_char_newline_spi

	mov		bx,		msg_diskinfo_curr_sect_track
	call	print_string_to_serial
	mov		ax,		[di_d0_curr_sect_track]
	call	print_word_hex_spi
	call	print_char_newline_spi
	call	print_char_newline_spi

	mov		bx,		msg_diskinfo_curr_capacity_lo
	call	print_string_to_serial
	mov		ax,		[di_d0_curr_capacity_lo]
	call	print_word_hex_spi
	call	print_char_newline_spi

	mov		bx,		msg_diskinfo_curr_capacity_hi
	call	print_string_to_serial
	mov		ax,		[di_d0_curr_capacity_hi]
	call	print_word_hex_spi
	call	print_char_newline_spi

	mov		bx,		msg_diskinfo_sectors_addressbl
	call	print_string_to_serial
	mov		ax,		[di_d0_sectors_addressbl+2]
	call	print_word_hex_spi
	mov		ax,		[di_d0_sectors_addressbl]
	call	print_word_hex_spi
	call	print_char_newline_spi
	call	print_char_newline_spi

	mov		bx,		msg_diskinfo_adj_num_cyl
	call	print_string_to_serial
	mov		ax,		[di_d0_adj_num_cyl]
	call	print_word_hex_spi
	call	print_char_newline_spi

	mov		bx,		msg_diskinfo_adj_num_heads
	call	print_string_to_serial
	mov		ax,		[di_d0_adj_num_heads]
	call	print_word_hex_spi
	call	print_char_newline_spi

	mov		bx,		msg_diskinfo_adj_sect_track
	call	print_string_to_serial
	mov		ax,		[di_d0_adj_sect_track]
	call	print_word_hex_spi
	call	print_char_newline_spi
	pop		bx
	pop		ax
	ret

ide_reset_disk:
	; INT 13H
	; AH = 00
	; DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)
	; on return:
		; AH = disk operation status  (see INT 13,STATUS)
		; CF = 0 if successful
	    ; = 1 if error
	; - clears reset flag in controller and pulls heads to track 0
	; - setting the controller reset flag causes the disk to recalibrate
	;   on the next disk operation
	; - if bit 7 is set, the diskette drive indicated by the lower 7 bits
	;   will reset then the hard disk will follow; return code in AH is
	;   for the drive requested

	cmp		dl,		0x80			; drive 0
	jne		.out					; only drive is 0 (for now), if not drive 0, get out

	mov	al, 4
	out IDE_REG_COMMAND, al			; do a "software reset" on the bus
	xor ax, ax
	out IDE_REG_COMMAND, al			; reset the bus to normal operation
	in al, IDE_REG_STATUS			; it might take 4 tries for status bits to reset
	in al, IDE_REG_STATUS			; ie. do a 400ns delay
	in al, IDE_REG_STATUS
	in al, IDE_REG_STATUS
.rdylp:
	mov	al, '.'
	call	print_char_spi
	in al, IDE_REG_STATUS
	;call	print_char_binary_spi
	and al, 0xc0			; check BSY and RDY
	cmp al, 0x40			; want BSY clear and RDY set
	jne short .rdylp
	jmp short .out			; not needed, but for my clarity
.out:
	mov ax, 0x0000		;ah = 0
	clc
	ret

adjust_chs:
	;https://en.wikipedia.org/wiki/Logical_block_addressing
	push	ax

	;CH = track/cylinder number  (0-1023 dec., see below)
	;CL = sector number  (1-17 dec.)
	;  |F|E|D|C|B|A|9|8|7|6|5-0|  CX
	;   | | | | | | | | | |	`-----	sector number (cl 00xxxxxx)
	;   | | | | | | | | `---------  high order 2 bits of track/cylinder (cl xx000000)
	;   `------------------------  low order 8 bits of track/cyl number (ch)

	mov		ah,	cl
	and		ah, 0b11000000
	shr		ah, 6
	mov		al, ch
	;shr		ax, [chs_adj]		;or shr?


	pop		ax
	ret

ide_read:
	;AH = 02
	;AL = number of sectors to read	(1-128 dec.)
	;CH = track/cylinder number  (0-1023 dec., see below)
	;CL = sector number  (1-17 dec.)
	;DH = head number  (0-15 dec.)
	;DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)
	;ES:BX = pointer to buffer
	;	on return:
	;		AH = status  (see INT 13,STATUS)
	;		AL = number of sectors read
	;		CF = 0 if successful
	;	       = 1 if error
	;- BIOS disk reads should be retried at least three times and the
	;  controller should be reset upon error detection
	;- be sure ES:BX does not cross a 64K segment boundary or a
	;  DMA boundary error will occur
	;- many programming references list only floppy disk register values
	;- only the disk number is checked for validity
	;- the parameters in CX change depending on the number of cylinders;
	;  the track/cylinder number is a 10 bit value taken from the 2 high
	;  order bits of CL and the 8 bits in CH (low order 8 bits of track):
	;
	;  |F|E|D|C|B|A|9|8|7|6|5-0|  CX
	;   | | | | | | | | | |	`-----	sector number (cl 00xxxxxx)
	;   | | | | | | | | `---------  high order 2 bits of track/cylinder (cl xx000000)
	;   `------------------------  low order 8 bits of track/cyl number (ch)
	
	push dx
	push cx
	push si
	push di

	mov	 si,	ax
	and	 si,	0x00ff


	in al,		IDE_REG_STATUS		; get the current status
	test al,	0x88				; check the BSY and DRQ bits -- both must be clear
	je	.ok
	.reset:
		call ide_reset_disk
	.ok:
		mov     al,		dl					;0x80 for drive 0 C:					0x10000000
		or		al,		0x20				;should always be set					0x00100000
		and		dh,		0b00001111			;head should only be lower nibble
		or		al,		dh					;add head info (bottom four bits)	   +0x____????
		out     IDE_REG_DRIVE_HEAD,	al

		mov     ax,		si					;# sectors to read in al
		out     IDE_REG_SECT_COUNT, al

		mov     al,		cl					;sector to read (1-based)
		and		al,		0b00111111
		out     IDE_REG_SECT_NUMBER, al

		mov     al,		ch					;cylinder low
		out     IDE_REG_CYL_LOW,al

		mov     al,		cl					;cylinder high - the rest of the cylinder 0
		and		al,		0b11000000
		shr		al,		6
		out     IDE_REG_CYL_HIGH, al

		mov     al,		0x20						;Read with retry.
		out     IDE_REG_COMMAND, al
		
		.still_going:
			in      al, IDE_REG_STATUS
			test    al, 8						;this means the sector buffer requires servicing
			jz      .still_going					;do not continue until the sector buffer is ready

		mov     dx, IDE_REG_DATA				
		mov		di, bx							; es:bx is pointer to buffer, es:di is used by insw
		mov     cx, 0
		.adds:
			add	cx,	256
			dec	si
			jnz	.adds
		cld
		mov		ax,	cx
		rep     insw

	.out:
		;	AH = status  (see INT 13,STATUS)
		;	AL = number of sectors read
		;	CF = 0 if successful
		;	   = 1 if error
		;	ES:BX points one byte after the last byte read

		mov		bx,		di
		xchg	ah,		al				; ah has the number of sectors, put into al
		mov		ah,		0x0				; no error
		clc								;clear carry flag =  return status of success

		pop di
		pop	si
		pop cx
		pop dx

		ret

print_buffer_hex:
	; cx - # of words
	; ds:bx - buffer

	push	ax
	push	bx
	;push	cx

	.loop_print:
		mov		ax, [bx]
		xchg	ah, al
		call	print_char_hex_spi
		xchg	ah, al
		call	print_char_hex_spi
		add		bx, 2
		loop	.loop_print

	;pop	cx
	pop	bx
	pop ax
	ret

print_buffer:
	push	ax
	push	bx
	push	cx

	mov bx,		drive_buffer
	mov cx,		128

	.loop_print:
		mov		ax, [bx]
		xchg	ah, al
		call	print_char_spi
		xchg	ah, al
		call	print_char_spi
		add		bx, 2
		loop	.loop_print

	pop	cx
	pop	bx
	pop ax
	ret

print_dap:
	; DS:SI = pointer to disk address packet (DAP)
	; *DAP packet:	
	;	label		offset	|  size  |  description
	;	DAPACK		00h			1B		size of DAP, set to 0x10
	;				01h			1B		unused, set to 0x00
	;	BLKCNT		02h..03h	2B		number of sectors to be read
	;	DB_ADD		04h..07h	4B		destination buffer - complete buffer must fit in segment
	;	D_LBA		08h..0fh	8B		absolute number of the start of the sectors to be read

	push	ax

	call	print_char_newline_spi
	mov		al, 'd'
	call	print_char_spi
	mov		al, 'a'
	call	print_char_spi
	mov		al, 'p'
	call	print_char_spi
	mov		al, ':'
	call	print_char_spi
	
	mov	al, ds:[si+0]						;dap size
	call	print_char_hex_spi
	mov	al, ds:[si+1]						;unused - 0
	call	print_char_hex_spi
	mov		al, '-'
	call	print_char_spi
	mov	al, ds:[si+2]						;sector transfer count
	call	print_char_hex_spi
	mov	al, ds:[si+3]						;sector transfer count
	call	print_char_hex_spi
	mov		al, '-'
	call	print_char_spi
	mov	al, ds:[si+4]						;buffer
	call	print_char_hex_spi
	mov	al, ds:[si+5]						;buffer
	call	print_char_hex_spi
	mov	al, ds:[si+6]						;buffer
	call	print_char_hex_spi
	mov	al, ds:[si+7]						;buffer
	call	print_char_hex_spi
	mov		al, '-'
	call	print_char_spi
	mov	al, ds:[si+8]						;lba
	call	print_char_hex_spi
	mov	al, ds:[si+9]						;lba
	call	print_char_hex_spi
	mov	al, ds:[si+10]						;lba
	call	print_char_hex_spi
	mov	al, ds:[si+11]						;lba
	call	print_char_hex_spi

	call	print_char_newline_spi

	pop		ax
	ret

isr_int_13h:				; disk services ISR
	push bp					; to support getting updated flags register out correctly
	mov bp, sp				; to support getting updated flags register out correctly

	push	ax
	mov		al,	'1'
	call	print_char_spi
	mov		al,	'3'
	call	print_char_spi
	mov		al,	':'
	call	print_char_spi
	pop		ax
	xchg	ah, al
	call	print_char_hex_spi
	xchg	ah, al
	call	print_char_newline_spi
	call	debug_print_interrupt_info_sm
	call	print_char_newline_spi

	.reset_disk_system:					;0x00
		cmp		ah,		0x00
		jne		.read_disk_sectors
		
		;call	ide_reset_disk
		; AH = 00
		; DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)
		; on return:
			; AH = disk operation status  (see INT 13,STATUS)
			; CF = 0 if successful
			; = 1 if error
		; - clears reset flag in controller and pulls heads to track 0
		; - setting the controller reset flag causes the disk to recalibrate
		;   on the next disk operation
		; - if bit 7 is set, the diskette drive indicated by the lower 7 bits
		;   will reset then the hard disk will follow; return code in AH is
		;   for the drive requested

		cmp		dl,		0x80			; drive 0
		jne		.out					; only drive is 0 (for now), if not drive 0, get out

		mov	al, 4
		out IDE_REG_COMMAND, al			; do a "software reset" on the bus
		xor ax, ax
		out IDE_REG_COMMAND, al			; reset the bus to normal operation
		in al, IDE_REG_STATUS			; it might take 4 tries for status bits to reset
		in al, IDE_REG_STATUS			; ie. do a 400ns delay
		in al, IDE_REG_STATUS
		in al, IDE_REG_STATUS

		.rdylp:
			mov	al, '.'
			call	print_char_spi
			in al, IDE_REG_STATUS
			;call	print_char_binary_spi
			and al, 0xc0			; check BSY and RDY
			cmp al, 0x40			; want BSY clear and RDY set
			jne short .rdylp
			
		mov ax, 0x0000		;ah = 0
		clc
		jmp		.out
	.read_disk_sectors:					;0x02
		cmp		ah,		0x02			
		jne		.get_current_drive_params
		call	ide_read
		jmp		.out
	.get_current_drive_params:			;0x08
		cmp		ah,		0x08			
		jne		.read_dasd_type

		;DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)
		;on return:
		;	AH = status  (see INT 13,STATUS)
		;	BL = CMOS drive type
		;			01 - 5¬  360K	     03 - 3«  720K
		;			02 - 5¬  1.2Mb	     04 - 3« 1.44Mb
		;	CH = cylinders (0-1023 dec. see below)
		;	CL = sectors per track	(see below) - (1-based)
		;	DH = number of sides (0 based) [number of heads]
		;	DL = number of drives attached
		;	ES:DI = pointer to 11 byte Disk Base Table (DBT)
		;	CF = 0 if successful
		;		= 1 if error

		;|F|E|D|C|B|A|9|8|7|6|5|4|3|2|1|0|  CX
		;| | | | | | | | | | `------------  sectors per track
		;| | | | | | | | `------------	high order 2 bits of cylinder count
		;`------------------------  low order 8 bits of cylinder count

		cmp		dl,		0x80
		jne		.other08

		push	es
		mov		ax, 0x0
		mov		es, ax
		
		mov		cl,		es:[di_d0_adj_sect_track]			;sectors per track
		and		cl,		0b00111111						;out==>sectors per track, low 6 bits of cx
		mov		dx,		es:[di_d0_adj_num_cyl]			
		dec		dl
		mov		ch,		dl								;out==>cylinders, low 8 bits in ch
		and		dh,		0b00000011
		shl		dh,		6
		or		cl,		dh								;out==>cylinders, high 2 bits in cl
		mov		dh,		es:[di_d0_adj_num_heads]			;number heads
		dec		dh

		mov		ah,		0x0							;no error
		mov		bl,		0x0							;drive type
		mov		dl,		0x1								;number drives attached
		pop		es
		;es:di
		clc							;clear carry flag = success
		jmp		.out

		.other08:
			mov		ax, 0x0
			mov		dl, 0x0
			clc
			;stc							;set carry flag = error
			jmp		.out
	.read_dasd_type:					;0x15
		cmp		ah,		0x15
		jne		.disk_change_status

		;DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)
		;on return:
		;AH = 00 drive not present
		;   = 01 diskette, no change detection present
		;   = 02 diskette, change detection present
		;   = 03 fixed disk present
		;CX:DX = number of fixed disk sectors; if 3 is returned in AH
		;CF = 0 if successful
		;   = 1 if error

		.disk0:
			cmp		dl,		0x80
			jne		.other
			
			push	es
			mov		ax, 0x0
			mov		es, ax
			
			mov		ah,		0x03		;fixed disk present
			mov		cx,		es:[di_d0_curr_capacity_hi]
			mov		dx,		es:[di_d0_curr_capacity_lo]
			
			pop		es
			clc							;clear carry flag = success
			jmp		.out
		.other:
			mov		ah,		0x00
			clc							;clear carry flag = success
			;stc							;set carry flag = error (no floppy drive currently)
			jmp		.out
	.disk_change_status:				;0x16
		cmp		ah,		0x16			
		jne		.check_extns_present

		;DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)
		;on return:
		;	AH = 00 no disk change
		;		= 01 disk changed
		;	CF = set if disk has been removed or an error occurred

		mov	ah, 0x0
		clc

		jmp		.out
	.check_extns_present:				;0x41
		cmp		ah,		0x41
		jne		.ext_read_sectors
		; DL = drive index (0x80 for first disk)
		; BX = 0x55aa
		; Out:
		;	CF = Set on not present, clear if present
		;	AH = error code or major version number
		;	BX = 0xaa55
		;	CX = Interface support bitmask
		
		
		mov		ah, 0x0
		mov		bx, 0xaa55			;send 0xaa55 to indicate support for extended int13h
		mov		cx, 0x1				;Device Access using the packet structure

		clc		;clear carry flag
		
		jmp		.out
	.ext_read_sectors:					;0x42
		cmp		ah,		0x42
		jne		.ext_read_drive_params
		; https://en.wikipedia.org/wiki/INT_13H,	https://wiki.osdev.org/Disk_access_using_the_BIOS_(INT_13h), https://wiki.osdev.org/ATA_read/write_sectors	
		; DL = drive index (0x80 for first disk)
		; DS:SI = pointer to disk address packet (DAP)
		;	*DAP packet:	
		;		label		offset	|  size  |  description
		;		DAPACK		00h			1B		size of DAP, set to 0x10
		;					01h			1B		unused, set to 0x00
		;		BLKCNT		02h..03h	2B		number of sectors to be read
		;		DB_ADD		04h..07h	4B		destination buffer - complete buffer must fit in segment
		;		D_LBA		08h..0fh	8B		absolute number of the start of the sectors to be read
		; Out:
		; CF = set on error, clear if no error
		; AH = return code

		push	bx
		push	dx
		push	cx
		push	si
		push	di
		push	es

		;call	print_dap				;print dap for debugging purposes

		in al,		IDE_REG_STATUS		; get the current status
		test al,	0x88				; check the BSY and DRQ bits -- both must be clear
		je	.ok
		.reset:
			call ide_reset_disk
		.ok:

			mov		al,						ds:[si+BLKCNT]	; number of sectors to read
			out		IDE_REG_SECT_COUNT,		al

			mov		ax, 0
			mov		es, ax

			; lba
				mov		al, 'l'
				call	print_char_spi
				mov		al, 'b'
				call	print_char_spi
				mov		al, 'a'
				call	print_char_spi
				mov		al, ':'
				call	print_char_spi
				mov		al, [si+D_LBA+3]
				call	print_char_hex_spi
				mov		al, [si+D_LBA+2]
				call	print_char_hex_spi
				mov		al, [si+D_LBA+1]
				call	print_char_hex_spi
				mov		al, [si+D_LBA+0]
				call	print_char_hex_spi

			; **** cylinders ****		C = LBA ÷ (HPC × SPT)
				mov		al, ','
				call	print_char_spi
				mov		al, 'c'
				call	print_char_spi
				mov		al, ':'
				call	print_char_spi
				mov		dx,						[si+D_LBA+2]
				mov		ax,						[si+D_LBA+0]
				mov		cx,						es:[di_d0_adj_num_heads]
				call	safe_div											; result in dx:ax
				mov		cx,						es:[di_d0_adj_sect_track]
				call	safe_div											; result in dx:ax
				xchg	al,						ah
				out		IDE_REG_CYL_HIGH,		al
				call	print_char_hex_spi
				xchg	al,						ah
				out		IDE_REG_CYL_LOW,		al
				call	print_char_hex_spi

			; **** heads ****			H = (LBA ÷ SPT) mod HPC
				mov		al, ','
				call	print_char_spi
				mov		al, 'h'
				call	print_char_spi
				mov		al, ':'
				call	print_char_spi
				mov		dx,						[si+D_LBA+2]
				mov		ax,						[si+D_LBA+0]
				mov		cx,						es:[di_d0_adj_sect_track]
				call	safe_div											; result in dx:ax
				mov		cx,						es:[di_d0_adj_num_heads]
				call	safe_div											; remainder in bx
				mov		al,						bl
				out		IDE_REG_DRIVE_HEAD,		al
				call	print_char_hex_spi

			; **** sectors ****			S = (LBA mod SPT) + 1
				mov		al, ','
				call	print_char_spi
				mov		al, 's'
				call	print_char_spi
				mov		al, ':'
				call	print_char_spi
				mov		dx,						[si+D_LBA+2]
				mov		ax,						[si+D_LBA+0]
				mov		cx,						es:[di_d0_adj_sect_track]
				call	safe_div											; remainder in bx
				inc		bx
				mov		al,						bl
				out		IDE_REG_SECT_NUMBER,	al
				call	print_char_hex_spi
				call	print_char_newline_spi


			mov     al,						0x20				; Read with retry.
			out     IDE_REG_COMMAND,		al


		.still_going:
			in      al, IDE_REG_STATUS
			;call	print_char_hex_spi
			test    al, 8										; sector buffer requires servicing
			jz      .still_going								; do not continue until the sector buffer is ready

		mov		al, '>'
		call	print_char_spi

		mov     dx, IDE_REG_DATA				
		mov		word di, ds:[si+DB_ADD]						; es:di is used by insw
		mov		word es, ds:[si+DB_ADD+2]					; es:di is used by insw
		mov     cx, 0
		push	si
		mov		si,	[si+BLKCNT]								; number of sectors to read
		.adds:
			add	cx,	256
			dec	si
			jnz	.adds
		cld
		mov		ax,	cx
		rep     insw
		pop		si

		.ext_rs_out:
			mov		ax,		0x00								; return code
			clc													; clear carry = no error
			pop		es
			pop		di
			pop		si
			pop		cx
			pop		dx
			pop		bx

			jmp		.out
	.ext_read_drive_params:				;0x48
		cmp		ah,		0x48
		jne		.unimplemented
		
		;https://en.wikipedia.org/wiki/INT_13H
		;DL =  drive number (80h=drive 0, 81h=drive 1)
		;DS:SI = pointer to result buffer
		;	00h..01h	2 bytes	size of Result Buffer (set this to 1Eh)
		;	02h..03h	2 bytes	information flags
		;	04h..07h	4 bytes	physical number of cylinders = last index + 1
		;					(because index starts with 0)
		;	08h..0Bh	4 bytes	physical number of heads = last index + 1
		;					(because index starts with 0)
		;	0Ch..0Fh	4 bytes	physical number of sectors per track = last index
		;					(because index starts with 1)
		;	10h..17h	8 bytes	absolute number of sectors = last index + 1
		;					(because index starts with 0)
		;	18h..19h	2 bytes	bytes per sector
		;	1Ah..1Dh	4 bytes	optional pointer to Enhanced Disk Drive (EDD) configuration parameters 
		;					which may be used for subsequent interrupt 13h Extension calls (if supported)
		;Out:
		;	CF clear on no error, set on error
		;	AH return code

		push	es
		mov		ax, 0x0
		mov		es, ax

		mov		ax,						0x001e							;size of result buffer = 0x1e	
		mov		word ds:[si+0],			ax								
		mov		ax,						0x0000							;information flags
		mov		word ds:[si+2],			ax
		mov		ax,						0x00							;cyl msw  (only have a word of data from identify drive, not two bytes)
		mov		word ds:[si+4+2],		ax
		mov		ax,						es:[di_d0_adj_num_cyl]			;cyl lsw
		dec		ax														;!************************
		mov		word ds:[si+4+0],		ax
		
		mov		ax,						0x00								;heads msw (only have a word of data from identify drive, not two bytes)
		mov		word ds:[si+8+2],		ax
		
		mov		ax,						es:[di_d0_adj_num_heads]			;heads lsw
		mov		word ds:[si+8+0],		ax
		
		mov		ax,						0x00							;sectors/track msw  (only have a word of data from identify drive, not two bytes)
		mov		word ds:[si+12+2],		ax
		mov		ax,						es:[di_d0_adj_sect_track]			;sectors/track lsw
		mov		word ds:[si+12+0],		ax

		mov		ax,						0x00						;num sectors dd3  (only have a word of data from identify drive, not two bytes)
		mov		word ds:[si+16+6],		ax
		mov		ax,						0x00		;num sectors dd2  (only have a word of data from identify drive, not two bytes)
		mov		word ds:[si+16+4],		ax
		mov		ax,						es:[di_d0_curr_capacity_hi]		;num sectors dd1
		mov		word ds:[si+16+2],		ax
		mov		ax,						es:[di_d0_curr_capacity_lo]		;num sectors dd0
		mov		word ds:[si+16+0],		ax
		mov		ax,						es:[di_d0_bytes_sect]				;bytes per sector
		mov		word ds:[si+24],		ax
		;next four bytes are optional pointer to enhanced disk drive config -- not using

		pop		es

		mov		ax,		0x00			; return code
		clc								; clear carry = no error
		jmp		.out
	.unimplemented:
		call	lcd_clear
		mov		al, '!'
		call	print_char
		mov		al, '1'
		call	print_char
		mov		al, '3'
		call	print_char
		mov		al, '!'
		call	print_char
		call	debug_print_function_info_char
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
		hlt		; temporary
	.out:
		;pushf				;0			;push flags, just in case anything in .out modified flags
		;push	ax			;1
		;push	es			;2
		;push	0x00		;3
		;pop		es			;3
		;lahf
		;mov		es:[flags_debug],	ah
		;pop		es			;2
		;pop		ax			;1
		;push	ax			;1
		;call	print_char_newline_spi
		;call	debug_print_interrupt_info_sm
		;call	print_char_newline_spi
		;pop		ax			;1
		;popf				;0
		;nop
		;nop
		;nop
		;nop
		;nop
		;nop


		; *****************************
		;push bp		; at top
		;mov bp, sp		; at top

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

		;retf	2
		;iret
		