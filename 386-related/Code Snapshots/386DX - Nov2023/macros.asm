%ifndef MACROS_MAC 
    %define MACROS_MAC 
    
%macro  abs 1

        cmp %1, 0
        jge %%skip
        neg %1
        %%skip:

%endmacro

%macro  DrawRectangle 5

        push word %5
        push word %4
        push word %3
        push word %2
        push word %1
        call vga_draw_rect

%endmacro

%macro  ds0000  0

    push    ds
    push	0x0000
	pop		ds

%endmacro

%macro  ds0000out   0
    pop     ds
%endmacro

%endif

