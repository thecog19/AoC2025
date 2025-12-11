extern print_number
extern read_file
extern read_integer
extern input_buffer

section .text
global _start

_start:
    ; Read input file
    mov rdi, filename
    call read_file
    mov [file_size], rax

    ; Parse all points (x,y coordinates)
    mov rsi, input_buffer
    xor r12, r12                 ; r12 = point count

.parse_loop:
    ; Check if we've reached end of file
    mov rax, rsi
    sub rax, input_buffer
    cmp rax, [file_size]
    jge .parse_done

    ; Skip any whitespace/newlines
    movzx rax, byte [rsi]
    cmp al, '0'
    jl .skip_char
    cmp al, '9'
    jg .skip_char

    ; Parse X coordinate
    mov rdi, rsi
    call read_integer
    mov rsi, rdx                 ; rdx = pointer after number

    ; Store X
    mov rcx, r12
    shl rcx, 4                   ; 2 qwords (16 bytes) per point
    mov [points + rcx], rax

    ; Skip comma
    inc rsi

    ; Parse Y coordinate
    mov rdi, rsi
    call read_integer
    mov rsi, rdx

    ; Store Y
    mov rcx, r12
    shl rcx, 4
    mov [points + rcx + 8], rax

    inc r12                      ; Next point
    jmp .parse_loop

.skip_char:
    inc rsi
    jmp .parse_loop

.parse_done:
    mov [num_points], r12

    ; Find largest rectangle area
    ; For each pair of points, compute |dx| * |dy|
    xor r15, r15                 ; r15 = max_area
    xor r12, r12                 ; r12 = i

.outer_loop:
    mov rax, [num_points]
    dec rax
    cmp r12, rax
    jge .done

    mov r13, r12
    inc r13                      ; r13 = j = i + 1

.inner_loop:
    cmp r13, [num_points]
    jge .next_i

    ; Get point i coords
    mov rax, r12
    shl rax, 4
    mov r8, [points + rax]       ; x1
    mov r9, [points + rax + 8]   ; y1

    ; Get point j coords
    mov rax, r13
    shl rax, 4
    mov r10, [points + rax]      ; x2
    mov r11, [points + rax + 8]  ; y2

    ; dx = |x2 - x1| + 1
    sub r10, r8
    mov rax, r10
    neg rax
    cmovs rax, r10               ; abs(dx)
    inc rax                      ; +1 to include both corners
    mov r10, rax

    ; dy = |y2 - y1| + 1
    sub r11, r9
    mov rax, r11
    neg rax
    cmovs rax, r11               ; abs(dy)
    inc rax                      ; +1 to include both corners
    mov r11, rax

    ; area = (dx+1) * (dy+1)
    mov rax, r10
    imul rax, r11

    ; Update max if larger
    cmp rax, r15
    cmovg r15, rax

    inc r13
    jmp .inner_loop

.next_i:
    inc r12
    jmp .outer_loop

.done:
    ; Print result
    mov rdi, r15
    call print_number

    ; Exit
    mov rax, 60
    xor rdi, rdi
    syscall

section .data
filename: db "../inputs/day9_input.txt", 0

section .bss
file_size: resq 1
num_points: resq 1
points: resq 2 * 10001          ; up to 10001 points * 2 coords
