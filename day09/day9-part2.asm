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

    ; Find largest valid rectangle area
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
    mov r8, [points + rax]       ; x_i
    mov r9, [points + rax + 8]   ; y_i

    ; Get point j coords
    mov rax, r13
    shl rax, 4
    mov r10, [points + rax]      ; x_j
    mov r11, [points + rax + 8]  ; y_j

    ; Compute rect bounds: min_x, max_x, min_y, max_y
    ; Store in rect_min_x, rect_max_x, rect_min_y, rect_max_y
    mov rax, r8
    mov rcx, r10
    cmp rax, rcx
    jle .x_ordered
    xchg rax, rcx
.x_ordered:
    mov [rect_min_x], rax
    mov [rect_max_x], rcx

    mov rax, r9
    mov rcx, r11
    cmp rax, rcx
    jle .y_ordered
    xchg rax, rcx
.y_ordered:
    mov [rect_min_y], rax
    mov [rect_max_y], rcx

    ; Check corner C1 = (x_i, y_j)
    mov rdi, r8                  ; x_i
    mov rsi, r11                 ; y_j
    call point_in_polygon
    test rax, rax
    jz .next_pair

    ; Check corner C2 = (x_j, y_i)
    mov rdi, r10                 ; x_j
    mov rsi, r9                  ; y_i
    call point_in_polygon
    test rax, rax
    jz .next_pair

    ; Check no edge crosses rectangle interior
    call check_edges_cross_rect
    test rax, rax
    jz .next_pair

    ; Valid rectangle! Compute area = (dx+1) * (dy+1)
    mov rax, [rect_max_x]
    sub rax, [rect_min_x]
    inc rax                      ; dx + 1

    mov rcx, [rect_max_y]
    sub rcx, [rect_min_y]
    inc rcx                      ; dy + 1

    imul rax, rcx                ; area

    ; Update max if larger
    cmp rax, r15
    cmovg r15, rax

.next_pair:
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

; ============================================
; point_in_polygon: Check if point (px, py) is inside or on polygon boundary
; Input: rdi = px, rsi = py
; Output: rax = 1 if inside/on-boundary, 0 if outside
; Uses ray casting: count vertical edges where edge_x > px and py in y-range
; ============================================
point_in_polygon:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi                 ; r12 = px
    mov r13, rsi                 ; r13 = py
    xor r14, r14                 ; r14 = crossing count
    xor r15, r15                 ; r15 = edge index

.pip_loop:
    cmp r15, [num_points]
    jge .pip_done

    ; Get edge endpoints: p1 = points[r15], p2 = points[(r15+1) % n]
    mov rax, r15
    shl rax, 4
    mov r8, [points + rax]       ; p1.x
    mov r9, [points + rax + 8]   ; p1.y

    mov rax, r15
    inc rax
    xor rdx, rdx
    div qword [num_points]       ; rax = (r15+1) / n, rdx = (r15+1) % n
    mov rax, rdx
    shl rax, 4
    mov r10, [points + rax]      ; p2.x
    mov r11, [points + rax + 8]  ; p2.y

    ; Check if point is on this edge
    ; First check if it's a horizontal edge (p1.y == p2.y)
    cmp r9, r11
    jne .check_vertical_edge

    ; Horizontal edge: check if py == edge_y and px in [min_x, max_x]
    cmp r13, r9
    jne .pip_next

    ; Check px in x-range
    mov rax, r8
    mov rcx, r10
    cmp rax, rcx
    jle .h_ordered
    xchg rax, rcx
.h_ordered:
    ; rax = min_x, rcx = max_x
    cmp r12, rax
    jl .pip_next
    cmp r12, rcx
    jg .pip_next
    ; Point is on horizontal edge
    mov rax, 1
    jmp .pip_return

