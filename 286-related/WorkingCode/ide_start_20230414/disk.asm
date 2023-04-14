
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
	; reference: https://lateblt.tripod.com/atapi.htm

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

	;.loop_busy:
	;	mov		bp,	0xffff					; low word of counter
	;	mov		si,	0x000f					; high word of counter
	;	call	delay_configurable			; counts down from dword to zero
	;
	;	mov		al,		'b'
	;	call	print_char_spi
	;	in		al,		IDE_REG_STATUS
	;	call	print_char_binary_spi
	;	call	print_char_newline_spi
	;	test	al,		0b10000000			;If b7=1, busy, loop
	;	jne	.loop_busy
	;
	
	cli
	
	;mov	dx,		IDE_REG_STATUS
	;.loop_drdy:
	;	mov		al,		'd'
	;	call	print_char_spi
	;	call	delay
	;	in		al,		dx
	;	call	print_char_binary_spi
	;	call	print_char_newline_spi
	;	and		al,		0b01000000			;If b6=0, busy, loop
	;	je	.loop_drdy

	mov	al,		0xa0									;selects device 0 (primary) -- use 0x10 device 1 (secondary)
	out	IDE_REG_DRIVE_HEAD,		al

	mov	al,						0xec					;cmd:identify drive
	out	IDE_REG_COMMAND,		al

	call	print_char_newline_spi

	.loop_drq:
		mov	al,		'q'
		call	print_char_spi

		in	al,		IDE_REG_STATUS
		and	al,		0b00001000			;If b3=0, no data, loop and try again
		je	.loop_drq

	mov ax, 0x0000
	mov	es,	ax

	mov dx,		IDE_REG_DATA
	mov di,		drive_buffer
	mov cx,		128
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
	mov		ax,	[drive_buffer+108]
	mov		[di_d0_curr_num_cyl], ax	
	mov		ax,	[drive_buffer+110]
	mov		[di_d0_curr_num_heads], ax	
	mov		ax,	[drive_buffer+114]
	mov		[di_d0_curr_capacity_lo], ax	
	mov		ax,	[drive_buffer+116]
	mov		[di_d0_curr_capacity_hi], ax	
	mov		ax,	[drive_buffer+120]
	mov		[di_d0_sectors_addressbl], ax	
	mov		ax,	[drive_buffer+122]
	mov		[di_d0_sectors_addressbl+2], ax	


	call	print_buffer
	call	print_char_newline_spi
	call	print_char_newline_spi
	call	print_buffer_hex
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

	mov		bx,		msg_diskinfo_bytes_sect
	call	print_string_to_serial
	mov		ax,		[di_d0_bytes_sect]
	call	print_word_hex_spi
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

	push ax

	mov	al, 4
	out IDE_REG_COMMAND, al			; do a "software reset" on the bus
	xor ax, ax
	out IDE_REG_COMMAND, al			; reset the bus to normal operation
	in al, IDE_REG_STATUS			; it might take 4 tries for status bits to reset
	in al, IDE_REG_STATUS			; ie. do a 400ns delay
	in al, IDE_REG_STATUS
	in al, IDE_REG_STATUS
.rdylp:
	in al, IDE_REG_STATUS
	and al, 0xc0			; check BSY and RDY
	cmp al, 0x40			; want BSY clear and RDY set
	jne short .rdylp
	
.out:
	pop ax
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
	;   | | | | | | | | | |	`-----	sector number
	;   | | | | | | | | `---------  high order 2 bits of track/cylinder
	;   `------------------------  low order 8 bits of track/cyl number

	push dx
	push cx
	push ax
	push es
	push bp

	mov	 bp,	ax

	;test bx,	bx					; # of sectors < 0 is a "reset" request from software
	;js short	.reset				; jump if signed
	in al,		IDE_REG_STATUS		; get the current status
	test al,	0x88				; check the BSY and DRQ bits -- both must be clear
	je short	.ok
	.reset:
		call ide_reset_disk
		;test bx, bx			; bypass any read on a "reset" request
		;jns short .ok
		;xor bx, bx			; force zero flag on, carry clear
		;jmp short .out
	.ok:
		mov     al, 0xa0					;Drive 0, head 0
		;mov		al,		0xa0				;drive 0				; * to do used passed value
		;or		al,		dh					;add head info (bottom four bits)
		out     IDE_REG_DRIVE_HEAD,	al

		;mov     ax,		bp					;# sectors to read in al
		mov     al,		1					;# sectors to read in al
		out     IDE_REG_SECT_COUNT, al

		;mov     al,		cl					;sector to read
		mov     al,		1					;sector to read
		;and		al,		0b00111111
		out     IDE_REG_SECT_NUMBER, al

		;mov     al,		ch					;cylinder low
		mov     al,		0b00000110					;cylinder low
		out     IDE_REG_CYL_LOW,al

		;mov     al,		cl					;cylinder high - the rest of the cylinder 0
		mov     al,		0b00000000					;cylinder high - the rest of the cylinder 0
		;and		al,		0b11000000
		;shr		al,		6
		out     IDE_REG_CYL_HIGH, al

		mov     al,		0x20						;Read with retry.
		out     IDE_REG_COMMAND, al
	.still_going:
		in      al, IDE_REG_STATUS
	    test    al, 8						;this means the sector buffer requires servicing
	    jz      .still_going					;do not continue until the sector buffer is ready
	    mov		ax, 0x0000
	    mov		es, ax
	    mov     dx, IDE_REG_DATA				;Data port - data comes in and out of here.
	    mov     di, drive_buffer
	    mov     cx, 512/2						;One sector /2
		cld
	    rep     insw

	    call		print_buffer_hex
	.out:
		; TO DO return values!
		pop	bp
		pop es
		pop ax
		pop cx
		pop dx
		ret

print_buffer_hex:
	push	ax
	push	bx
	push	cx

	mov bx,		drive_buffer
	mov cx,		128

	.loop_print:
		mov		ax, [bx]
		xchg	ah, al
		call	print_char_hex_spi
		xchg	ah, al
		call	print_char_hex_spi
		add		bx, 2
		loop	.loop_print

	pop	cx
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

isr_int_13h:

ret