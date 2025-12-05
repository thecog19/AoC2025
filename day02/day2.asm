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

            ; Try each pattern length from 1 to digit_count/2
            mov rbx, 1                   ; rbx = pattern length to try

            try_pattern_length:
                mov rax, r10
                shr rax, 1               ; rax = digit_count / 2
                cmp rbx, rax
                ja not_invalid           ; tried all lengths, no pattern found

                ; Check if digit_count % pattern_len == 0
                mov rax, r10
                xor rdx, rdx
                div rbx                  ; rax = quotient, rdx = remainder
                test rdx, rdx
                jnz next_pattern_length  ; not evenly divisible

                ; rax = number of repetitions needed
                cmp rax, 2
                jb next_pattern_length   ; need at least 2 repetitions

                ; Check if the pattern of length rbx repeats
                mov rcx, rax
                dec rcx                  ; blocks to compare = repetitions - 1
                lea rdi, [r9 + rbx]      ; rdi = start of second block

            check_block:
                test rcx, rcx
                jz pattern_found         ; all blocks matched!

                ; Compare rbx bytes: [r9] vs [rdi]
                push rcx
                push rdi
                push rbx

                mov rsi, r9              ; always compare against first block
                mov rcx, rbx
                repe cmpsb

                pop rbx
                pop rdi
                pop rcx

                jne next_pattern_length  ; mismatch, try next length

                add rdi, rbx             ; move to next block
                dec rcx
                jmp check_block

            pattern_found:
                add r8, r14
                jmp not_invalid

            next_pattern_length:
                inc rbx
                jmp try_pattern_length

            not_invalid:
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