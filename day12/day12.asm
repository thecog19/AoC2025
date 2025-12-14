extern read_file
extern read_integer
extern print_number
extern input_buffer

section .text
global _start

; Day 12: Christmas Tree Farm
; Polyomino packing - check if all required pieces fit in each region

_start:
    ; Read input file
    mov rdi, filename
    call read_file
    mov [file_size], rax

    ; Parse shape definitions first
    mov rsi, input_buffer
    call parse_shapes

    ; Now parse and solve each region
    ; rsi points past shape definitions now
    xor r15, r15                    ; r15 = count of successful regions

.next_region:
    ; Check if we've reached end of file
    mov rax, rsi
    sub rax, input_buffer
    cmp rax, [file_size]
    jge .done

    ; Skip whitespace
    movzx rax, byte [rsi]
    cmp al, ' '
    je .skip_ws
    cmp al, 10
    je .skip_ws
    cmp al, 13
    je .skip_ws
    cmp al, 0
    je .done

    ; Check if it's a digit (start of region definition)
    cmp al, '0'
    jb .skip_ws
    cmp al, '9'
    ja .skip_ws
    jmp .parse_region

.skip_ws:
    inc rsi
    jmp .next_region

.parse_region:
    ; Parse WxH: count0 count1 count2 count3 count4 count5
    ; Parse width
    mov rdi, rsi
    call read_integer
    mov [region_width], rax
    mov rsi, rdx

    ; Skip 'x'
    inc rsi

    ; Parse height
    mov rdi, rsi
    call read_integer
    mov [region_height], rax
    mov rsi, rdx

    ; Skip ':'
.skip_to_counts:
    cmp byte [rsi], ':'
    je .found_colon
    inc rsi
    jmp .skip_to_counts
.found_colon:
    inc rsi

    ; Parse 6 piece counts
    xor rcx, rcx                    ; shape index
.parse_counts:
    cmp rcx, 6
    jge .counts_done

    ; Skip spaces
.skip_spaces:
    cmp byte [rsi], ' '
    jne .read_count
    inc rsi
    jmp .skip_spaces

.read_count:
    mov rdi, rsi
    push rcx
    call read_integer
    pop rcx
    mov [pieces_needed + rcx*8], rax
    mov rsi, rdx
    inc rcx
    jmp .parse_counts

.counts_done:
    ; Skip to end of line
.skip_to_eol:
    movzx rax, byte [rsi]
    cmp al, 10
    je .eol_found
    cmp al, 0
    je .solve_region
    inc rsi
    jmp .skip_to_eol
.eol_found:
    inc rsi

.solve_region:
    ; Save rsi
    push rsi

    ; Calculate total cells needed and skips allowed
    xor rax, rax
    xor rcx, rcx
.calc_total:
    cmp rcx, 6
    jge .calc_done
    mov rbx, [pieces_needed + rcx*8]
    imul rbx, [shape_cell_counts + rcx*8]
    add rax, rbx
    inc rcx
    jmp .calc_total
.calc_done:
    mov [total_cells_needed], rax

    ; Calculate grid size and skips allowed
    mov rbx, [region_width]
    imul rbx, [region_height]
    mov [grid_size], rbx
    sub rbx, rax                        ; skips_allowed = grid_size - total_cells
    jl .region_fail                     ; fail if negative
    mov [skips_allowed], rbx

    ; Clear the grid
    call clear_grid

    ; Try to solve
    call solve
    test rax, rax
    jz .region_fail

    ; Success!
    inc r15

.region_fail:
    pop rsi
    jmp .next_region

.done:
    ; Print result
    mov rdi, r15
    call print_number

    ; Exit
    mov rax, 60
    xor rdi, rdi
    syscall

; ============================================================
; parse_shapes: Parse the 6 shape definitions
; Input: rsi = pointer to start of input
; Output: rsi = pointer past shape definitions
;         shape data stored in shape_cells
; ============================================================
parse_shapes:
    push rbx
    push r12
    push r13
    push r14

    xor r12, r12                    ; r12 = shape index

