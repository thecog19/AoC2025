extern print_number
extern read_file
extern input_buffer

section .text
global _start

_start:
    mov rdi, filename
    call read_file
    mov [file_size], rax

    ; Find line width (position of first newline)
    mov rdi, input_buffer
    xor rcx, rcx
.find_newline:
    movzx rax, byte [rdi + rcx]
    cmp al, 10
    je .found_newline
    cmp al, 13
    je .found_newline
    inc rcx
    jmp .find_newline
.found_newline:
    mov [line_width], rcx

    ; Check for CRLF
    movzx rax, byte [rdi + rcx]
    cmp al, 13
    jne .not_crlf
    inc rcx                      ; skip CR
.not_crlf:
    inc rcx                      ; skip LF
    mov [line_stride], rcx       ; stride includes newline chars

    ; Count number of lines
    mov rax, [file_size]
    xor rdx, rdx
    div rcx
    mov [num_lines], rax
    cmp rdx, 0
    je .lines_counted
    inc qword [num_lines]
.lines_counted:

    ; Find 'S' position in first row
    mov rdi, input_buffer
    xor rcx, rcx
.find_s:
    movzx rax, byte [rdi + rcx]
    cmp al, 'S'
    je .found_s
    inc rcx
    jmp .find_s
.found_s:
    mov [start_col], rcx

    ; Initialize current_beams array (all zeros)
    mov rdi, current_beams
    mov rcx, 256
    xor rax, rax
    rep stosb

    ; Set starting beam at S column
    mov rax, [start_col]
    mov byte [current_beams + rax], 1

    ; r15 = split count
    xor r15, r15

    ; r12 = current row (start at row 1, since S is at row 0)
    mov r12, 1

.row_loop:
    mov rax, [num_lines]
    cmp r12, rax
    jge .done

    ; Clear next_beams array
    mov rdi, next_beams
    mov rcx, 256
    xor rax, rax
    rep stosb

    ; Get pointer to current row
    mov rax, r12
    mov rcx, [line_stride]
    imul rax, rcx
    add rax, input_buffer
    mov [row_ptr], rax

    ; Process each column
    xor r13, r13                 ; r13 = current column

.col_loop:
    mov rax, [line_width]
    cmp r13, rax
    jge .next_row

    ; Check if beam active at this column
    cmp byte [current_beams + r13], 0
    je .next_col

    ; Get character at this position
    mov rax, [row_ptr]
    movzx rbx, byte [rax + r13]

    ; Check if it's a splitter
    cmp bl, '^'
    je .split_beam

    ; Check if it's empty space (beam continues)
    cmp bl, '.'
    jne .next_col                ; anything else stops the beam

    ; Beam continues - mark in next_beams
    mov byte [next_beams + r13], 1
    jmp .next_col

.split_beam:
    ; Increment split count
    inc r15

    ; Add beam to left (col-1) if in bounds
    cmp r13, 0
    je .add_right
    mov rax, r13
    dec rax
    mov byte [next_beams + rax], 1

.add_right:
    ; Add beam to right (col+1) if in bounds
    mov rax, r13
    inc rax
    cmp rax, [line_width]
    jge .next_col
    mov byte [next_beams + rax], 1

.next_col:
    inc r13
    jmp .col_loop

.next_row:
    ; Copy next_beams to current_beams
    mov rsi, next_beams
    mov rdi, current_beams
    mov rcx, 256
    rep movsb

    inc r12
    jmp .row_loop

.done:
    mov rdi, r15
    call print_number

    mov rax, 60
    xor rdi, rdi
    syscall

section .data
filename: db "../inputs/day7_input.txt", 0

section .bss
file_size: resq 1
line_width: resq 1
line_stride: resq 1
num_lines: resq 1
start_col: resq 1
row_ptr: resq 1
current_beams: resb 256
next_beams: resb 256
