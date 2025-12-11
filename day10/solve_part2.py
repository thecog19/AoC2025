#!/usr/bin/env python3
import re
from fractions import Fraction
from itertools import product

def parse_line(line):
    buttons = []
    for match in re.finditer(r'\(([^)]+)\)', line):
        indices = [int(x) for x in match.group(1).split(',')]
        buttons.append(indices)
    target_match = re.search(r'\{([^}]+)\}', line)
    targets = [int(x) for x in target_match.group(1).split(',')]
    return buttons, targets

def gaussian_elimination(A, b):
    """
    Perform Gaussian elimination to get RREF.
    Returns (rref_matrix, pivot_cols) where rref_matrix includes augmented column.
    """
    m = len(A)
    n = len(A[0]) if m > 0 else 0

    # Create augmented matrix
    aug = [row[:] + [b[i]] for i, row in enumerate(A)]

    pivot_cols = []
    pivot_row = 0

    for col in range(n):
        if pivot_row >= m:
            break

        # Find pivot
        pivot = -1
        for row in range(pivot_row, m):
            if aug[row][col] != 0:
                pivot = row
                break

        if pivot == -1:
            continue

        # Swap rows
        aug[pivot_row], aug[pivot] = aug[pivot], aug[pivot_row]

        # Scale pivot row
        scale = aug[pivot_row][col]
        aug[pivot_row] = [x / scale for x in aug[pivot_row]]

        # Eliminate column
        for row in range(m):
            if row != pivot_row and aug[row][col] != 0:
                factor = aug[row][col]
                aug[row] = [aug[row][j] - factor * aug[pivot_row][j] for j in range(n + 1)]

        pivot_cols.append(col)
        pivot_row += 1

    return aug, pivot_cols

def solve_machine(buttons, targets):
    """
    Solve Ax = b for non-negative integers minimizing sum(x).
    Uses Gaussian elimination to find parametric solution, then searches.
    """
    n = len(buttons)
    m = len(targets)

    # Build matrix A
    A = [[Fraction(0)] * n for _ in range(m)]
    for j, btn in enumerate(buttons):
        for i in btn:
            if i < m:
                A[i][j] = Fraction(1)

    b = [Fraction(t) for t in targets]

    # Gaussian elimination
    rref, pivot_cols = gaussian_elimination(A, b)

    # Free variables are those not in pivot_cols
    free_vars = [j for j in range(n) if j not in pivot_cols]

    # Check for inconsistency (row of zeros with non-zero RHS)
    for i in range(len(pivot_cols), m):
        if rref[i][n] != 0:
            return None  # No solution

    # If no free variables, solution is unique
    if not free_vars:
        solution = [Fraction(0)] * n
        for i, col in enumerate(pivot_cols):
            solution[col] = rref[i][n]
        if all(s >= 0 and s.denominator == 1 for s in solution):
            return int(sum(solution))
        return None

    # Express basic vars in terms of free vars:
    # x_pivot[i] = rref[i][n] - sum(rref[i][f] * x_f for f in free_vars)

    # For each basic var, compute:
    # - constant term (rref[i][n])
    # - coefficients for each free var (-rref[i][f])
    basic_const = {}
    basic_coeff = {}
    for i, col in enumerate(pivot_cols):
        basic_const[col] = rref[i][n]
        basic_coeff[col] = {f: -rref[i][f] for f in free_vars}

    import math

    # For free variables, use generous bounds based on target values
    # The actual feasible region depends on interactions between variables
    max_val = max(targets)

    # Simple heuristic bounds - may need to search wider
    free_lower = {f: 0 for f in free_vars}
    free_upper = {f: max_val for f in free_vars}

    def int_range(lower, upper):
        return range(lower, upper + 1)

    ranges = [int_range(free_lower[f], free_upper[f]) for f in free_vars]

    best = None

    for free_vals in product(*ranges):
        # Compute basic variables
        solution = [Fraction(0)] * n

        # Set free variables
        for i, f in enumerate(free_vars):
            solution[f] = Fraction(free_vals[i])

        # Compute basic variables
        valid = True
        for col in pivot_cols:
            val = basic_const[col]
            for i, f in enumerate(free_vars):
                val += basic_coeff[col][f] * free_vals[i]
            if val < 0 or val.denominator != 1:
                valid = False
                break
            solution[col] = val

        if valid:
            total = sum(solution)
            if best is None or total < best:
                best = total

    return int(best) if best is not None else None

