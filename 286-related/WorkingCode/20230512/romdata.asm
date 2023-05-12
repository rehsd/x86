charmap:							; ASCII 0x20 to 0x7F	Used in VGA character output
	%include "charmap.asm"

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

; strings			; terminate with 0x0
	msg_vga_post_version						db	'rehsd -- BIOS version 0.0000.000B -- 10 May 2023', 0x0
	msg_286at8									db	'80286 at 8 MHz!', 0x0
	msg_286at10									db	'80286 at 10 MHz!', 0x0
	msg_286at11									db	'80286 at 11 MHz!', 0x0
	msg_loading									db	'Loading...', 0x0
	msg_vga_test_header							db	'Dynamically-generated Test Pattern', 0x0
	msg_vga_test_red							db	'Red 0-31 (5 bits)', 0x0
	msg_vga_test_green							db	'Green 0-63 (6 bits)', 0x0
	msg_vga_test_blue							db	'Blue 0-31 (5 bits)', 0x0
	msg_vga_test_footer							db	'640x480x2B  RGB565  --  5x7 fixed width font', 0x0
	msg_spi_init								db	'SPI (and VIA) Init', 0x0a, 0x0
	msg_sdcard_init								db	'SD Card Init starting', 0x0a, 0x0
	msg_sdcard_try00							db	'SD Card Init: Sending cmd 00...', 0x0a, 0x0
	msg_sdcard_try00_done						db	'SD Card Init: cmd 00 success', 0x0a, 0x0
	msg_sdcard_init_out							db	'SD Card routine finished',0x0a, 0x0
	msg_sdcard_sendcommand						db	'SD Card Send Command: ', 0x0
	msg_sdcard_received							db	0x0a, 'Received: ', 0x0
	msg_sdcard_try08							db	'SD Card Init: Sending cmd 08...', 0x0a, 0x0
	msg_sdcard_try08_done						db	'SD Card Init: cmd 08 success', 0x0a, 0x0
	msg_garbage									db	'.', 0x0a, 0x0
	msg_sdcard_try55							db	'SD Card Init: Sending cmd 55...', 0x0a, 0x0
	msg_sdcard_try55_done						db	'SD Card Init: cmd 55 success', 0x0a, 0x0
	msg_sdcard_try41							db	'SD Card Init: Sending cmd 41...', 0x0a, 0x0
	msg_sdcard_try41_done						db	'SD Card Init: cmd 41 success.', 0x0a, '** SD Card initialization complete. Let the party begin! **', 0x0a, 0x0
	msg_sdcard_try18							db	'SD Card Init: Sending cmd 18...', 0x0a, 0x0
	msg_sdcard_try18_done						db	'SD Card Init: cmd 18 success', 0x0a, 0x0
	msg_sdcard_nodata							db	'SD Card - No data!', 0x0a, 0x0
	msg_sdcard_read_done						db  'SD Card - Finished reading data', 0x0a, 0x0
	msg_bios_update_complete					db	'BIOS update complete! Please reset the system.', 0x0
	msg_vga_prompt								db	'>>', 0x0
	msg_diskinfo_num_cyl						db	'Cylinders (default)        : 0x', 0x0
	msg_diskinfo_num_heads						db	'Heads (default)            : 0x', 0x0
	msg_diskinfo_sect_track						db	'Sectors / track            : 0x', 0x0
	msg_diskinfo_bytes_sect						db	'Bytes/sector (default)     : 0x', 0x0
	msg_diskinfo_curr_num_cyl					db	'Cylinders (current)        : 0x', 0x0
	msg_diskinfo_curr_num_heads					db  'Heads (current)            : 0x', 0x0
	msg_diskinfo_curr_sect_track				db	'Sectors / track (current)  : 0x', 0x0
	msg_diskinfo_adj_num_cyl					db	'Cylinders (adjusted)       : 0x', 0x0
	msg_diskinfo_adj_num_heads					db  'Heads (adjusted)           : 0x', 0x0
	msg_diskinfo_adj_sect_track					db	'Sectors / track (adjusted) : 0x', 0x0
	msg_diskinfo_curr_capacity_lo				db  'Capacity sectors lsw       : 0x', 0x0
	msg_diskinfo_curr_capacity_hi				db  'Capacity sectors msw       : 0x', 0x0
	msg_diskinfo_sectors_addressbl				db  'Addressable sectors LBA    : 0x', 0x0
	os_cmd_help									db  'help', 0x0
	os_cmd_ver									db	'ver', 0x0
	os_cmd_cls									db	'cls', 0x0
	os_cmd_update_bios							db	'updatebios', 0x0
	os_cmd_reboot								db	'reboot', 0x0
	os_cmd_rundoscomc							db	'rundoscomc', 0x0
	os_cmd_rundoscomcpp							db	'rundoscomcpp', 0x0
	os_cmd_rundoscommandcom						db	'command.com', 0x0
	os_cmd_win									db	'win', 0x0
	os_cmd_unrecognized							db	'Unrecognized Command', 0x0
	msg_cmd_help1								db  'Supported commands: cls, command.com, help, reboot, rundoscomc, rundoscomcpp, updatebios, ver, win', 0x0
	msg_cmd_help2								db  'ESC=Clear LCD | Shift-ESC=Clear VGA | F1=RTC refresh | F5=Black screen | F6=White screen', 0x0
	msg_cmd_help3								db  'F7=Test screen | F8=Shapes | F9=Image from SD Card | F12=Swap frame', 0x0
	msg_update_bios								db	'Updating BIOS. See status on system LCD. The system will automatically reset.', 0x0
	msg_xcp_diverr								db	'Division error', 0x0
	msg_xcp_overflow							db	'Oveflow', 0x0
	msg_xcp_invalidop							db	'Invalid OpCode', 0x0
	msg_xcp_multi								db	'Multiple xcps', 0x0
	msg_xcp_genprot								db	'Gen prot xcp', 0x0
	msg_dos_service								db	'DOS Service: ', 0x0

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

