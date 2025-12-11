extern read_file
extern read_integer
extern print_number
extern input_buffer

section .text
global _start

_start:
    ; Read input file
    mov rdi, filename
    call read_file
    mov [file_size], rax

    xor r15, r15                 ; r15 = total presses across all machines
    mov rsi, input_buffer        ; rsi = current position in input

.next_machine:
    ; Check if we've reached end of file
    mov rax, rsi
    sub rax, input_buffer
    cmp rax, [file_size]
    jge .done

    ; Parse target pattern [.##.]
    ; Find '['
.find_bracket:
    cmp byte [rsi], '['
    je .parse_target
    cmp byte [rsi], 0
    je .done
    inc rsi
    jmp .find_bracket

.parse_target:
    inc rsi                      ; skip '['
    xor r8, r8                   ; r8 = target bitmask
    xor rcx, rcx                 ; rcx = bit position

.parse_target_loop:
    cmp byte [rsi], ']'
    je .target_done

    cmp byte [rsi], '#'
    jne .target_not_on

    ; Set bit at position rcx
    mov rax, 1
    shl rax, cl
    or r8, rax

.target_not_on:
    inc rcx
    inc rsi
    jmp .parse_target_loop

.target_done:
    inc rsi                      ; skip ']'
    mov [target], r8
    mov [num_lights], rcx

    ; Parse buttons - each (x,y,z) becomes a bitmask
    xor r12, r12                 ; r12 = button count

.parse_buttons:
    ; Skip whitespace, look for '(' or '{'
.skip_ws:
    movzx rax, byte [rsi]
    cmp al, '('
    je .parse_one_button
    cmp al, '{'
    je .buttons_done
    cmp al, 10                   ; newline
    je .buttons_done
    cmp al, 0
    je .buttons_done
    inc rsi
    jmp .skip_ws

.parse_one_button:
    inc rsi                      ; skip '('
    xor r9, r9                   ; r9 = button bitmask

.parse_button_nums:
    ; Check for ')'
    cmp byte [rsi], ')'
    je .button_done

    ; Skip comma if present
    cmp byte [rsi], ','
    jne .parse_num
    inc rsi

.parse_num:
    ; Parse number
    mov rdi, rsi
    call read_integer
    mov rsi, rdx                 ; rdx = new position

    ; Set bit at position rax
    mov rcx, rax
    mov rax, 1
    shl rax, cl
    or r9, rax
    jmp .parse_button_nums

.button_done:
    inc rsi                      ; skip ')'

    ; Store button bitmask
    mov rax, r12
    mov [buttons + rax*8], r9
    inc r12
    jmp .parse_buttons

.buttons_done:
    mov [num_buttons], r12

    ; Skip to end of line (past the {...} part)
.skip_to_eol:
    movzx rax, byte [rsi]
    cmp al, 10
    je .eol_found
    cmp al, 0
    je .solve_machine
    inc rsi
    jmp .skip_to_eol

.eol_found:
    inc rsi                      ; skip newline

.solve_machine:
    ; Try all subsets of buttons
    ; r10 = subset (bitmask of which buttons to press)
    ; r11 = best (minimum presses found)

    mov r11, 9999                ; r11 = best = infinity
    xor r10, r10                 ; r10 = subset = 0

    ; Calculate 2^num_buttons
    mov rcx, [num_buttons]
    mov r13, 1
    shl r13, cl                  ; r13 = 2^num_buttons

.try_subset:
    cmp r10, r13
    jge .machine_done

    ; Compute XOR of selected buttons
    xor r8, r8                   ; r8 = xor result
    xor rcx, rcx                 ; rcx = button index

.xor_loop:
    cmp rcx, [num_buttons]
    jge .xor_done

    ; Check if button rcx is in subset r10
    mov rax, 1
    shl rax, cl
    test r10, rax
    jz .xor_next

    ; XOR in this button's mask
    xor r8, [buttons + rcx*8]

.xor_next:
    inc rcx
    jmp .xor_loop

.xor_done:
    ; Check if result matches target
    cmp r8, [target]
    jne .next_subset

    ; Count bits in r10 (popcount)
    mov rax, r10
    xor rcx, rcx                 ; rcx = count
.popcount:
    test rax, rax
    jz .popcount_done
    mov rdx, rax
    dec rdx
    and rax, rdx                 ; clear lowest set bit
    inc rcx
    jmp .popcount
.popcount_done:

    ; Update best if better
    cmp rcx, r11
    cmovl r11, rcx

.next_subset:
    inc r10
    jmp .try_subset

.machine_done:
    ; Add best to total
    add r15, r11
    jmp .next_machine

.done:
    ; Print total
    mov rdi, r15
    call print_number

    ; Exit
    mov rax, 60
    xor rdi, rdi
    syscall

section .data
filename: db "../inputs/day10_input.txt", 0

section .bss
file_size: resq 1
target: resq 1
num_lights: resq 1
num_buttons: resq 1
buttons: resq 64               ; up to 64 buttons per machine
