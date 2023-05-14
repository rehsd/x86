%ifndef MACROS_MAC 
    %define MACROS_MAC 
    
%macro  abs 1

        cmp %1, 0
        jge %%skip
        neg %1
        %%skip:

%endmacro

%macro  DrawRectangle 5

        push %5
        push %4
        push %3
        push %2
        push %1
        call vga_draw_rect

%endmacro


%endif

