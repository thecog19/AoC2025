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
    je process_line          ; treat CR as line end

    cmp al, 10               ; newline?
    je process_line

    jmp next_byte

process_line:
    ; r9 = line start, r12 = line end (at CR or LF)
    ; Line length = r12 - r9

    mov r10, r12
    sub r10, r9              ; r10 = line length (n)

    mov r14, 0               ; result accumulator
    mov r15, 0               ; digits picked so far
    mov rbx, r9              ; current search start position

pick_loop:
    cmp r15, 12
    jge pick_done            ; picked all 12 digits

    ; Calculate search end: line_start + (n - (12 - picks))
    ; = r9 + (r10 - (12 - r15))
    ; = r9 + r10 - 12 + r15
    mov rcx, r9
    add rcx, r10
    sub rcx, 12
    add rcx, r15
    inc rcx                  ; end is exclusive, so +1

    ; Find max digit in [rbx, rcx)
    mov rdi, rbx             ; scan position
    mov rsi, 0               ; best digit value
    mov rdx, rbx             ; best digit position

find_max_loop:
    cmp rdi, rcx
    jge find_max_done

    movzx rax, byte [rdi]
    sub rax, '0'
    cmp rax, rsi
    jle find_max_next

    mov rsi, rax             ; new best digit
    mov rdx, rdi             ; new best position

find_max_next:
    inc rdi
    jmp find_max_loop

find_max_done:
    ; rsi = best digit, rdx = best position
    ; Accumulate: result = result * 10 + digit
    imul r14, 10
    add r14, rsi

    ; Update search start to after best position
    lea rbx, [rdx + 1]

    ; Increment picks
    inc r15
    jmp pick_loop

pick_done:
    ; Add result to sum
    add r8, r14

    ; Set up for next line
    lea r9, [r12 + 1]

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
