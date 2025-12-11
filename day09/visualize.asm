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

    ; Parse all points
    mov rsi, input_buffer
    xor r12, r12                 ; r12 = point count

.parse_loop:
    mov rax, rsi
    sub rax, input_buffer
    cmp rax, [file_size]
    jge .parse_done

    movzx rax, byte [rsi]
    cmp al, '0'
    jl .skip_char
    cmp al, '9'
    jg .skip_char

    ; Parse X
    mov rdi, rsi
    call read_integer
    mov rsi, rdx
    mov rcx, r12
    shl rcx, 4
    mov [points + rcx], rax

    inc rsi                      ; skip comma

    ; Parse Y
    mov rdi, rsi
    call read_integer
    mov rsi, rdx
    mov rcx, r12
    shl rcx, 4
    mov [points + rcx + 8], rax

    inc r12
    jmp .parse_loop

.skip_char:
    inc rsi
    jmp .parse_loop

.parse_done:
    mov [num_points], r12

    ; === Output SVG ===

    ; Header
    mov rdi, svg_header
    call print_string

    ; Polygon element start
    mov rdi, polygon_start
    call print_string

    ; Output all points as "x,y "
    xor r12, r12
.svg_points_loop:
    cmp r12, [num_points]
    jge .svg_points_done

    ; Get point
    mov rax, r12
    shl rax, 4
    mov rdi, [points + rax]      ; x
    call print_number_no_newline

    mov rdi, ','
    call print_char

    mov rax, r12
    shl rax, 4
    mov rdi, [points + rax + 8]  ; y
    call print_number_no_newline

    mov rdi, ' '
    call print_char

    inc r12
    jmp .svg_points_loop

.svg_points_done:
    ; Close polygon
    mov rdi, polygon_end
    call print_string

    ; Draw red circles at each vertex
    xor r12, r12
.svg_circles_loop:
    cmp r12, [num_points]
    jge .svg_circles_done

    ; <circle cx="
    mov rdi, circle_start
    call print_string

    ; x coord
    mov rax, r12
    shl rax, 4
    mov rdi, [points + rax]
    call print_number_no_newline

    ; " cy="
    mov rdi, circle_cy
    call print_string

    ; y coord
    mov rax, r12
    shl rax, 4
    mov rdi, [points + rax + 8]
    call print_number_no_newline

    ; " r="50" fill="red"/>
    mov rdi, circle_end
    call print_string

    inc r12
    jmp .svg_circles_loop

.svg_circles_done:
    ; SVG footer
    mov rdi, svg_footer
    call print_string

    ; Exit
    mov rax, 60
    xor rdi, rdi
    syscall

; ============================================
; print_string: Print null-terminated string
; Input: rdi = pointer to string
; ============================================
print_string:
    push rdi
    ; Find length
    mov rsi, rdi
    xor rcx, rcx
.strlen:
    cmp byte [rsi + rcx], 0
    je .strlen_done
    inc rcx
    jmp .strlen
.strlen_done:
    mov rax, 1
    mov rdi, 1
    mov rdx, rcx
    syscall
    pop rdi
    ret

; ============================================
; print_char: Print single character
; Input: rdi = character (in low byte)
; ============================================
print_char:
    mov [char_buf], dil
    mov rax, 1
    mov rdi, 1
    mov rsi, char_buf
    mov rdx, 1
    syscall
    ret

; ============================================
; print_number_no_newline: Print number without newline
; Input: rdi = number
; ============================================
print_number_no_newline:
    mov rax, rdi
    mov rcx, 10
    mov r8, num_buffer + 20

.convert_loop:
    xor rdx, rdx
    div rcx
    add rdx, '0'
    dec r8
    mov [r8], dl
    test rax, rax
    jnz .convert_loop

    ; Print
    mov rax, 1
    mov rdi, 1
    mov rsi, r8
    mov rdx, num_buffer + 20
    sub rdx, r8
    syscall
    ret

section .data
filename: db "../inputs/day9_input.txt", 0

svg_header:
    db '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100000 100000">', 10
    db '<rect width="100000" height="100000" fill="#1a1a2e"/>', 10
    db 0

polygon_start:
    db '<polygon points="', 0

polygon_end:
    db '" fill="#2d5a3d" stroke="#4a9f5a" stroke-width="100"/>', 10, 0

circle_start:
    db '<circle cx="', 0

circle_cy:
    db '" cy="', 0

circle_end:
    db '" r="200" fill="#ff6b6b"/>', 10, 0

svg_footer:
    db '</svg>', 10, 0

section .bss
file_size: resq 1
num_points: resq 1
char_buf: resb 1
num_buffer: resb 21
points: resq 2 * 10001