def solve_machine_debug(buttons, targets):
    """Debug version that shows work"""
    n_buttons = len(buttons)
    n_targets = len(targets)
    print(f"  Buttons: {buttons}")
    print(f"  Targets: {targets}")

    A = [[0] * (n_buttons + 1) for _ in range(n_targets)]
    for j, btn in enumerate(buttons):
        for i in btn:
            if i < n_targets:
                A[i][j] = 1
    for i in range(n_targets):
        A[i][n_buttons] = targets[i]

    print("  Initial matrix:")
    for row in A:
        print(f"    {row}")

    pivot_col = [-1] * n_buttons
    pivot_row = [-1] * n_targets
    current_row = 0

    for col in range(n_buttons):
        if current_row >= n_targets:
            break
        pivot = -1
        for row in range(current_row, n_targets):
            if A[row][col] != 0:
                pivot = row
                break
        if pivot == -1:
            continue
        if pivot != current_row:
            A[current_row], A[pivot] = A[pivot], A[current_row]
        pivot_val = A[current_row][col]
        for c in range(n_buttons + 1):
            A[current_row][c] /= pivot_val
        for row in range(n_targets):
            if row != current_row and A[row][col] != 0:
                factor = A[row][col]
                for c in range(n_buttons + 1):
                    A[row][c] -= factor * A[current_row][c]
        pivot_col[col] = current_row
        pivot_row[current_row] = col
        current_row += 1

    print("  RREF matrix:")
    for row in A:
        print(f"    {row}")
    print(f"  pivot_col: {pivot_col}")
    print(f"  pivot_row: {pivot_row}")

    free_vars = [j for j in range(n_buttons) if pivot_col[j] == -1]
    basic_vars = [j for j in range(n_buttons) if pivot_col[j] != -1]
    print(f"  free_vars: {free_vars}, basic_vars: {basic_vars}")

    solution = [0.0] * n_buttons
    if not free_vars:
        for row in range(n_targets):
            if pivot_row[row] != -1:
                solution[pivot_row[row]] = A[row][n_buttons]
        print(f"  Unique solution: {solution}, sum={sum(solution)}")
        return int(round(sum(solution)))

    for row in range(n_targets):
        if pivot_row[row] != -1:
            solution[pivot_row[row]] = A[row][n_buttons]
    print(f"  Initial solution (free=0): {solution}")

    for f in free_vars:
        coeff_sum = sum(A[pivot_col[j]][f] for j in basic_vars)
        print(f"  Free var {f}: coeff_sum={coeff_sum}, net_change={1-coeff_sum}")
        if coeff_sum > 1:
            max_increase = float('inf')
            for j in basic_vars:
                row = pivot_col[j]
                if A[row][f] > 1e-10:
                    limit = solution[j] / A[row][f]
                    print(f"    Basic var {j} limits to {limit}")
                    max_increase = min(max_increase, limit)
            print(f"    max_increase={max_increase}")
            if max_increase > 0 and max_increase < float('inf'):
                solution[f] += max_increase
                for j in basic_vars:
                    row = pivot_col[j]
                    solution[j] -= A[row][f] * max_increase
                print(f"    After increase: {solution}")

    print(f"  Final solution: {solution}, sum={sum(solution)}")
    return int(round(sum(solution)))

def main():
    # Test with test input first
    test_input = """[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}
[...#.] (0,2,3,4) (2,3) (0,4) (0,1,2) (1,2,3,4) {7,5,12,7,2}
[.###.#] (0,1,2,3,4) (0,3,4) (0,1,2,4,5) (1,2) {10,11,11,5,10,5}"""

    print("Test cases:")
    total = 0
    for i, line in enumerate(test_input.strip().split('\n'), 1):
        buttons, targets = parse_line(line)
        result = solve_machine(buttons, targets)
        print(f"  Machine {i}: {result}")
        total += result
    print(f"  Total: {total} (expected 33)")
    print()

    print("Real input:")
    total = 0
    with open('../inputs/day10_input.txt') as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            buttons, targets = parse_line(line)
            result = solve_machine(buttons, targets)
            print(f"{result}")
            total += result
    print(f"Total: {total}")

if __name__ == '__main__':
    main()
