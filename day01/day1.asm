extern print_number
extern read_file
extern print_file
extern input_buffer

section .text 
global _start

_start:

mov rdi, filename
call read_file
mov r13, input_buffer
mov r14, rax

mov rbx, 50
mov r12, 0

mov r15, 0
mov r9, 0

process_loop:
    cmp r14,0 
    je done
    mov al, [r13]

    cmp al, 'L'
    jne not_L
    mov r15, 0
    jmp next_byte
    not_L:

    cmp al, 'R'
    jne not_R
    mov r15, 1
    jmp next_byte
    not_R:

    cmp al, 13          ; carriage return?
    je next_byte        ; just skip it

    cmp al, 10
    jne not_newline

    mov r10, 0              ; flag: did we wrap?

    mov r11, rbx 
    cmp r15, 0
    jne not_left
    sub rbx, r9
    check_zeros:
    cmp rbx, 0
    jge end_math
    cmp r11,0
    je skip_count
    inc r12
    skip_count:
    mov r10, 1
    mov r11, 1
    add rbx, 100
    jmp check_zeros

    not_left:
    add rbx, r9
    check_right_zeros:
    cmp rbx, 99
    jle end_math
    inc r12
    mov r10, 1
    sub rbx, 100
    jmp check_right_zeros
    end_math:

    mov r9, 0

    cmp rbx, 0
    jne next_byte      ; not on 0, skip

    cmp r15, 0         ; is it L direction?
    je count_landing   ; L always counts landing on 0

    cmp r10, 0         ; R: only count if didn't wrap
    jne next_byte

    count_landing:
    inc r12
    jmp next_byte

    not_newline:

    sub al, 48
    imul r9, r9, 10
    movzx rax, al
    add r9, rax

    next_byte:

    inc r13
    dec r14
    jmp process_loop

done: 
    mov rdi, r12
    call print_number

mov rax, 60
mov rdi, 0 
syscall

section .data 
filename: db "inputs/day1_input.txt", 0