.parse_next_shape:
    cmp r12, 6
    jge .shapes_done

    ; Skip to shape index digit
.find_digit:
    movzx rax, byte [rsi]
    cmp al, '0'
    jb .skip_char
    cmp al, '9'
    ja .skip_char
    jmp .found_shape_start
.skip_char:
    inc rsi
    jmp .find_digit

.found_shape_start:
    ; Skip "N:" part
.skip_header:
    cmp byte [rsi], 10
    je .header_done
    inc rsi
    jmp .skip_header
.header_done:
    inc rsi                         ; skip newline

    ; Parse 3 rows of shape
    xor r13, r13                    ; r13 = cell count for this shape
    xor r14, r14                    ; r14 = row

.parse_shape_row:
    cmp r14, 3
    jge .shape_done

    xor rbx, rbx                    ; rbx = column
.parse_shape_col:
    cmp rbx, 3
    jge .row_done

    movzx rax, byte [rsi]
    inc rsi

    cmp al, '#'
    jne .not_cell

    ; Store cell offset (row, col) for this shape
    ; shape_cells[shape_idx][cell_idx] = (row << 8) | col
    imul rax, r12, MAX_CELLS_PER_SHAPE * 2
    add rax, r13
    add rax, r13                    ; rax = shape_idx * MAX_CELLS * 2 + cell_idx * 2
    mov byte [shape_cells + rax], r14b      ; row
    mov byte [shape_cells + rax + 1], bl    ; col
    inc r13

.not_cell:
    inc rbx
    jmp .parse_shape_col

.row_done:
    ; Skip line endings (handle both CRLF and LF)
.skip_line_ending:
    cmp byte [rsi], 13       ; CR
    je .skip_eol_char
    cmp byte [rsi], 10       ; LF
    je .skip_eol_char
    jmp .line_ending_done
.skip_eol_char:
    inc rsi
    jmp .skip_line_ending
.line_ending_done:
    inc r14
    jmp .parse_shape_row

.shape_done:
    ; Store cell count for this shape
    mov [shape_cell_counts + r12*8], r13

    ; Generate all orientations for this shape
    mov rdi, r12
    call generate_orientations

    inc r12
    jmp .parse_next_shape

.shapes_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================
; generate_orientations: Generate all 8 rotations/flips for a shape
; Input: rdi = shape index
; ============================================================
generate_orientations:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    sub rsp, 64                     ; local storage

    mov r12, rdi                    ; r12 = shape index
    mov r13, [shape_cell_counts + r12*8]  ; r13 = cell count

    ; Copy original cells to temp buffer
    xor rcx, rcx
.copy_original:
    cmp rcx, r13
    jge .copy_done
    imul rax, r12, MAX_CELLS_PER_SHAPE * 2
    lea rax, [shape_cells + rax + rcx*2]
    movzx rbx, byte [rax]           ; row
    movzx r14, byte [rax + 1]       ; col
    mov [rbp - 32 + rcx*2], bl      ; temp row
    mov [rbp - 32 + rcx*2 + 1], r14b ; temp col
    inc rcx
    jmp .copy_original
.copy_done:

    ; Store orientation 0 (original)
    xor rcx, rcx
    mov r15, 0                      ; orientation index
    call store_orientation

    ; Generate 3 more rotations (90, 180, 270)
    mov r14, 3                      ; 3 more rotations
.rotate_loop:
    ; Rotate all cells 90 CW: (r,c) -> (c, 2-r)
    xor rcx, rcx
.rotate_cells:
    cmp rcx, r13
    jge .rotate_done
    movzx rax, byte [rbp - 32 + rcx*2]      ; old row
    movzx rbx, byte [rbp - 32 + rcx*2 + 1]  ; old col
    ; new_row = old_col, new_col = 2 - old_row
    mov r8, rbx                     ; new row = old col
    mov r9, 2
    sub r9, rax                     ; new col = 2 - old row
    mov [rbp - 32 + rcx*2], r8b
    mov [rbp - 32 + rcx*2 + 1], r9b
    inc rcx
    jmp .rotate_cells
