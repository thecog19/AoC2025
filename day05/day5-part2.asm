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
    jge done_parsing

    ; Check for blank line
    movzx rax, byte [r12]
    cmp al, 10
    je done_parsing
    cmp al, 13
    je done_parsing

    ; Parse start number
    parse_int
    mov [rbx], rax

    ; Skip dash
    inc r12

    ; Parse end number
    parse_int
    mov [rbx + 8], rax

    ; Next slot
    add rbx, 16
    inc r14

    ; Skip ONE newline sequence
    cmp r12, r13
    jge done_parsing
    movzx rax, byte [r12]
    cmp al, 13
    jne skip_lf
    inc r12
skip_lf:
    cmp r12, r13
    jge done_parsing
    movzx rax, byte [r12]
    cmp al, 10
    jne parse_ranges
    inc r12
    jmp parse_ranges

done_parsing:
    ; ===== PHASE 2: Bubble sort ranges by start value =====
    ; Outer loop: r8 = 0 to range_count-1
    mov r8, 0
outer_loop:
    mov rax, r14
    dec rax
    cmp r8, rax
    jge sort_done

    ; Inner loop: r9 = 0 to range_count-1-r8
    mov r9, 0
    mov r10, r14
    dec r10
    sub r10, r8              ; r10 = range_count - 1 - i

inner_loop:
    cmp r9, r10
    jge inner_done

    ; Compare ranges[r9].start vs ranges[r9+1].start
    mov rax, r9
    shl rax, 4               ; rax = r9 * 16
    lea r11, [ranges + rax]  ; r11 = &ranges[r9]

    mov rcx, [r11]           ; rcx = ranges[r9].start
    mov rdx, [r11 + 16]      ; rdx = ranges[r9+1].start

    cmp rcx, rdx
    jle no_swap

    ; Swap ranges[r9] and ranges[r9+1]
    ; Swap starts
    mov [r11], rdx
    mov [r11 + 16], rcx
    ; Swap ends
    mov rcx, [r11 + 8]
    mov rdx, [r11 + 24]
    mov [r11 + 8], rdx
    mov [r11 + 24], rcx

no_swap:
    inc r9
    jmp inner_loop

inner_done:
    inc r8
    jmp outer_loop

sort_done:
    ; ===== PHASE 3: Merge overlapping ranges and count =====
    cmp r14, 0
    je print_zero

    mov r15, 0               ; r15 = total count
    mov rbx, ranges

    ; Initialize current merged range
    mov r8, [rbx]            ; r8 = cur_start
    mov r9, [rbx + 8]        ; r9 = cur_end

    ; Walk through remaining ranges
    mov rcx, 1               ; rcx = index (start at 1)

merge_loop:
    cmp rcx, r14
    jge merge_done

    ; Get next range
    mov rax, rcx
    shl rax, 4
    lea r11, [ranges + rax]
    mov r10, [r11]           ; r10 = next_start
    mov rdx, [r11 + 8]       ; rdx = next_end

    ; Check if overlapping: next_start <= cur_end + 1
    mov rax, r9
    inc rax                  ; rax = cur_end + 1
    cmp r10, rax
    jg not_overlapping

    ; Overlapping - extend cur_end if needed
    cmp rdx, r9
    jle no_extend
    mov r9, rdx              ; cur_end = max(cur_end, next_end)
no_extend:
    jmp next_range

not_overlapping:
    ; Finalize current range
    mov rax, r9
    sub rax, r8
    inc rax                  ; size = cur_end - cur_start + 1
    add r15, rax             ; total += size

    ; Start new current range
    mov r8, r10              ; cur_start = next_start
    mov r9, rdx              ; cur_end = next_end

next_range:
    inc rcx
    jmp merge_loop

merge_done:
    ; Add final range
    mov rax, r9
    sub rax, r8
    inc rax
    add r15, rax

    mov rdi, r15
    call print_number
    jmp exit

print_zero:
    mov rdi, 0
    call print_number

exit:
    mov rax, 60
    mov rdi, 0
    syscall

section .data
filename: db "../inputs/day5_input.txt", 0

section .bss
ranges: resb 16384
