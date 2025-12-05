extern print_number
extern read_file
extern input_buffer

section .text
global _start

_start:
    mov rdi, filename
    call read_file
    mov r12, rax             ; r12 = file size

    ; Find width (position of first newline)
    mov rdi, input_buffer
    xor rcx, rcx
find_width:
    mov al, [rdi + rcx]
    cmp al, 10
    je found_width
    cmp al, 13
    je found_width
    inc rcx
    jmp find_width
found_width:
    mov r13, rcx             ; r13 = line width

    ; Calculate stride
    mov rdi, input_buffer
    add rdi, rcx
    mov al, [rdi]
    cmp al, 13
    jne not_crlf
    add rcx, 2
    jmp set_stride
not_crlf:
    inc rcx
set_stride:
    mov r14, rcx             ; r14 = stride

    ; Calculate height
    mov rax, r12
    xor rdx, rdx
    div r14
    mov r15, rax             ; r15 = height

    ; Total removed counter
    mov qword [total_removed], 0

removal_loop:
    ; Count accessible in this pass
    mov qword [pass_count], 0

    ; First pass: mark accessible rolls with 'x'
    mov rsi, 0               ; current row

mark_row_loop:
    cmp rsi, r15
    jge do_removal

    mov rdi, 0               ; current col

mark_col_loop:
    cmp rdi, r13
    jge mark_next_row

    ; Calculate position
    mov rax, rsi
    imul rax, r14
    add rax, rdi
    mov rcx, rax             ; rcx = position

    ; Check if this is a roll
    mov r8, input_buffer
    add r8, rcx
    mov al, [r8]
    cmp al, '@'
    jne mark_next_col

    ; Count neighbors
    xor r9, r9               ; neighbor count

    ; Top-left
    cmp rsi, 0
    je skip_mark_top
    cmp rdi, 0
    je skip_mark_topleft
    mov rax, rcx
    sub rax, r14
    dec rax
    mov r8, input_buffer
    add r8, rax
    mov al, [r8]
    cmp al, '@'
    je inc_mark_topleft
    cmp al, 'x'
    jne skip_mark_topleft
inc_mark_topleft:
    inc r9
skip_mark_topleft:

    ; Top
    cmp rsi, 0
    je skip_mark_top
    mov rax, rcx
    sub rax, r14
    mov r8, input_buffer
    add r8, rax
    mov al, [r8]
    cmp al, '@'
    je inc_mark_topmid
    cmp al, 'x'
    jne skip_mark_topmid
inc_mark_topmid:
    inc r9
skip_mark_topmid:

    ; Top-right
    cmp rsi, 0
    je skip_mark_top
    lea rax, [rdi + 1]
    cmp rax, r13
    jge skip_mark_top
    mov rax, rcx
    sub rax, r14
    inc rax
    mov r8, input_buffer
    add r8, rax
    mov al, [r8]
    cmp al, '@'
    je inc_mark_topright
    cmp al, 'x'
    jne skip_mark_top
inc_mark_topright:
    inc r9
skip_mark_top:

    ; Left
    cmp rdi, 0
    je skip_mark_left
    mov rax, rcx
    dec rax
    mov r8, input_buffer
    add r8, rax
    mov al, [r8]
    cmp al, '@'
    je inc_mark_left
    cmp al, 'x'
    jne skip_mark_left
inc_mark_left:
    inc r9
skip_mark_left:

    ; Right
    lea rax, [rdi + 1]
    cmp rax, r13
    jge skip_mark_right
    mov rax, rcx
    inc rax
    mov r8, input_buffer
    add r8, rax
    mov al, [r8]
    cmp al, '@'
    je inc_mark_right
    cmp al, 'x'
    jne skip_mark_right
inc_mark_right:
    inc r9
skip_mark_right:

    ; Bottom-left
    lea rax, [rsi + 1]
    cmp rax, r15
    jge skip_mark_bottom
    cmp rdi, 0
    je skip_mark_bottomleft
    mov rax, rcx
    add rax, r14
    dec rax
    mov r8, input_buffer
    add r8, rax
    mov al, [r8]
    cmp al, '@'
    je inc_mark_bottomleft
    cmp al, 'x'
    jne skip_mark_bottomleft
inc_mark_bottomleft:
    inc r9
skip_mark_bottomleft:

    ; Bottom
    lea rax, [rsi + 1]
    cmp rax, r15
    jge skip_mark_bottom
    mov rax, rcx
    add rax, r14
    mov r8, input_buffer
    add r8, rax
    mov al, [r8]
    cmp al, '@'
    je inc_mark_bottommid
    cmp al, 'x'
    jne skip_mark_bottommid
inc_mark_bottommid:
    inc r9
skip_mark_bottommid:

    ; Bottom-right
    lea rax, [rsi + 1]
    cmp rax, r15
    jge skip_mark_bottom
    lea rax, [rdi + 1]
    cmp rax, r13
    jge skip_mark_bottom
    mov rax, rcx
    add rax, r14
    inc rax
    mov r8, input_buffer
    add r8, rax
    mov al, [r8]
    cmp al, '@'
    je inc_mark_bottomright
    cmp al, 'x'
    jne skip_mark_bottom
inc_mark_bottomright:
    inc r9
skip_mark_bottom:

    ; Check if accessible (< 4 neighbors)
    cmp r9, 4
    jge mark_next_col

    ; Mark as 'x' for removal
    mov r8, input_buffer
    add r8, rcx
    mov byte [r8], 'x'
    inc qword [pass_count]

mark_next_col:
    inc rdi
    jmp mark_col_loop

mark_next_row:
    inc rsi
    jmp mark_row_loop

do_removal:
    ; Check if we removed anything
    mov rax, [pass_count]
    cmp rax, 0
    je done

    ; Add to total
    add [total_removed], rax

    ; Second pass: convert 'x' to '.'
    mov rsi, 0

remove_row_loop:
    cmp rsi, r15
    jge removal_loop        ; go back for another pass

    mov rdi, 0

remove_col_loop:
    cmp rdi, r13
    jge remove_next_row

    mov rax, rsi
    imul rax, r14
    add rax, rdi
    mov r8, input_buffer
    add r8, rax
    cmp byte [r8], 'x'
    jne remove_next_col
    mov byte [r8], '.'

remove_next_col:
    inc rdi
    jmp remove_col_loop

remove_next_row:
    inc rsi
    jmp remove_row_loop

done:
    mov rdi, [total_removed]
    call print_number

    mov rax, 60
    mov rdi, 0
    syscall

section .data
filename: db "../inputs/day4_input.txt", 0

section .bss
total_removed: resq 1
pass_count: resq 1