.rotate_done:
    inc r15
    call store_orientation
    dec r14
    jnz .rotate_loop

    ; Now flip and do 4 more orientations
    ; First, get original shape back
    xor rcx, rcx
.copy_original2:
    cmp rcx, r13
    jge .copy_done2
    imul rax, r12, MAX_CELLS_PER_SHAPE * 2
    lea rax, [shape_cells + rax + rcx*2]
    movzx rbx, byte [rax]           ; row
    movzx r8, byte [rax + 1]        ; col
    mov [rbp - 32 + rcx*2], bl
    mov [rbp - 32 + rcx*2 + 1], r8b
    inc rcx
    jmp .copy_original2
.copy_done2:

    ; Flip horizontally: (r,c) -> (r, 2-c)
    xor rcx, rcx
.flip_cells:
    cmp rcx, r13
    jge .flip_done
    movzx rax, byte [rbp - 32 + rcx*2 + 1]  ; old col
    mov rbx, 2
    sub rbx, rax                    ; new col = 2 - old col
    mov [rbp - 32 + rcx*2 + 1], bl
    inc rcx
    jmp .flip_cells
.flip_done:

    ; Store flipped orientation
    inc r15                         ; r15 = 4 (orient 0-3 already stored)
    call store_orientation

    ; Generate 3 more rotations of flipped
    mov r14, 3
.rotate_loop2:
    xor rcx, rcx
.rotate_cells2:
    cmp rcx, r13
    jge .rotate_done2
    movzx rax, byte [rbp - 32 + rcx*2]
    movzx rbx, byte [rbp - 32 + rcx*2 + 1]
    mov r8, rbx
    mov r9, 2
    sub r9, rax
    mov [rbp - 32 + rcx*2], r8b
    mov [rbp - 32 + rcx*2 + 1], r9b
    inc rcx
    jmp .rotate_cells2
.rotate_done2:
    inc r15
    call store_orientation
    dec r14
    jnz .rotate_loop2

    mov rsp, rbp
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; store_orientation: Store current temp cells as orientation r15
; Normalizes cells so minimum row/col is 0
store_orientation:
    push rax
    push rbx
    push rcx
    push rdx
    push r8
    push r9

    ; Find min row and min col
    mov r8, 255                     ; min row
    mov r9, 255                     ; min col
    xor rcx, rcx
.find_min:
    cmp rcx, r13
    jge .found_min
    movzx rax, byte [rbp - 32 + rcx*2]
    movzx rbx, byte [rbp - 32 + rcx*2 + 1]
    cmp rax, r8
    cmovb r8, rax
    cmp rbx, r9
    cmovb r9, rbx
    inc rcx
    jmp .find_min
.found_min:

    ; Store normalized cells
    ; all_orientations[shape][orient][cell] = (row-min_row, col-min_col)
    xor rcx, rcx
.store_cells:
    cmp rcx, r13
    jge .store_done
    movzx rax, byte [rbp - 32 + rcx*2]
    movzx rbx, byte [rbp - 32 + rcx*2 + 1]
    sub rax, r8                     ; normalize row
    sub rbx, r9                     ; normalize col

    ; Calculate offset: shape*8*MAX_CELLS*2 + orient*MAX_CELLS*2 + cell*2
    imul rdx, r12, 8 * MAX_CELLS_PER_SHAPE * 2
    imul r10, r15, MAX_CELLS_PER_SHAPE * 2
    add rdx, r10
    add rdx, rcx
    add rdx, rcx
    mov [all_orientations + rdx], al
    mov [all_orientations + rdx + 1], bl
    inc rcx
    jmp .store_cells
.store_done:

    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================
