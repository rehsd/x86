jmp	start_ldr
start_ldr:
	mov		ah,		0x0a		; write character at current cursor position, no color specified
	mov		al,		'k'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		'e'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		'r'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		'n'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		'e'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		'l'			; al=char to write
	int		0x10				; call interrupt 0x10
	mov		al,		'!'			; al=char to write
	int		0x10				; call interrupt 0x10
	hlt

	times   0x01f1-$+$$ db 0
	filename	db      "KERNEL  SYS",0,0			; for later... file that will be loaded next
	sign		dw      0xAA55