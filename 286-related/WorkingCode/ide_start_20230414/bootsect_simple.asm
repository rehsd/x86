jmp	start_ldr
start_ldr:
	mov		ah,		0x0a		; write character at current cursor position, no color specified
	mov		al,		'b'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		'o'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		'o'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		't'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		's'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		'e'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		'c'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		't'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		' '			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		'l'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		'o'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		'a'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		'd'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		'e'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		'd'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		'!'			; al=char to write
	int		0x10				; call interrupt 0x10
	hlt

	times   0x01f1-$+$$ db 0
	filename	db      "KERNEL  SYS",0,0			; for later... file that will be loaded next
	sign		dw      0xAA55