; check_area: Verify total cells needed <= grid area
; Output: rax = 1 if ok, 0 if impossible
; ============================================================
check_area:
    push rbx
    push rcx

    ; Calculate total cells needed
    xor rax, rax                    ; total cells
    xor rcx, rcx                    ; shape index
.sum_loop:
    cmp rcx, 6
    jge .sum_done
    mov rbx, [pieces_needed + rcx*8]
    imul rbx, [shape_cell_counts + rcx*8]
    add rax, rbx
    inc rcx
    jmp .sum_loop
.sum_done:

    ; Compare with grid area (must be <=)
    mov rbx, [region_width]
    imul rbx, [region_height]
    cmp rax, rbx
    ja .area_fail                   ; fail if cells needed > grid area

    mov rax, 1
    jmp .area_ret
.area_fail:
    xor rax, rax
.area_ret:
    pop rcx
    pop rbx
    ret

; ============================================================
; clear_grid: Set all grid cells to 0
; ============================================================
clear_grid:
    push rcx
    push rdi
    push rax

    lea rdi, [grid]
    mov rcx, MAX_GRID_SIZE
    xor rax, rax
    rep stosb

    pop rax
    pop rdi
    pop rcx
    ret

; ============================================================
; solve: Main backtracking solver
; Output: rax = 1 if solution found, 0 otherwise
; ============================================================
solve:
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    push rbp

    ; Copy pieces_needed to pieces_remaining
    xor rcx, rcx
.copy_pieces:
    cmp rcx, 6
    jge .copy_done
    mov rax, [pieces_needed + rcx*8]
    mov [pieces_remaining + rcx*8], rax
    inc rcx
    jmp .copy_pieces
.copy_done:

    ; Initialize skips_remaining
    mov rax, [skips_allowed]
    mov [skips_remaining], rax

    ; Start recursive solve
    call solve_recursive

    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret

; ============================================================
; solve_recursive: Recursive backtracking with cell skipping
; Output: rax = 1 if solved, 0 otherwise
; ============================================================
solve_recursive:
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    ; Check if all pieces placed
    xor rcx, rcx
    xor rax, rax
.check_done:
    cmp rcx, 6
    jge .all_placed
    add rax, [pieces_remaining + rcx*8]
    inc rcx
    jmp .check_done
.all_placed:
    test rax, rax
    jnz .not_done
    mov rax, 1                      ; Success!
    jmp .solve_ret

.not_done:
    ; Find first empty cell (grid value == 0)
    mov r8, [region_height]
    mov r9, [region_width]
    xor r10, r10                    ; row
.find_empty_row:
    cmp r10, r8
    jge .no_empty
    xor r11, r11                    ; col
.find_empty_col:
    cmp r11, r9
    jge .next_row

    ; Check grid[row * width + col] == 0
    mov rax, r10
    imul rax, r9
    add rax, r11
    cmp byte [grid + rax], 0
    je .found_empty
    inc r11
    jmp .find_empty_col
.next_row:
    inc r10
    jmp .find_empty_row

.no_empty:
    ; No empty cell but pieces remain
    xor rax, rax
    jmp .solve_ret

.found_empty:
    ; r10 = empty_row, r11 = empty_col
    ; Try each shape that has pieces remaining
    xor r12, r12                    ; shape index
.try_shape:
    cmp r12, 6
    jge .shapes_exhausted

    ; Check if this shape has pieces remaining
    cmp qword [pieces_remaining + r12*8], 0
    je .next_shape

    ; Try each orientation (0-7)
    xor r13, r13                    ; orientation index
.try_orientation:
    cmp r13, 8
    jge .next_shape

    ; Try placing so that each cell of the shape covers (r10, r11)
    mov r14, [shape_cell_counts + r12*8]  ; cell count
    xor r15, r15                    ; cell index
