extern print_number
extern read_file
extern input_buffer

section .text
global _start

_start:
    mov rdi, filename
    call read_file
    mov r12, input_buffer    ; pointer to current position
    mov r13, rax             ; bytes remaining

    mov r8, 0                ; sum accumulator
    mov r9, input_buffer     ; line start pointer

process_loop:
    cmp r13, 0
    je done

    mov al, [r12]

    cmp al, 13               ; carriage return?
    je process_line          ; treat CR as line end (handle CRLF)

    cmp al, 10               ; newline?
    je process_line

    jmp next_byte

process_line:
    ; r9 = line start, r12 = current pos (at newline)
    ; Line length = r12 - r9

    ; Pass 1: find highest digit (not at last position)
    mov r10, 0               ; best digit value
    mov r11, r9              ; best digit position
    mov rcx, r9              ; current scan position

pass1_loop:
    lea rax, [rcx + 1]       ; need at least 1 char after
    cmp rax, r12
    jge pass1_done

    movzx rax, byte [rcx]
    sub rax, '0'             ; convert to digit value
    cmp rax, r10
    jle pass1_next

    mov r10, rax             ; new best digit
    mov r11, rcx             ; save position

pass1_next:
    inc rcx
    jmp pass1_loop

pass1_done:
    ; Pass 2: find highest digit after r11
    mov r14, 0               ; second digit value
    lea rcx, [r11 + 1]       ; start after best position

pass2_loop:
    cmp rcx, r12
    jge pass2_done

    movzx rax, byte [rcx]
    sub rax, '0'
    cmp rax, r14
    jle pass2_next

    mov r14, rax             ; new best second digit

pass2_next:
    inc rcx
    jmp pass2_loop

pass2_done:
    ; Compute joltage: r10 * 10 + r14
    imul r10, 10
    add r10, r14
    add r8, r10              ; add to sum

    ; Set up for next line
    lea r9, [r12 + 1]        ; next line starts after newline

next_byte:
    inc r12
    dec r13
    jmp process_loop

done:
    mov rdi, r8
    call print_number

    mov rax, 60
    mov rdi, 0
    syscall

section .data
filename: db "inputs/day3_input.txt", 0

section .bss
