extern read_file
extern read_integer
extern print_number
extern input_buffer

section .text
global _start

; Strategy: Parse, build matrix, Gaussian elimination, enumerate free vars

_start:
    mov rdi, filename
    call read_file
    mov [file_size], rax

    xor r15, r15                 ; r15 = total presses across all machines
    mov rsi, input_buffer

.next_machine:
    mov rax, rsi
    sub rax, input_buffer
    cmp rax, [file_size]
    jge .done

    ; Skip [...] part
.find_bracket:
    cmp byte [rsi], ']'
    je .bracket_found
    cmp byte [rsi], 0
    je .done
    inc rsi
    jmp .find_bracket

.bracket_found:
    inc rsi

    ; Clear matrix
    lea rdi, [matrix]
    mov rcx, 16*17
    xor rax, rax
.clear_matrix:
    mov qword [rdi], 0
    add rdi, 8
    dec rcx
    jnz .clear_matrix

    xor r12, r12                 ; r12 = button count (columns)

.parse_buttons:
.skip_ws:
    movzx rax, byte [rsi]
    cmp al, '('
    je .parse_one_button
    cmp al, '{'
    je .buttons_done
    cmp al, 10
    je .buttons_done
    cmp al, 0
    je .buttons_done
    inc rsi
    jmp .skip_ws

.parse_one_button:
    inc rsi
.parse_button_nums:
    cmp byte [rsi], ')'
    je .button_done
    cmp byte [rsi], ','
    jne .parse_num
    inc rsi
.parse_num:
    mov rdi, rsi
    call read_integer
    mov rsi, rdx
    ; Set matrix[rax][r12] = 1
    imul rdi, rax, 17*8
    mov rax, r12
    shl rax, 3
    add rdi, rax
    mov qword [matrix + rdi], 1
    jmp .parse_button_nums

.button_done:
    inc rsi
    inc r12
    jmp .parse_buttons

.buttons_done:
    mov [num_buttons], r12

    ; Parse targets
.find_brace:
    cmp byte [rsi], '{'
    je .parse_targets
    cmp byte [rsi], 0
    je .solve_machine
    inc rsi
    jmp .find_brace

.parse_targets:
    inc rsi
    xor r12, r12

.parse_targets_loop:
    cmp byte [rsi], '}'
    je .targets_done
    cmp byte [rsi], ','
    jne .parse_target_num
    inc rsi
.parse_target_num:
    mov rdi, rsi
    call read_integer
    mov rsi, rdx
    ; Store target in augmented column
    imul rdi, r12, 17*8
    add rdi, 16*8
    mov [matrix + rdi], rax
    mov [targets + r12*8], rax
    inc r12
    jmp .parse_targets_loop

.targets_done:
    inc rsi
    mov [num_targets], r12

.skip_to_eol:
    movzx rax, byte [rsi]
    cmp al, 10
    je .eol_found
    cmp al, 0
    je .solve_machine
    inc rsi
    jmp .skip_to_eol

.eol_found:
    inc rsi

.solve_machine:
    push rsi
    push r15
    call solve_linear_system
    pop r15
    pop rsi
    add r15, rax
    jmp .next_machine

.done:
    mov rdi, r15
    call print_number
    mov rax, 60
    xor rdi, rdi
    syscall

; Solve the linear system using Gaussian elimination
; Returns minimum sum of button presses in rax
solve_linear_system:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 512

    mov r14, [num_targets]
    mov r15, [num_buttons]

    ; Initialize pivot arrays to -1
    mov rcx, 16
    lea rdi, [pivot_col]
.init_pc:
    mov qword [rdi], -1
    add rdi, 8
    dec rcx
    jnz .init_pc

    mov rcx, 16
    lea rdi, [pivot_row]
.init_pr:
    mov qword [rdi], -1
    add rdi, 8
    dec rcx
    jnz .init_pr

    ; Copy matrix to work area (use fractions: num/denom pairs)
    ; We'll work with scaled integers, multiplying by LCM when needed
    ; For simplicity, keep matrix as integers and track denominators

    ; Gaussian elimination
    xor r12, r12                 ; current column
    xor r13, r13                 ; current pivot row

.elim_col:
    cmp r12, r15
    jge .elim_done
    cmp r13, r14
    jge .elim_done

    ; Find pivot in column r12
    mov rbx, r13
.find_pivot:
    cmp rbx, r14
    jge .no_pivot

    imul rdi, rbx, 17*8
    mov rax, r12
    shl rax, 3
    cmp qword [matrix + rdi + rax], 0
    jne .pivot_found
    inc rbx
    jmp .find_pivot

.no_pivot:
    inc r12
    jmp .elim_col