.try_cell_anchor:
    cmp r15, r14
    jge .next_orient

    ; Get this cell's offset in orientation r13
    ; offset = all_orientations[shape*8*MAX_CELLS*2 + orient*MAX_CELLS*2 + cell*2]
    imul rax, r12, 8 * MAX_CELLS_PER_SHAPE * 2
    imul rbx, r13, MAX_CELLS_PER_SHAPE * 2
    add rax, rbx
    add rax, r15
    add rax, r15
    movzx rcx, byte [all_orientations + rax]      ; cell_row offset
    movzx rdx, byte [all_orientations + rax + 1]  ; cell_col offset

    ; place_row = empty_row - cell_row, place_col = empty_col - cell_col
    mov rdi, r10
    sub rdi, rcx                    ; place_row
    js .next_cell                   ; skip if negative

    mov rsi, r11
    sub rsi, rdx                    ; place_col
    js .next_cell                   ; skip if negative

    ; Try to place shape at (rdi, rsi) = (place_row, place_col)
    ; First check if it fits
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    ; can_place_at(shape=r12, orient=r13, row=rdi, col=rsi)
    mov r8, rdi                     ; place_row
    mov r9, rsi                     ; place_col
    mov rdi, r12                    ; shape
    mov rsi, r13                    ; orientation
    mov rdx, r8                     ; row
    mov rcx, r9                     ; col
    call can_place_at

    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10

    test rax, rax
    jz .next_cell

    ; Place the shape!
    ; Recalculate place_row and place_col
    imul rax, r12, 8 * MAX_CELLS_PER_SHAPE * 2
    imul rbx, r13, MAX_CELLS_PER_SHAPE * 2
    add rax, rbx
    add rax, r15
    add rax, r15
    movzx rcx, byte [all_orientations + rax]
    movzx rdx, byte [all_orientations + rax + 1]
    mov r8, r10
    sub r8, rcx                     ; place_row
    mov r9, r11
    sub r9, rdx                     ; place_col

    ; place_shape_at(shape=r12, orient=r13, row=r8, col=r9, fill=1)
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    push r8
    push r9

    mov rdi, r12
    mov rsi, r13
    mov rdx, r8
    mov rcx, r9
    mov r8, 1
    call place_shape_at

    ; Decrement pieces remaining
    dec qword [pieces_remaining + r12*8]

    ; Recurse
    call solve_recursive
    mov rbx, rax                    ; save result

    pop r9
    pop r8
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10

    test rbx, rbx
    jnz .found_solution

    ; Backtrack: remove shape
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    ; Recalculate place_row and place_col again
    imul rax, r12, 8 * MAX_CELLS_PER_SHAPE * 2
    imul rbx, r13, MAX_CELLS_PER_SHAPE * 2
    add rax, rbx
    add rax, r15
    add rax, r15
    movzx rcx, byte [all_orientations + rax]
    movzx rdx, byte [all_orientations + rax + 1]
    mov r8, r10
    sub r8, rcx
    mov r9, r11
    sub r9, rdx

    mov rdi, r12
    mov rsi, r13
    mov rdx, r8
    mov rcx, r9
    mov r8, 0
    call place_shape_at

    ; Restore pieces remaining
    inc qword [pieces_remaining + r12*8]

    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10

.next_cell:
    inc r15
    jmp .try_cell_anchor

.next_orient:
    inc r13
    jmp .try_orientation

.next_shape:
    inc r12
    jmp .try_shape

.shapes_exhausted:
    ; No shape can cover this empty cell
    ; Try skipping it if we have skips remaining
    cmp qword [skips_remaining], 0
    jle .try_failed

    ; Mark cell as skipped (-1 = 0xFF)
    mov rax, r10
    imul rax, [region_width]
    add rax, r11
    mov byte [grid + rax], 0xFF

    ; Decrement skips remaining
    dec qword [skips_remaining]

    ; Recurse
    call solve_recursive
    mov rbx, rax

    ; Restore cell and skips
    mov rax, r10
    imul rax, [region_width]
    add rax, r11
    mov byte [grid + rax], 0
    inc qword [skips_remaining]

    test rbx, rbx
    jnz .found_solution

