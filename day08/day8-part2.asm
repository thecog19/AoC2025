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

    ; Parse all points
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
    mov rsi, rdx

    ; Store X
    mov rcx, r12
    imul rcx, 24
    mov [points + rcx], rax

    ; Skip comma
    inc rsi

    ; Parse Y coordinate
    mov rdi, rsi
    call read_integer
    mov rsi, rdx

    ; Store Y
    mov rcx, r12
    imul rcx, 24
    mov [points + rcx + 8], rax

    ; Skip comma
    inc rsi

    ; Parse Z coordinate
    mov rdi, rsi
    call read_integer
    mov rsi, rdx

    ; Store Z
    mov rcx, r12
    imul rcx, 24
    mov [points + rcx + 16], rax

    inc r12
    jmp .parse_loop

.skip_char:
    inc rsi
    jmp .parse_loop

.parse_done:
    mov [num_points], r12

    ; Allocate memory for pairs using mmap
    mov rax, 9                   ; mmap syscall
    xor rdi, rdi                 ; addr = NULL
    mov rsi, 16 * 500000         ; length = 8MB
    mov rdx, 3                   ; PROT_READ | PROT_WRITE
    mov r10, 0x22                ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1                   ; fd = -1
    xor r9, r9                   ; offset = 0
    syscall
    mov [pairs_ptr], rax

    ; Generate all pairs with distances
    xor r12, r12                 ; r12 = i
    xor r15, r15                 ; r15 = pair count

.gen_outer:
    mov rax, [num_points]
    dec rax
    cmp r12, rax
    jge .gen_done

    mov r13, r12
    inc r13                      ; r13 = j = i + 1

.gen_inner:
    cmp r13, [num_points]
    jge .gen_next_i

    ; Calculate distance squared between points i and j
    mov rax, r12
    imul rax, 24
    mov r8, [points + rax]       ; x1
    mov r9, [points + rax + 8]   ; y1
    mov r10, [points + rax + 16] ; z1

    mov rax, r13
    imul rax, 24
    mov r11, [points + rax]      ; x2
    mov rcx, [points + rax + 8]  ; y2
    mov rdx, [points + rax + 16] ; z2

    ; dx = x2 - x1
    sub r11, r8
    mov rax, r11
    imul rax, r11
    mov rbx, rax                 ; rbx = dist²

    ; dy = y2 - y1
    sub rcx, r9
    mov rax, rcx
    imul rax, rcx
    add rbx, rax

    ; dz = z2 - z1
    sub rdx, r10
    mov rax, rdx
    imul rax, rdx
    add rbx, rax

    ; Store pair: (dist², i, j)
    mov rax, [pairs_ptr]
    mov rcx, r15
    imul rcx, 16
    add rax, rcx

    mov [rax], rbx               ; distance²
    mov [rax + 8], r12d          ; i (32-bit)
    mov [rax + 12], r13d         ; j (32-bit)

    inc r15
    inc r13
    jmp .gen_inner

.gen_next_i:
    inc r12
    jmp .gen_outer

.gen_done:
    mov [num_pairs], r15

    ; Sort pairs by distance (quicksort)
    mov rdi, 0
    mov rsi, r15
    dec rsi
    call quicksort

    ; Initialize Union-Find parent array
    xor rcx, rcx
.init_uf:
    cmp rcx, [num_points]
    jge .init_uf_done
    mov [parent + rcx*8], rcx    ; parent[i] = i
    inc rcx
    jmp .init_uf
.init_uf_done:

    ; Initialize circuits counter = num_points
    mov rax, [num_points]
    mov [circuits], rax

    ; Connect pairs until all in one circuit
    xor r12, r12                 ; r12 = pair index

.connect_loop:
    cmp r12, [num_pairs]
    jge .connect_done            ; shouldn't happen, but safety

    ; Get pair[r12]
    mov rax, [pairs_ptr]
    mov rcx, r12
    imul rcx, 16
    add rax, rcx

    mov r14d, [rax + 8]          ; i
    mov r15d, [rax + 12]         ; j

    ; Check if find(i) != find(j)
    mov edi, r14d
    call find_root
    mov rbx, rax                 ; rbx = root of i

    mov edi, r15d
    call find_root               ; rax = root of j

    cmp rax, rbx
    je .skip_pair                ; same circuit, skip

    ; Different circuits - union them
    mov [parent + rbx*8], rax    ; parent[root_i] = root_j
    dec qword [circuits]         ; one less circuit

    ; Check if we're down to 1 circuit
    cmp qword [circuits], 1
    je .found_last

.skip_pair:
    inc r12
    jmp .connect_loop

.found_last:
    ; Last connection was between points r14 and r15
    ; Get X coordinates and multiply
    mov eax, r14d
    imul rax, 24
    mov r13, [points + rax]      ; X of point i

    mov eax, r15d
    imul rax, 24
    mov rax, [points + rax]      ; X of point j

    imul rax, r13                ; X_i * X_j

    mov rdi, rax
    call print_number

    jmp .exit

.connect_done:
    ; Should never reach here
    mov rdi, 0
    call print_number

.exit:
    mov rax, 60
    xor rdi, rdi
    syscall

; ============================================
; find_root: Find root of node with path compression
; Input: rdi = node
; Output: rax = root
; ============================================
find_root:
    mov rax, rdi
.find_loop:
    mov rcx, [parent + rax*8]
    cmp rcx, rax
    je .find_done
    mov rdx, [parent + rcx*8]
    mov [parent + rax*8], rdx
    mov rax, rcx
    jmp .find_loop
.find_done:
    ret

; ============================================
; quicksort: Sort pairs array by distance
; Input: rdi = left, rsi = right
; ============================================
quicksort:
    cmp rdi, rsi
    jge .qs_done

    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi                 ; left
    mov r13, rsi                 ; right

    ; Pivot = pairs[right].distance
    mov rax, [pairs_ptr]
    mov rcx, r13
    imul rcx, 16
    add rax, rcx
    mov r14, [rax]               ; pivot distance

    mov r15, r12                 ; i = left
    mov rbx, r12                 ; j = left

.partition_loop:
    cmp rbx, r13
    jge .partition_done

    mov rax, [pairs_ptr]
    mov rcx, rbx
    imul rcx, 16
    add rax, rcx
    mov rdx, [rax]               ; pairs[j].distance

    cmp rdx, r14
    jge .no_swap

    mov rdi, r15
    mov rsi, rbx
    call swap_pairs
    inc r15

.no_swap:
    inc rbx
    jmp .partition_loop

.partition_done:
    mov rdi, r15
    mov rsi, r13
    call swap_pairs

    mov rdi, r12
    mov rsi, r15
    dec rsi
    call quicksort

    mov rdi, r15
    inc rdi
    mov rsi, r13
    call quicksort

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx

.qs_done:
    ret

; ============================================
; swap_pairs: Swap two pairs
; Input: rdi = index1, rsi = index2
; ============================================
swap_pairs:
    mov rax, [pairs_ptr]

    mov rcx, rdi
    imul rcx, 16
    add rcx, rax

    mov rdx, rsi
    imul rdx, 16
    add rdx, rax

    mov r8, [rcx]
    mov r9, [rcx + 8]
    mov r10, [rdx]
    mov r11, [rdx + 8]
    mov [rcx], r10
    mov [rcx + 8], r11
    mov [rdx], r8
    mov [rdx + 8], r9

    ret

section .data
filename: db "../inputs/day8_input.txt", 0

section .bss
file_size: resq 1
num_points: resq 1
num_pairs: resq 1
pairs_ptr: resq 1
circuits: resq 1
points: resq 3 * 1001
parent: resq 1001
