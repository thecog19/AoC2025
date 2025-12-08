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

    ; Count number of lines (handle file not ending with newline)
    mov rax, [file_size]
    xor rdx, rdx
    div rcx
    mov [num_lines], rax
    cmp rdx, 0
    je .lines_counted
    inc qword [num_lines]
.lines_counted:

    ; r15 = grand total
    xor r15, r15

    ; r12 = current column (scanning left to right to find problems)
    xor r12, r12

.process_columns:
    mov rax, [line_width]
    cmp r12, rax
    jge .done

    ; Check if this column is a separator (all spaces)
    call is_separator_column
    cmp rax, 1
    je .next_column

    ; Found start of a problem - find the end
    mov r13, r12                 ; r13 = start column
.find_end:
    inc r12
    mov rax, [line_width]
    cmp r12, rax
    jge .found_problem_end
    call is_separator_column
    cmp rax, 0
    je .find_end

.found_problem_end:
    ; Problem spans columns r13 to r12-1
    ; Get operator from last row (find it in this range)
    mov rax, [num_lines]
    dec rax
    mov rcx, [line_stride]
    imul rax, rcx
    add rax, input_buffer
    add rax, r13

    mov rbx, r12
    sub rbx, r13                 ; rbx = width of problem
.find_op:
    movzx rdx, byte [rax]
    cmp dl, '*'
    je .got_mult
    cmp dl, '+'
    je .got_add
    inc rax
    dec rbx
    jnz .find_op
    jmp .next_column

.got_mult:
    mov byte [current_op], '*'
    jmp .parse_columns
.got_add:
    mov byte [current_op], '+'

.parse_columns:
    ; Initialize accumulator based on operation
    cmp byte [current_op], '*'
    jne .init_add
    mov qword [accumulator], 1
    jmp .process_problem_cols
.init_add:
    mov qword [accumulator], 0

.process_problem_cols:
    ; Process columns RIGHT-TO-LEFT within the problem (r13 to r12-1)
    ; r14 = current column being processed (starts at r12-1, goes down to r13)
    mov r14, r12
    dec r14                      ; start at rightmost column of problem

.col_loop:
    cmp r14, r13
    jl .problem_done

    ; Parse vertical number from column r14
    ; Read digits from top to bottom (rows 0 to num_lines-2)
    call parse_vertical_number
    cmp rbx, 0                   ; rbx = 1 if number found
    je .next_col

    ; Apply operation
    cmp byte [current_op], '*'
    jne .do_add
    mov rcx, [accumulator]
    imul rax, rcx
    mov [accumulator], rax
    jmp .next_col
.do_add:
    add [accumulator], rax

.next_col:
    dec r14
    jmp .col_loop

.problem_done:
    mov rax, [accumulator]
    add r15, rax
    jmp .process_columns

.next_column:
    inc r12
    jmp .process_columns

.done:
    mov rdi, r15
    call print_number

    mov rax, 60
    xor rdi, rdi
    syscall

; Check if column r12 is all spaces
; Returns 1 in rax if separator, 0 otherwise
is_separator_column:
    push r14
    xor r14, r14                 ; row counter
.check_row:
    mov rax, [num_lines]
    cmp r14, rax
    jge .is_sep

    mov rax, r14
    mov rcx, [line_stride]
    imul rax, rcx
    add rax, r12
    add rax, input_buffer
    movzx rax, byte [rax]
    cmp al, ' '
    jne .not_sep
    inc r14
    jmp .check_row
.is_sep:
    mov rax, 1
    pop r14
    ret
.not_sep:
    xor rax, rax
    pop r14
    ret

; Parse vertical number from column r14
; Reads top-to-bottom (rows 0 to num_lines-2, skip operator row)
; Returns number in rax, rbx=1 if valid number found, rbx=0 if column is all spaces
parse_vertical_number:
    push r8
    push r9
    push r10

    xor rax, rax                 ; accumulator for number
    xor r10, r10                 ; flag: found any digit?
    xor r8, r8                   ; current row

.vert_loop:
    mov r9, [num_lines]
    dec r9                       ; skip operator row
    cmp r8, r9
    jge .vert_done

    ; Get character at (row r8, column r14)
    push rax
    mov rax, r8
    mov rcx, [line_stride]
    imul rax, rcx
    add rax, r14
    add rax, input_buffer
    movzx rcx, byte [rax]
    pop rax

    ; Check if it's a digit
    sub rcx, '0'
    cmp rcx, 9
    ja .next_row_vert            ; not a digit, skip

    ; It's a digit - accumulate
    imul rax, 10
    add rax, rcx
    mov r10, 1                   ; mark that we found a digit

.next_row_vert:
    inc r8
    jmp .vert_loop

.vert_done:
    mov rbx, r10                 ; rbx = 1 if found digits, 0 otherwise
    pop r10
    pop r9
    pop r8
    ret

section .data
filename: db "../inputs/day6_input.txt", 0

section .bss
file_size: resq 1
line_width: resq 1
line_stride: resq 1
num_lines: resq 1
accumulator: resq 1
current_op: resb 1
