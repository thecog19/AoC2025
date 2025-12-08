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

    ; Initialize current_counts array (all zeros)
    mov rdi, current_counts
    mov rcx, 256
    xor rax, rax
    rep stosq

    ; Set starting timeline count at S column = 1
    mov rax, [start_col]
    mov qword [current_counts + rax*8], 1

    ; r12 = current row (start at row 1, since S is at row 0)
    mov r12, 1

.row_loop:
    mov rax, [num_lines]
    cmp r12, rax
    jge .done

    ; Clear next_counts array
    mov rdi, next_counts
    mov rcx, 256
    xor rax, rax
    rep stosq

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

    ; Get timeline count at this column
    mov r14, [current_counts + r13*8]
    cmp r14, 0
    je .next_col                 ; no timelines here

    ; Get character at this position
    mov rax, [row_ptr]
    movzx rbx, byte [rax + r13]

    ; Check if it's a splitter
    cmp bl, '^'
    je .split_beam

    ; Check if it's empty space (beam continues)
    cmp bl, '.'
    jne .next_col                ; anything else stops the beam

    ; Beam continues - add count to next_counts at same column
    add [next_counts + r13*8], r14
    jmp .next_col

.split_beam:
    ; Add timeline count to left (col-1) if in bounds
    cmp r13, 0
    je .add_right
    mov rax, r13
    dec rax
    add [next_counts + rax*8], r14

.add_right:
    ; Add timeline count to right (col+1) if in bounds
    mov rax, r13
    inc rax
    cmp rax, [line_width]
    jge .next_col
    add [next_counts + rax*8], r14

.next_col:
    inc r13
    jmp .col_loop

.next_row:
    ; Copy next_counts to current_counts
    mov rsi, next_counts
    mov rdi, current_counts
    mov rcx, 256 * 8             ; 256 qwords = 2048 bytes
    rep movsb

    inc r12
    jmp .row_loop

.done:
    ; Sum all timeline counts
    xor r15, r15
    xor r13, r13
.sum_loop:
    cmp r13, 256
    jge .print_result
    add r15, [current_counts + r13*8]
    inc r13
    jmp .sum_loop

.print_result:
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
current_counts: resq 256        ; qword array for timeline counts
next_counts: resq 256
