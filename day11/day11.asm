extern read_file
extern print_number
extern input_buffer

section .text
global _start

; Day 11: Count all paths from "you" to "out"
; Uses DFS with memoization: count[node] = sum(count[neighbors]), count["out"] = 1

_start:
    mov rdi, filename
    call read_file
    mov [file_size], rax

    ; Initialize hash table to -1 (empty)
    lea rdi, [hash_table]
    mov rcx, HASH_SIZE
    mov rax, -1
.init_hash:
    mov qword [rdi], rax
    add rdi, 8
    dec rcx
    jnz .init_hash

    ; Initialize path_count to -1 (uncomputed)
    lea rdi, [path_count]
    mov rcx, MAX_NODES
    mov rax, -1
.init_paths:
    mov qword [rdi], rax
    add rdi, 8
    dec rcx
    jnz .init_paths

    xor r15, r15                    ; r15 = node count
    mov rsi, input_buffer

    ; Parse all lines
.parse_line:
    mov rax, rsi
    sub rax, input_buffer
    cmp rax, [file_size]
    jge .parsing_done

    ; Skip whitespace/newlines
    movzx rax, byte [rsi]
    cmp al, 10
    je .skip_ws
    cmp al, 13
    je .skip_ws
    cmp al, ' '
    je .skip_ws
    cmp al, 0
    je .parsing_done
    jmp .parse_source

.skip_ws:
    inc rsi
    jmp .parse_line

.parse_source:
    ; Read source node name (3 chars before ':')
    mov eax, [rsi]                  ; load 4 bytes (3 chars + ':' or space)
    and eax, 0x00FFFFFF             ; mask to 3 chars
    mov [current_name], eax
    add rsi, 3

    ; Get or create node index for source
    mov edi, eax
    call get_or_create_node
    mov r12, rax                    ; r12 = source node index

    ; Skip to ':' then past it
.find_colon:
    cmp byte [rsi], ':'
    je .found_colon
    inc rsi
    jmp .find_colon
.found_colon:
    inc rsi                         ; skip ':'

    ; Initialize edge count for this source
    imul rdi, r12, MAX_EDGES*8
    mov qword [adj_count + r12*8], 0

    ; Parse destinations
.parse_dest:
    ; Skip spaces
    cmp byte [rsi], ' '
    jne .check_dest_end
    inc rsi
    jmp .parse_dest

.check_dest_end:
    movzx rax, byte [rsi]
    cmp al, 10
    je .line_done
    cmp al, 13
    je .line_done
    cmp al, 0
    je .line_done

    ; Read destination name (3 chars)
    mov eax, [rsi]
    and eax, 0x00FFFFFF
    add rsi, 3

    ; Get or create node index for destination
    mov edi, eax
    push r12
    call get_or_create_node
    mov r13, rax                    ; r13 = dest node index
    pop r12

    ; Add edge: adj_list[source][count] = dest
    mov rcx, [adj_count + r12*8]
    imul rdi, r12, MAX_EDGES*8
    mov [adj_list + rdi + rcx*8], r13
    inc qword [adj_count + r12*8]

    jmp .parse_dest

.line_done:
    inc rsi
    jmp .parse_line

.parsing_done:
    mov [node_count], r15

    ; Find "you" and "out" indices
    mov edi, 'you'                  ; packed as 3 bytes
    call find_node
    mov [you_idx], rax

    mov edi, 'out'
    call find_node
    mov [out_idx], rax

    ; Set path_count[out] = 1
    mov rax, [out_idx]
    mov qword [path_count + rax*8], 1

    ; Call count_paths(you_idx)
    mov rdi, [you_idx]
    call count_paths

    ; Print result
    mov rdi, rax
    call print_number

    ; Exit
    mov rax, 60
    xor rdi, rdi
    syscall

; Get or create node index for name in edi (3-byte packed name)
; Returns index in rax
get_or_create_node:
    push rbx
    push r12

    mov r12d, edi                   ; save name

    ; Hash: simple modulo
    mov eax, edi
    xor edx, edx
    mov ecx, HASH_SIZE
    div ecx
    mov ebx, edx                    ; ebx = hash bucket

    ; Linear probe to find or insert
.probe:
    mov rax, [hash_table + rbx*8]
    cmp rax, -1
    je .insert_new

    ; Check if names match
    mov ecx, [node_names + rax*4]
    cmp ecx, r12d
    je .found

    ; Collision - linear probe
    inc ebx
    cmp ebx, HASH_SIZE
    jb .probe
    xor ebx, ebx
    jmp .probe

.insert_new:
    ; Create new node
    mov rax, r15                    ; new index = node_count
    mov [hash_table + rbx*8], rax
    mov [node_names + rax*4], r12d
    mov qword [adj_count + rax*8], 0
    inc r15                         ; increment node_count

.found:
    pop r12
    pop rbx
    ret

; Find node index for name in edi
; Returns index in rax (-1 if not found)
find_node:
    push rbx

    mov ebx, edi                    ; save name

    ; Search through all nodes
    xor rax, rax
.search:
    cmp rax, r15
    jge .not_found

    cmp [node_names + rax*4], ebx
    je .done

    inc rax
    jmp .search

.not_found:
    mov rax, -1
.done:
    pop rbx
    ret

; count_paths(node_idx in rdi)
; Returns count in rax
; Uses memoization - path_count[node] cached
count_paths:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14

    mov r12, rdi                    ; r12 = node index

    ; Check cache
    mov rax, [path_count + r12*8]
    cmp rax, -1
    jne .return_cached

    ; Sum paths through all neighbors
    xor r13, r13                    ; r13 = sum
    xor r14, r14                    ; r14 = neighbor index

    mov rbx, [adj_count + r12*8]    ; rbx = edge count

.sum_neighbors:
    cmp r14, rbx
    jge .done_sum

    ; Get neighbor index
    imul rdi, r12, MAX_EDGES*8
    mov rdi, [adj_list + rdi + r14*8]

    ; Recursive call
    call count_paths
    add r13, rax

    inc r14
    jmp .sum_neighbors

.done_sum:
    ; Cache result
    mov [path_count + r12*8], r13
    mov rax, r13

.return_cached:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .data
filename: db "../inputs/day11_input.txt", 0

section .bss
HASH_SIZE equ 2048
MAX_NODES equ 1024
MAX_EDGES equ 32

file_size: resq 1
node_count: resq 1
you_idx: resq 1
out_idx: resq 1
current_name: resd 1

hash_table: resq HASH_SIZE          ; hash -> node index
node_names: resd MAX_NODES          ; node index -> packed 3-char name
adj_list: resq MAX_NODES * MAX_EDGES ; adjacency list
adj_count: resq MAX_NODES           ; edge count per node
path_count: resq MAX_NODES          ; memoized path counts
