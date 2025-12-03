extern print_number
extern read_file
extern print_file
extern input_buffer

section .text
global _start

_start:

mov rdi, filename
call read_file
mov r12, input_buffer
mov r13, rax

mov r14, 0 ;we need a buffer for the first half of the range
mov r15, 0 ;we need a buffer the second half of the range

mov r11, 0 ;we need a flag for the first half vs the second half of the range

mov r8, 0 ;this is the SUM of all ids

process_loop: 
    cmp r13, 0
    je done
    mov al, [r12]

    cmp al, "-"
    je dash_register_switch
    jmp after_dash
    dash_register_switch:
        mov r11, 1
        jmp end_step
    after_dash: 

    cmp al, ","
    je next_sequence
    jmp after_comma
    next_sequence:
        processing_loop:
            mov rax, r14
            mov rcx, 10
            mov r9, digit_buffer + 20    ; build from end

            convert_to_digits:
                xor rdx, rdx
                div rcx
                add rdx, '0'
                dec r9
                mov [r9], dl
                cmp rax, 0
                jne convert_to_digits

            mov r10, digit_buffer + 20
            sub r10, r9                  ; r10 = digit count
            test r10, 1                  ; is low bit set?
            jnz not_doubled              ; odd length, skip

            mov rcx, r10
            shr rcx, 1                   ; rcx = half length

            mov rsi, r9                  ; first half
            mov rdi, r9
            add rdi, rcx                 ; second half

            repe cmpsb
            jne not_doubled              ; didn't match

            add r8, r14

        not_doubled:
        cmp r14, r15 
        lea r14, [r14+1]
        jne processing_loop 

        mov r11, 0 ;this is the reset block
        mov r14, 0
        mov r15, 0
        jmp end_step
    after_comma:

    ;accumulate the number into either r14 or r15
    cmp r11, 0
    je accumulate_first
    jmp accumulate_second

    accumulate_first: 
    sub al, 48
    imul r14, r14, 10
    movzx rax, al
    add r14, rax
    jmp end_step

    accumulate_second:
    sub al, 48
    imul r15, r15, 10
    movzx rax, al
    add r15, rax
    jmp end_step

    end_step:
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
filename: db "inputs/day2_input.txt", 0

section .bss
digit_buffer: resb 21