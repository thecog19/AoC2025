extern print_number
extern read_file
extern input_buffer

section .text
global _start

_start:
    mov rdi, filename
    call read_file
    mov r12, rax             ; r12 = file size

    ; Find width (position of first newline + 1 for stride)
    mov rdi, input_buffer
    xor rcx, rcx
find_width:
    mov al, [rdi + rcx]
    cmp al, 10               ; newline?
    je found_width
    cmp al, 13               ; carriage return?
    je found_width
    inc rcx
    jmp find_width
found_width:
    mov r13, rcx             ; r13 = line width (without newline)

    ; Calculate stride (width + newline chars)
    mov rdi, input_buffer
    add rdi, rcx
    mov al, [rdi]
    cmp al, 13               ; CRLF?
    jne not_crlf
    add rcx, 2               ; stride includes CR+LF
    jmp set_stride
not_crlf:
    inc rcx                  ; stride includes just LF
set_stride:
    mov r14, rcx             ; r14 = stride

    ; Calculate height
    mov rax, r12
    xor rdx, rdx
    div r14
    mov r15, rax             ; r15 = height

    ; Count accessible rolls
    mov rbx, 0               ; accessible count
    mov rsi, 0               ; current row

row_loop:
    cmp rsi, r15
    jge done

    mov rdi, 0               ; current col

col_loop:
    cmp rdi, r13
    jge next_row

    ; Calculate position in buffer
    mov rax, rsi
    imul rax, r14
    add rax, rdi
    mov rcx, rax             ; rcx = position

    ; Check if this is a roll (@)
    mov r8, input_buffer
    add r8, rcx
    mov al, [r8]
    cmp al, '@'
    jne next_col

    ; Count neighbors
    xor r9, r9               ; neighbor count

    ; Check all 8 directions
    ; Top-left (row-1, col-1)
    cmp rsi, 0
    je skip_top
    cmp rdi, 0
    je skip_topleft
    mov rax, rcx
    sub rax, r14
    dec rax
    mov r8, input_buffer
    add r8, rax
    cmp byte [r8], '@'
    jne skip_topleft
    inc r9
skip_topleft:

    ; Top (row-1, col)
    cmp rsi, 0
    je skip_top
    mov rax, rcx
    sub rax, r14
    mov r8, input_buffer
    add r8, rax
    cmp byte [r8], '@'
    jne skip_topmid
    inc r9
skip_topmid:

    ; Top-right (row-1, col+1)
    cmp rsi, 0
    je skip_top
    lea rax, [rdi + 1]
    cmp rax, r13
    jge skip_top
    mov rax, rcx
    sub rax, r14
    inc rax
    mov r8, input_buffer
    add r8, rax
    cmp byte [r8], '@'
    jne skip_top
    inc r9
skip_top:

    ; Left (row, col-1)
    cmp rdi, 0
    je skip_left
    mov rax, rcx
    dec rax
    mov r8, input_buffer
    add r8, rax
    cmp byte [r8], '@'
    jne skip_left
    inc r9
skip_left:

    ; Right (row, col+1)
    lea rax, [rdi + 1]
    cmp rax, r13
    jge skip_right
    mov rax, rcx
    inc rax
    mov r8, input_buffer
    add r8, rax
    cmp byte [r8], '@'
    jne skip_right
    inc r9
skip_right:

    ; Bottom-left (row+1, col-1)
    lea rax, [rsi + 1]
    cmp rax, r15
    jge skip_bottom
    cmp rdi, 0
    je skip_bottomleft
    mov rax, rcx
    add rax, r14
    dec rax
    mov r8, input_buffer
    add r8, rax
    cmp byte [r8], '@'
    jne skip_bottomleft
    inc r9
skip_bottomleft:

    ; Bottom (row+1, col)
    lea rax, [rsi + 1]
    cmp rax, r15
    jge skip_bottom
    mov rax, rcx
    add rax, r14
    mov r8, input_buffer
    add r8, rax
    cmp byte [r8], '@'
    jne skip_bottommid
    inc r9
skip_bottommid:

    ; Bottom-right (row+1, col+1)
    lea rax, [rsi + 1]
    cmp rax, r15
    jge skip_bottom
    lea rax, [rdi + 1]
    cmp rax, r13
    jge skip_bottom
    mov rax, rcx
    add rax, r14
    inc rax
    mov r8, input_buffer
    add r8, rax
    cmp byte [r8], '@'
    jne skip_bottom
    inc r9
skip_bottom:

    ; Check if accessible (< 4 neighbors)
    cmp r9, 4
    jge next_col
    inc rbx                  ; accessible!

next_col:
    inc rdi
    jmp col_loop

next_row:
    inc rsi
    jmp row_loop

done:
    mov rdi, rbx
    call print_number

    mov rax, 60
    mov rdi, 0
    syscall

section .data
filename: db "../inputs/day4_input.txt", 0

section .bss