.check_vertical_edge:
    ; Vertical edge: p1.x == p2.x
    cmp r8, r10
    jne .pip_next                ; Not vertical (shouldn't happen for rectilinear)

    ; Check if point is on this vertical edge
    cmp r12, r8
    jne .check_crossing

    ; px == edge_x, check if py in y-range
    mov rax, r9
    mov rcx, r11
    cmp rax, rcx
    jle .v_on_ordered
    xchg rax, rcx
.v_on_ordered:
    cmp r13, rax
    jl .check_crossing
    cmp r13, rcx
    jg .check_crossing
    ; Point is on vertical edge
    mov rax, 1
    jmp .pip_return

.check_crossing:
    ; Check if ray from (px, py) going right crosses this vertical edge
    ; Condition: edge_x > px AND py strictly between edge y-values
    cmp r8, r12                  ; edge_x > px?
    jle .pip_next

    ; Check py strictly in (min_y, max_y)
    mov rax, r9
    mov rcx, r11
    cmp rax, rcx
    jle .v_cross_ordered
    xchg rax, rcx
.v_cross_ordered:
    ; rax = min_y, rcx = max_y
    cmp r13, rax
    jle .pip_next                ; py <= min_y
    cmp r13, rcx
    jge .pip_next                ; py >= max_y

    ; Ray crosses this edge
    inc r14

.pip_next:
    inc r15
    jmp .pip_loop

.pip_done:
    ; Odd crossings = inside
    mov rax, r14
    and rax, 1                   ; rax = 1 if odd, 0 if even

.pip_return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================
; check_edges_cross_rect: Check if any edge crosses rectangle interior
; Uses globals: rect_min_x, rect_max_x, rect_min_y, rect_max_y
; Output: rax = 1 if no edge crosses (valid), 0 if some edge crosses (invalid)
; ============================================
check_edges_cross_rect:
    push rbx
    push r12
    push r13
    push r14
    push r15

    xor r15, r15                 ; r15 = edge index

.cer_loop:
    cmp r15, [num_points]
    jge .cer_valid

    ; Get edge endpoints
    mov rax, r15
    shl rax, 4
    mov r8, [points + rax]       ; p1.x
    mov r9, [points + rax + 8]   ; p1.y

    mov rax, r15
    inc rax
    xor rdx, rdx
    div qword [num_points]
    mov rax, rdx
    shl rax, 4
    mov r10, [points + rax]      ; p2.x
    mov r11, [points + rax + 8]  ; p2.y

    ; Check if horizontal edge (p1.y == p2.y)
    cmp r9, r11
    jne .check_vert_cross

    ; Horizontal edge at y = r9
    ; Crosses interior if: min_y < r9 < max_y AND x-ranges overlap
    mov rax, [rect_min_y]
    cmp r9, rax
    jle .cer_next                ; edge_y <= min_y
    mov rax, [rect_max_y]
    cmp r9, rax
    jge .cer_next                ; edge_y >= max_y

    ; Check x-range overlap: edge [min(p1.x,p2.x), max(p1.x,p2.x)] vs rect [min_x, max_x]
    mov rax, r8
    mov rcx, r10
    cmp rax, rcx
    jle .h_cross_ordered
    xchg rax, rcx
.h_cross_ordered:
    ; rax = edge_min_x, rcx = edge_max_x
    mov rdx, [rect_max_x]
    cmp rax, rdx
    jge .cer_next                ; edge_min_x >= rect_max_x (no overlap)
    mov rdx, [rect_min_x]
    cmp rcx, rdx
    jle .cer_next                ; edge_max_x <= rect_min_x (no overlap)

    ; Edge crosses interior - invalid
    xor rax, rax
    jmp .cer_return

.check_vert_cross:
    ; Vertical edge at x = r8 (assuming p1.x == p2.x)
    cmp r8, r10
    jne .cer_next                ; Not vertical (shouldn't happen)

    ; Crosses interior if: min_x < r8 < max_x AND y-ranges overlap
    mov rax, [rect_min_x]
    cmp r8, rax
    jle .cer_next                ; edge_x <= min_x
    mov rax, [rect_max_x]
    cmp r8, rax
    jge .cer_next                ; edge_x >= max_x

    ; Check y-range overlap
    mov rax, r9
    mov rcx, r11
    cmp rax, rcx
    jle .v_cross_ordered
    xchg rax, rcx
.v_cross_ordered:
    ; rax = edge_min_y, rcx = edge_max_y
    mov rdx, [rect_max_y]
    cmp rax, rdx
    jge .cer_next                ; edge_min_y >= rect_max_y
    mov rdx, [rect_min_y]
    cmp rcx, rdx
    jle .cer_next                ; edge_max_y <= rect_min_y

    ; Edge crosses interior - invalid
    xor rax, rax
    jmp .cer_return

.cer_next:
    inc r15
    jmp .cer_loop

.cer_valid:
    mov rax, 1

.cer_return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .data
filename: db "../inputs/day9_input.txt", 0

section .bss
file_size: resq 1
num_points: resq 1
rect_min_x: resq 1
rect_max_x: resq 1
rect_min_y: resq 1
rect_max_y: resq 1
points: resq 2 * 10001          ; up to 10001 points * 2 coords