.pivot_found:
    ; Swap rows if needed
    cmp rbx, r13
    je .no_swap

    xor rcx, rcx
.swap_loop:
    cmp rcx, 17
    jge .no_swap

    imul rdi, r13, 17*8
    imul rax, rbx, 17*8
    mov rdx, rcx
    shl rdx, 3

    mov r8, [matrix + rdi + rdx]
    mov r9, [matrix + rax + rdx]
    mov [matrix + rdi + rdx], r9
    mov [matrix + rax + rdx], r8

    inc rcx
    jmp .swap_loop

.no_swap:
    mov [pivot_col + r12*8], r13
    mov [pivot_row + r13*8], r12

    ; Get pivot element
    imul rdi, r13, 17*8
    mov rax, r12
    shl rax, 3
    mov r8, [matrix + rdi + rax]  ; pivot

    ; Eliminate in all other rows
    xor rbx, rbx
.elim_row:
    cmp rbx, r14
    jge .elim_row_done
    cmp rbx, r13
    je .elim_next

    ; Get element to eliminate
    imul rdi, rbx, 17*8
    mov rax, r12
    shl rax, 3
    mov r9, [matrix + rdi + rax]
    test r9, r9
    jz .elim_next

    ; Row operation: row = row * pivot - element * pivot_row
    xor rcx, rcx
.elim_entry:
    cmp rcx, 17
    jge .reduce_row

    imul rdi, rbx, 17*8
    imul rax, r13, 17*8
    mov rdx, rcx
    shl rdx, 3

    mov r10, [matrix + rdi + rdx]
    imul r10, r8
    mov r11, [matrix + rax + rdx]
    imul r11, r9
    sub r10, r11
    mov [matrix + rdi + rdx], r10

    inc rcx
    jmp .elim_entry

.reduce_row:
    ; Reduce row by GCD to prevent overflow
    ; Find GCD of all non-zero elements in the row
    mov rdi, 0                   ; current GCD (0 means not set)
    xor rcx, rcx
.find_gcd_loop:
    cmp rcx, 17
    jge .apply_gcd

    imul rax, rbx, 17*8
    mov rdx, rcx
    shl rdx, 3
    mov r10, [matrix + rax + rdx]
    test r10, r10
    jz .find_gcd_next

    ; Make positive
    mov r11, r10
    neg r11
    cmovs r11, r10               ; r11 = abs(r10)

    ; If GCD not set, set it
    test rdi, rdi
    jz .set_gcd

    ; Compute GCD(rdi, r11) using Euclidean algorithm
    push rcx
    push rbx
    mov rax, rdi
    mov rcx, r11
.gcd_loop:
    test rcx, rcx
    jz .gcd_done
    xor rdx, rdx
    div rcx
    mov rax, rcx
    mov rcx, rdx
    jmp .gcd_loop
.gcd_done:
    mov rdi, rax
    pop rbx
    pop rcx
    jmp .find_gcd_next

.set_gcd:
    mov rdi, r11

.find_gcd_next:
    inc rcx
    jmp .find_gcd_loop

.apply_gcd:
    ; Divide row by GCD if > 1
    cmp rdi, 1
    jle .elim_next

    xor rcx, rcx
.div_gcd_loop:
    cmp rcx, 17
    jge .elim_next

    imul rax, rbx, 17*8
    mov rdx, rcx
    shl rdx, 3
    mov r10, [matrix + rax + rdx]
    push rdx
    mov rax, r10
    cqo
    idiv rdi
    mov r10, rax
    pop rdx
    imul rax, rbx, 17*8
    mov [matrix + rax + rdx], r10

    inc rcx
    jmp .div_gcd_loop

.elim_next:
    inc rbx
    jmp .elim_row

.elim_row_done:
    inc r12
    inc r13
    jmp .elim_col

.elim_done:
    ; Count free variables
    xor r8, r8
    xor r12, r12
.count_free:
    cmp r12, r15
    jge .count_done
    cmp qword [pivot_col + r12*8], -1
    jne .not_free
    mov [free_vars + r8*8], r12
    inc r8
.not_free:
    inc r12
    jmp .count_free

.count_done:
    mov [num_free], r8

    ; No free vars = unique solution
    test r8, r8
    jnz .has_free

    ; Compute unique solution
    xor rax, rax
    xor r12, r12
.unique_loop:
    cmp r12, r14
    jge .return_sum

    mov rcx, [pivot_row + r12*8]
    cmp rcx, -1
    je .unique_next

    imul rdi, r12, 17*8
    mov r8, rcx
    shl r8, 3
    mov r9, [matrix + rdi + r8]   ; pivot
    mov r10, [matrix + rdi + 16*8] ; rhs

    ; Check divisibility
    push rax
    push rdx
    mov rax, r10
    cqo
    idiv r9
    test rdx, rdx
    pop rdx
    jnz .invalid
    test rax, rax
    js .invalid
    mov [solution + rcx*8], rax
    pop rax
    add rax, [solution + rcx*8]
    jmp .unique_next