sprite_rehsd:
	dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0020,0x18E3,0x2124,0x2985,0x3186,0x31A6,0x31A6,0x3186,0x2965,0x2124,0x18C3,0x0841,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0841,0x2104,0x39E7,0x4248,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4248,0x39E7,0x2104,0x0841,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0841,0x2104,0x39E7,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x52AA,0x4A69,0x4A69,0x4A69,0x39E7,0x18E3,0x0861,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0841,0x2965,0x4A49,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x738E,0xD6BA,0x4A69,0x4A69,0x4A69,0x4A69,0x4A49,0x2965,0x0020,0x0000,0x0000,0x0000,0x0000,0x0000
	dw 0x0000,0x0000,0x0000,0x0000,0x1082,0x31A6,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x73AE,0xE73C,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x31A6,0x0861,0x0000,0x0000,0x0000,0x0000
	dw 0x0000,0x0000,0x0000,0x0841,0x31A6,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x73AE,0xE73C,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x31A6,0x0020,0x0000,0x0000,0x0000
	dw 0x0000,0x0000,0x0841,0x2985,0x4A69,0x4A69,0x52CA,0x528A,0x4A69,0x5ACB,0x528A,0x4A69,0x4A69,0x6B6D,0x7BEF,0x5ACB,0x4A69,0x4A69,0x73AE,0xE73C,0x528A,0x6B6D,0x73CE,0x528A,0x4A69,0x4A69,0x4A69,0x4A69,0x2965,0x0000,0x0000,0x0000
	dw 0x0000,0x0000,0x2104,0x4A49,0x4A69,0x4A69,0xC658,0x9492,0xBE17,0xEF9D,0x94B2,0x4A69,0xB5D6,0xF7DE,0xF7DE,0xE75C,0x630C,0x4A69,0x73AE,0xE75C,0xBDF7,0xF7DE,0xFFFF,0xBDF7,0x4A69,0x4A69,0x4A69,0x4A69,0x4248,0x18C3,0x0000,0x0000
	dw 0x0000,0x0841,0x39E7,0x4A69,0x4A69,0x4A69,0xCE59,0xEF7D,0xDEFB,0xB5D6,0x8410,0x8430,0xE75C,0x6B6D,0x52AA,0xBE17,0xBDF7,0x4A69,0x73AE,0xF7DE,0xD6BA,0x7BEF,0xA534,0xEF9D,0x630C,0x4A69,0x4A69,0x4A69,0x4A69,0x39E7,0x0841,0x0000
	dw 0x0000,0x2104,0x4A69,0x4A69,0x4A69,0x4A69,0xCE59,0xBDF7,0x4A89,0x4A69,0x4A69,0xC638,0x94B2,0x4A69,0x4A69,0x6B6D,0xEF7D,0x4A69,0x73AE,0xE75C,0x52AA,0x4A69,0x4A69,0xEF9D,0x738E,0x4A69,0x4A69,0x4A69,0x4A69,0x4A49,0x2124,0x0000
	dw 0x0020,0x39E7,0x4A69,0x4A69,0x4A69,0x4A69,0xCE59,0x8C71,0x4A69,0x4A69,0x528A,0xDF1B,0x8430,0x738E,0x738E,0x8410,0xF7BE,0x528A,0x73AE,0xE73C,0x4A69,0x4A69,0x4A69,0xDF1B,0x7BCF,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x39C7,0x1082
	dw 0x18E3,0x4248,0x4A69,0x4A69,0x4A69,0x4A69,0xCE59,0x8C71,0x4A69,0x4A69,0x52AA,0xEF7D,0xEF9D,0xEF9D,0xEF9D,0xEF9D,0xEF9D,0x52AA,0x73AE,0xE73C,0x4A69,0x4A69,0x4A69,0xDEFB,0x7BCF,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4228,0x1082
	dw 0x2124,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0xCE59,0x8C71,0x4A69,0x4A69,0x52AA,0xE75C,0x632C,0x528A,0x528A,0x528A,0x528A,0x4A69,0x73AE,0xE73C,0x4A69,0x4A69,0x4A69,0xDEFB,0x7BCF,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x18C3
	dw 0x2985,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0xCE59,0x8C71,0x4A69,0x4A69,0x4A89,0xDEFB,0x7C0F,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x73AE,0xE73C,0x4A69,0x632C,0x528A,0xDEFB,0x7BCF,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x2965
	dw 0x31A6,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0xCE59,0x8C71,0x4A69,0x4A69,0x4A69,0xB5D6,0xCE79,0x4A69,0x4A69,0x4A69,0x73AE,0x4A69,0x73AE,0xE73C,0x4A69,0xDF1B,0x6B6D,0xDEFB,0x7BCF,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x3186
	dw 0x31A6,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0xCE59,0x8C71,0x4A69,0x4A69,0x4A69,0x6B6D,0xF7BE,0xC658,0x9CF3,0xBE17,0xEF7D,0x4A69,0x73AE,0xE73C,0x4A69,0xE73C,0x6B8D,0xDEFB,0x7BCF,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x31A6
	dw 0x31A6,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0xAD95,0x7BEF,0x4A69,0x4A69,0x4A69,0x4A69,0x7BCF,0xDF1B,0xF7DE,0xDF1B,0x8C71,0x4A69,0x6B6D,0xC638,0x4A69,0xE73C,0x6B8D,0xBDF7,0x6B8D,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x31A6
	dw 0x3186,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x6B4D,0x94D2,0x8C71,0x5B0B,0x4A69,0x4A69,0x4A69,0x7BEF,0x9CF3,0x73AE,0xE73C,0x6B8D,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x3186
	dw 0x2965,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x7BCF,0xF7BE,0xEF9D,0xF7DE,0xEF9D,0x528A,0x4A69,0x94B2,0xF7DE,0xF7DE,0xF7DE,0xF7DE,0x6B8D,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x2965
	dw 0x2124,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0xD6BA,0xA554,0x4A69,0x5AEB,0xBDD7,0x528A,0x52AA,0xEF7D,0x9CF3,0x4A69,0x6B6D,0xEF9D,0x6B8D,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x18C3
	dw 0x18C3,0x4248,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0xEF9D,0x7BCF,0x4A69,0x4A69,0x4A69,0x4A69,0x8410,0xDF1B,0x4A89,0x4A69,0x4A69,0xE73C,0x6B8D,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4228,0x1082
	dw 0x0841,0x39E7,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0xD6BA,0xD69A,0x6B8D,0x52AA,0x4A69,0x4A69,0xA534,0xBE17,0x4A69,0x4A69,0x4A69,0xE73C,0x6B8D,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x31C6,0x0000
	dw 0x0000,0x2104,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x7BCF,0xEF9D,0xF7DE,0xE73C,0x8C51,0x4A69,0xB596,0xB5B6,0x4A69,0x4A69,0x4A69,0xE73C,0x6B8D,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A49,0x2104,0x0000
	dw 0x0000,0x0020,0x39E7,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x5ACB,0x94D2,0xD6DA,0xF7BE,0x5AEB,0xAD75,0xBDF7,0x4A69,0x4A69,0x4A69,0xE73C,0x6B8D,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x39E7,0x0020,0x0000
	dw 0x0000,0x0000,0x18E3,0x4A49,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x52CA,0xEF9D,0x73CE,0x9CD3,0xCE79,0x4A69,0x4A69,0x4A69,0xE73C,0x6B8D,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4248,0x18C3,0x0000,0x0000
	dw 0x0000,0x0000,0x0861,0x2965,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A89,0x9CF3,0x4A89,0x4A69,0x5ACB,0xEF9D,0x6B8D,0x73AE,0xEF7D,0x5B0B,0x4A69,0x73AE,0xF7BE,0x6B8D,0x4A69,0x4A69,0x4A69,0x4A69,0x4A49,0x2965,0x0000,0x0000,0x0000
	dw 0x0000,0x0000,0x0000,0x0020,0x31A6,0x4A69,0x4A69,0x4A69,0x4A69,0x4A89,0xF7BE,0xDEFB,0xB5D6,0xD6DA,0xD6DA,0x4A69,0x4A69,0xDEFB,0xE75C,0xD6BA,0xEF9D,0xF7BE,0x6B8D,0x4A69,0x4A69,0x4A69,0x4A69,0x3186,0x0020,0x0000,0x0000,0x0000
	dw 0x0000,0x0000,0x0000,0x0000,0x0861,0x31A6,0x4A69,0x4A69,0x4A69,0x4A69,0x73CE,0xC658,0xDF1B,0xBDF7,0x5ACB,0x4A69,0x4A69,0x6B4D,0xD6BA,0xD6DA,0x73AE,0xAD55,0x630C,0x4A69,0x4A69,0x4A49,0x3186,0x0861,0x0000,0x0000,0x0000,0x0000
	dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0020,0x2965,0x4248,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4248,0x2965,0x0020,0x0000,0x0000,0x0000,0x0000,0x0000
	dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x18C3,0x39E7,0x4A49,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A49,0x39E7,0x18C3,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0841,0x2104,0x39C7,0x4228,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4A69,0x4228,0x31C6,0x2104,0x0020,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000
	dw 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x1082,0x18C3,0x2965,0x3186,0x31A6,0x31A6,0x3186,0x2965,0x18C3,0x1082,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000

