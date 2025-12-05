extern print_number
extern read_file
extern input_buffer

section .text
global _start

; Macro to parse integer at [r12], result in rax, updates r12 to first non-digit
%macro parse_int 0
    xor rax, rax
%%parse_loop:
    movzx rcx, byte [r12]
    sub rcx, '0'
    cmp rcx, 9
    ja %%parse_done
    imul rax, 10
    add rax, rcx
    inc r12
    jmp %%parse_loop
%%parse_done:
%endmacro

_start:
    mov rdi, filename
    call read_file
    mov r12, input_buffer    ; r12 = current position
    mov r13, rax             ; r13 = file size
    add r13, input_buffer    ; r13 = end of input

    mov r14, 0               ; r14 = range count
    mov rbx, ranges          ; rbx = pointer to ranges array

    ; ===== PHASE 1: Parse ranges until blank line =====
parse_ranges:
    cmp r12, r13
    jge done_ranges

    ; Check for blank line (newline at start = done with ranges)
    movzx rax, byte [r12]
    cmp al, 10
    je done_ranges
    cmp al, 13
    je done_ranges

    ; Parse start number
    parse_int
    mov [rbx], rax           ; Store start

    ; Skip the dash '-'
    inc r12

    ; Parse end number
    parse_int
    mov [rbx + 8], rax       ; Store end

    ; Move to next range slot
    add rbx, 16
    inc r14

    ; Skip ONE newline sequence (CR, LF, or CRLF)
    cmp r12, r13
    jge done_ranges
    movzx rax, byte [r12]
    cmp al, 13               ; CR?
    jne not_cr
    inc r12                  ; Skip CR
not_cr:
    cmp r12, r13
    jge done_ranges
    movzx rax, byte [r12]
    cmp al, 10               ; LF?
    jne parse_ranges
    inc r12                  ; Skip LF
    jmp parse_ranges

done_ranges:
    ; Skip blank line (one more newline sequence)
skip_blank:
    cmp r12, r13
    jge parse_ids
    movzx rax, byte [r12]
    cmp al, 10
    je do_skip_blank
    cmp al, 13
    je do_skip_blank
    jmp parse_ids
do_skip_blank:
    inc r12
    jmp skip_blank

    ; ===== PHASE 2: Check IDs against ranges =====
parse_ids:
    mov r15, 0               ; r15 = fresh count

next_id:
    cmp r12, r13
    jge done

    ; Skip whitespace/newlines
    movzx rax, byte [r12]
    cmp al, 10
    je skip_char
    cmp al, 13
    je skip_char
    cmp al, ' '
    je skip_char

    ; Must be a digit, parse the ID
    cmp al, '0'
    jb done
    cmp al, '9'
    ja done

    parse_int
    mov r8, rax              ; r8 = ID to check

    ; Check ID against all ranges
    mov rcx, 0               ; range index
    mov r9, ranges

check_range:
    cmp rcx, r14
    jge not_fresh

    mov r10, [r9]            ; start
    mov r11, [r9 + 8]        ; end

    cmp r8, r10              ; ID < start?
    jb try_next_range
    cmp r8, r11              ; ID > end?
    ja try_next_range

    ; Fresh!
    inc r15
    jmp next_id

try_next_range:
    add r9, 16
    inc rcx
    jmp check_range

not_fresh:
    jmp next_id

skip_char:
    inc r12
    jmp next_id

done:
    mov rdi, r15
    call print_number

    mov rax, 60
    mov rdi, 0
    syscall

section .data
filename: db "../inputs/day5_input.txt", 0

section .bss
ranges: resb 16384