.invalid:
    pop rax
    mov rax, 999999999
    jmp .return_sum

.unique_next:
    inc r12
    jmp .unique_loop

.has_free:
    ; Initialize best
    mov qword [best_sum], 999999999

    ; Find max target for bounds
    xor r8, r8
    xor rcx, rcx
.find_max:
    cmp rcx, r14
    jge .max_done
    mov rax, [targets + rcx*8]
    cmp rax, r8
    cmovg r8, rax
    inc rcx
    jmp .find_max

.max_done:
    mov [max_target], r8

    ; Enumerate based on number of free vars
    mov rax, [num_free]
    cmp rax, 1
    je .one_free
    cmp rax, 2
    je .two_free
    cmp rax, 3
    je .three_free
    ; More than 3 free vars - give up (shouldn't happen for this input)
    mov rax, 999999999
    jmp .return_sum

.one_free:
    xor r12, r12                 ; value for free var 0
.loop1:
    cmp r12, [max_target]
    jg .done_enum
    mov qword [free_val], r12
    call check_solution
    inc r12
    jmp .loop1

.two_free:
    xor r12, r12
.loop2a:
    cmp r12, [max_target]
    jg .done_enum
    mov qword [free_val], r12
    xor r13, r13
.loop2b:
    cmp r13, [max_target]
    jg .next2a
    mov qword [free_val + 8], r13
    call check_solution
    inc r13
    jmp .loop2b
.next2a:
    inc r12
    jmp .loop2a

.three_free:
    xor r12, r12
.loop3a:
    cmp r12, [max_target]
    jg .done_enum
    mov qword [free_val], r12
    xor r13, r13
.loop3b:
    cmp r13, [max_target]
    jg .next3a
    mov qword [free_val + 8], r13
    xor rbx, rbx
.loop3c:
    cmp rbx, [max_target]
    jg .next3b
    mov qword [free_val + 16], rbx
    push r12
    push r13
    push rbx
    call check_solution
    pop rbx
    pop r13
    pop r12
    inc rbx
    jmp .loop3c
.next3b:
    inc r13
    jmp .loop3b
.next3a:
    inc r12
    jmp .loop3a

.done_enum:
    mov rax, [best_sum]
    jmp .return_sum

.return_sum:
    add rsp, 512
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Check if current free_val produces valid solution, update best_sum
check_solution:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 64

    mov r14, [num_targets]
    mov r15, [num_buttons]

    xor r8, r8                   ; sum of solution
    xor r12, r12                 ; row index
.check_row:
    cmp r12, r14
    jge .check_done

    mov rcx, [pivot_row + r12*8]
    cmp rcx, -1
    je .check_next

    ; Get pivot and rhs
    imul rdi, r12, 17*8
    mov rbx, rcx
    shl rbx, 3
    mov r9, [matrix + rdi + rbx]  ; pivot
    mov r10, [matrix + rdi + 16*8] ; rhs

    ; Subtract free var contributions
    xor rax, rax
.sub_free:
    cmp rax, [num_free]
    jge .compute_basic

    mov r11, [free_vars + rax*8]
    push rdi
    imul rdi, r12, 17*8
    mov rbx, r11
    shl rbx, 3
    mov rbx, [matrix + rdi + rbx]  ; coeff
    pop rdi

    imul rbx, [free_val + rax*8]
    sub r10, rbx

    inc rax
    jmp .sub_free

.compute_basic:
    ; basic_var = r10 / r9
    mov rax, r10
    cqo
    idiv r9
    test rdx, rdx
    jnz .check_fail              ; not integer

    test rax, rax
    js .check_fail               ; negative

    add r8, rax

.check_next:
    inc r12
    jmp .check_row

.check_done:
    ; Add free var values
    xor r12, r12
.add_free:
    cmp r12, [num_free]
    jge .update_best

    add r8, [free_val + r12*8]
    inc r12
    jmp .add_free

.update_best:
    cmp r8, [best_sum]
    jge .check_fail
    mov [best_sum], r8

.check_fail:
    add rsp, 64
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .data
filename: db "../inputs/day10_input.txt", 0

section .bss
file_size: resq 1
num_buttons: resq 1
num_targets: resq 1
targets: resq 16
matrix: resq 16*17
solution: resq 16
pivot_col: resq 16
pivot_row: resq 16
free_vars: resq 16
free_val: resq 16
num_free: resq 1
best_sum: resq 1
max_target: resq 1
