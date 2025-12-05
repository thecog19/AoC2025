global print_number
global read_file
global print_file
global read_integer
global input_buffer

section .text

print_number:
    mov rax, rdi
    mov rcx, 10
    mov r8, print_buffer + 20
    mov byte [print_buffer + 20], 10

    convert_loop:
        xor rdx, rdx
        div rcx
        add rdx, 48
        dec r8
        mov [r8], dl
        cmp rax, 0
        jne convert_loop

    mov rax, 1
    mov rdi, 1
    mov rsi, r8
    mov rdx, print_buffer + 21
    sub rdx, r8
    syscall
    ret

read_file:
    mov rax, 2
    mov rsi, 0
    syscall

    mov [file_descriptor], rax

    mov rax, 0 
    mov rdi, [file_descriptor] 
    mov rsi, input_buffer 
    mov rdx, 32768
    syscall
    mov r8, rax
    mov rdi, rax

    mov rax, 3
    mov rdi, [file_descriptor]
    syscall
    mov rax, r8
    ret

print_file:
    mov rdx, rdi
    mov rax, 1
    mov rdi, 1
    mov rsi, input_buffer
    syscall
    ret

; read_integer: parse an integer from a string
; Input:  rdi = pointer to string (first char should be a digit)
; Output: rax = parsed integer value
;         rdx = pointer to first non-digit character
; Clobbers: rcx, r8
read_integer:
    xor rax, rax             ; rax = accumulator = 0
    mov rcx, 10              ; multiplier
    mov rdx, rdi             ; rdx = current position

.read_loop:
    movzx r8, byte [rdx]     ; load current character
    sub r8, '0'              ; convert ASCII to digit
    cmp r8, 9                ; is it 0-9?
    ja .done                 ; if > 9, not a digit, we're done

    imul rax, rcx            ; accumulator *= 10
    add rax, r8              ; accumulator += digit
    inc rdx                  ; move to next character
    jmp .read_loop

.done:
    ret

section .bss

print_buffer: resb 21
input_buffer: resb 32768
file_descriptor: resb 8
