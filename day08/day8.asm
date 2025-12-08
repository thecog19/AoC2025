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
    mov rsi, rdx                 ; rdx = pointer after number

    ; Store X
    mov rcx, r12
    imul rcx, 24                 ; 3 qwords per point
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

    inc r12                      ; Next point
    jmp .parse_loop

.skip_char:
    inc rsi
    jmp .parse_loop

.parse_done:
    mov [num_points], r12

    ; Allocate memory for pairs using mmap
    ; Max pairs = n*(n-1)/2 = 1000*999/2 = 499500
    ; Each pair = 16 bytes (8 for dist², 4 for i, 4 for j)
    ; Total = ~8MB
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
    ; Get point i coords
    mov rax, r12
    imul rax, 24
    mov r8, [points + rax]       ; x1
    mov r9, [points + rax + 8]   ; y1
    mov r10, [points + rax + 16] ; z1

    ; Get point j coords
    mov rax, r13
    imul rax, 24
    mov r11, [points + rax]      ; x2
    mov rcx, [points + rax + 8]  ; y2
    mov rdx, [points + rax + 16] ; z2

    ; dx = x2 - x1
    sub r11, r8
    mov rax, r11
    imul rax, r11                ; dx²

    mov rbx, rax                 ; rbx = dist²

    ; dy = y2 - y1
    sub rcx, r9
    mov rax, rcx
    imul rax, rcx                ; dy²
    add rbx, rax

    ; dz = z2 - z1
    sub rdx, r10
    mov rax, rdx
    imul rax, rdx                ; dz²
    add rbx, rax

    ; Store pair: (dist², i, j)
    mov rax, [pairs_ptr]
    mov rcx, r15
    imul rcx, 16                 ; 16 bytes per pair
    add rax, rcx

    mov [rax], rbx               ; distance²
    mov [rax + 8], r12d          ; i (32-bit)
    mov [rax + 12], r13d         ; j (32-bit)

    inc r15                      ; pair count++
    inc r13
    jmp .gen_inner

.gen_next_i:
    inc r12
    jmp .gen_outer

.gen_done:
    mov [num_pairs], r15

    ; Sort pairs by distance (quicksort)
    mov rdi, 0                   ; left = 0
    mov rsi, r15
    dec rsi                      ; right = num_pairs - 1
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

    ; Connect top K pairs (10 for test, 1000 for real)
    mov r12, [num_points]
    cmp r12, 100
    jl .use_small_k
    mov r14, 1000                ; K = 1000 for large input
    jmp .connect_pairs
.use_small_k:
    mov r14, 10                  ; K = 10 for test input

.connect_pairs:
    xor r12, r12                 ; r12 = connection counter

.connect_loop:
    cmp r12, r14
    jge .connect_done

    ; Get pair[r12]
    mov rax, [pairs_ptr]
    mov rcx, r12
    imul rcx, 16
    add rax, rcx

    mov edi, [rax + 8]           ; i
    mov esi, [rax + 12]          ; j

    ; Union(i, j)
    call union_sets

    inc r12
    jmp .connect_loop

.connect_done:
    ; Count circuit sizes
    ; First clear sizes array
    xor rcx, rcx
.clear_sizes:
    cmp rcx, [num_points]
    jge .clear_sizes_done
    mov qword [sizes + rcx*8], 0
    inc rcx
    jmp .clear_sizes
.clear_sizes_done:

    ; For each node, find root and increment size
    xor r12, r12
.count_sizes:
    cmp r12, [num_points]
    jge .count_sizes_done

    mov rdi, r12
    call find_root
    inc qword [sizes + rax*8]

    inc r12
    jmp .count_sizes
.count_sizes_done:

    ; Find top 3 sizes
    xor r13, r13                 ; max1
    xor r14, r14                 ; max2
    xor r15, r15                 ; max3

    xor r12, r12
.find_max:
    cmp r12, [num_points]
    jge .find_max_done

    mov rax, [sizes + r12*8]

    cmp rax, r13
    jle .check_max2
    ; New max1
    mov r15, r14                 ; max3 = max2
    mov r14, r13                 ; max2 = max1
    mov r13, rax                 ; max1 = new
    jmp .next_max

.check_max2:
    cmp rax, r14
    jle .check_max3
    ; New max2
    mov r15, r14                 ; max3 = max2
    mov r14, rax                 ; max2 = new
    jmp .next_max

.check_max3:
    cmp rax, r15
    jle .next_max
    ; New max3
    mov r15, rax

.next_max:
    inc r12
    jmp .find_max

.find_max_done:
    ; Multiply top 3: r13 * r14 * r15
    mov rax, r13
    imul rax, r14
    imul rax, r15

    mov rdi, rax
    call print_number

    ; Exit
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
    ; Path compression: parent[rax] = parent[parent[rax]]
    mov rdx, [parent + rcx*8]
    mov [parent + rax*8], rdx
    mov rax, rcx
    jmp .find_loop
.find_done:
    ret

; ============================================
; union_sets: Union two sets
; Input: edi = node1, esi = node2
; ============================================
union_sets:
    push rbx

    ; Find roots
    mov edi, edi                 ; zero-extend edi to rdi
    call find_root
    mov rbx, rax                 ; rbx = root1

    mov edi, esi                 ; zero-extend esi to rdi
    call find_root               ; rax = root2

    ; If same root, nothing to do
    cmp rax, rbx
    je .union_done

    ; Make root1 point to root2
    mov [parent + rbx*8], rax

.union_done:
    pop rbx
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

    ; if pairs[j].distance < pivot
    mov rax, [pairs_ptr]
    mov rcx, rbx
    imul rcx, 16
    add rax, rcx
    mov rdx, [rax]               ; pairs[j].distance

    cmp rdx, r14
    jge .no_swap

    ; Swap pairs[i] and pairs[j]
    mov rdi, r15
    mov rsi, rbx
    call swap_pairs
    inc r15                      ; i++

.no_swap:
    inc rbx                      ; j++
    jmp .partition_loop

.partition_done:
    ; Swap pairs[i] and pairs[right]
    mov rdi, r15
    mov rsi, r13
    call swap_pairs

    ; Recursively sort left partition
    mov rdi, r12
    mov rsi, r15
    dec rsi
    call quicksort

    ; Recursively sort right partition
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
    add rcx, rax                 ; rcx = &pairs[index1]

    mov rdx, rsi
    imul rdx, 16
    add rdx, rax                 ; rdx = &pairs[index2]

    ; Swap 16 bytes
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
points: resq 3 * 1001           ; 1001 points * 3 coords
parent: resq 1001               ; Union-Find parent array
sizes: resq 1001                ; Circuit sizes