.try_failed:
    xor rax, rax
    jmp .solve_ret

.found_solution:
    mov rax, 1

.solve_ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret

; ============================================================
; can_place_at: Check if shape can be placed at position
; Input: rdi = shape index, rsi = orientation, rdx = row, rcx = col
; Output: rax = 1 if can place, 0 otherwise
; ============================================================
can_place_at:
    push rbx
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14

    mov r8, rdi                     ; shape
    mov r9, rsi                     ; orientation
    mov r10, rdx                    ; base row
    mov r11, rcx                    ; base col
    mov r12, [shape_cell_counts + r8*8]  ; cell count
    mov r13, [region_width]
    mov r14, [region_height]

    xor rbx, rbx                    ; cell index
.check_cell:
    cmp rbx, r12
    jge .can_place_yes

    ; Get cell offset
    imul rax, r8, 8 * MAX_CELLS_PER_SHAPE * 2
    imul rcx, r9, MAX_CELLS_PER_SHAPE * 2
    add rax, rcx
    add rax, rbx
    add rax, rbx
    movzx rcx, byte [all_orientations + rax]      ; row offset
    movzx rdx, byte [all_orientations + rax + 1]  ; col offset

    ; Calculate actual position
    add rcx, r10                    ; actual row
    add rdx, r11                    ; actual col

    ; Bounds check
    cmp rcx, r14
    jge .can_place_no
    cmp rdx, r13
    jge .can_place_no

    ; Overlap check (must be 0)
    mov rax, rcx
    imul rax, r13
    add rax, rdx
    cmp byte [grid + rax], 0
    jne .can_place_no

    inc rbx
    jmp .check_cell

.can_place_yes:
    mov rax, 1
    jmp .can_place_ret
.can_place_no:
    xor rax, rax
.can_place_ret:
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbx
    ret

; ============================================================
; place_shape_at: Place or remove shape on grid
; Input: rdi = shape, rsi = orientation, rdx = row, rcx = col, r8 = fill value
; ============================================================
place_shape_at:
    push rbx
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    mov r9, rdi                     ; shape
    mov r10, rsi                    ; orientation
    mov r11, rdx                    ; base row
    mov r12, rcx                    ; base col
    mov r13, r8                     ; fill value
    mov r14, [shape_cell_counts + r9*8]  ; cell count
    mov r15, [region_width]

    xor rbx, rbx                    ; cell index
.place_cell:
    cmp rbx, r14
    jge .place_done

    ; Get cell offset
    imul rax, r9, 8 * MAX_CELLS_PER_SHAPE * 2
    imul rcx, r10, MAX_CELLS_PER_SHAPE * 2
    add rax, rcx
    add rax, rbx
    add rax, rbx
    movzx rcx, byte [all_orientations + rax]      ; row offset
    movzx rdx, byte [all_orientations + rax + 1]  ; col offset

    ; Calculate grid position
    add rcx, r11                    ; actual row
    add rdx, r12                    ; actual col
    mov rax, rcx
    imul rax, r15
    add rax, rdx

    ; Write cell
    mov [grid + rax], r13b

    inc rbx
    jmp .place_cell

.place_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop rbx
    ret

section .data
filename: db "../inputs/day12_input.txt", 0

section .bss
MAX_CELLS_PER_SHAPE equ 9
MAX_GRID_SIZE equ 2500              ; 50x50

file_size: resq 1
region_width: resq 1
region_height: resq 1

; Shape data
shape_cells: resb 6 * MAX_CELLS_PER_SHAPE * 2      ; original cells for each shape
shape_cell_counts: resq 6                           ; number of cells per shape
all_orientations: resb 6 * 8 * MAX_CELLS_PER_SHAPE * 2  ; all rotations/flips

; Region solving
pieces_needed: resq 6
pieces_remaining: resq 6
total_cells_needed: resq 1
grid_size: resq 1
skips_allowed: resq 1
skips_remaining: resq 1
grid: resb MAX_GRID_SIZE
