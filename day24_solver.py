from z3 import *
v0 = Int("v0")
n3 = Int("n3")
n4 = Int("n4")
v1 = Int("v1")
n7 = Int("n7")
n8 = Int("n8")
n9 = Int("n9")
v2 = Int("v2")
n12 = Int("n12")
n13 = Int("n13")
n14 = Int("n14")
v3 = Int("v3")
n16 = Int("n16")
n17 = Int("n17")
v4 = Int("v4")
n22 = Int("n22")
v5 = Int("v5")
n24 = Int("n24")
n26 = Int("n26")
n27 = Int("n27")
n28 = Int("n28")
n29 = Int("n29")
n31 = Int("n31")
n32 = Int("n32")
n33 = Int("n33")
v6 = Int("v6")
n36 = Int("n36")
v7 = Int("v7")
n38 = Int("n38")
n39 = Int("n39")
n40 = Int("n40")
n41 = Int("n41")
n42 = Int("n42")
n43 = Int("n43")
n44 = Int("n44")
n45 = Int("n45")
n46 = Int("n46")
n48 = Int("n48")
n49 = Int("n49")
v8 = Int("v8")
n51 = Int("n51")
n52 = Int("n52")
n53 = Int("n53")
n54 = Int("n54")
n55 = Int("n55")
n57 = Int("n57")
n58 = Int("n58")
n59 = Int("n59")
v9 = Int("v9")
v10 = Int("v10")
n62 = Int("n62")
n63 = Int("n63")
n64 = Int("n64")
n65 = Int("n65")
n66 = Int("n66")
n68 = Int("n68")
n69 = Int("n69")
n70 = Int("n70")
n71 = Int("n71")
n73 = Int("n73")
n74 = Int("n74")
v11 = Int("v11")
n76 = Int("n76")
n77 = Int("n77")
n78 = Int("n78")
n79 = Int("n79")
n80 = Int("n80")
n82 = Int("n82")
n83 = Int("n83")
n84 = Int("n84")
n85 = Int("n85")
n87 = Int("n87")
n88 = Int("n88")
v12 = Int("v12")
n90 = Int("n90")
n91 = Int("n91")
n92 = Int("n92")
n93 = Int("n93")
n94 = Int("n94")
n96 = Int("n96")
n97 = Int("n97")
n98 = Int("n98")
n99 = Int("n99")
n101 = Int("n101")
n102 = Int("n102")
v13 = Int("v13")
n104 = Int("n104")
n105 = Int("n105")
n106 = Int("n106")
n107 = Int("n107")
n108 = Int("n108")
n109 = Int("n109")
n110 = Int("n110")
n111 = Int("n111")
constraints = (n111 == 0, v0 >= 1, v0 <= 9,v1 >= 1, v1 <= 9,v2 >= 1, v2 <= 9,v3 >= 1, v3 <= 9,v4 >= 1, v4 <= 9,v5 >= 1, v5 <= 9,v6 >= 1, v6 <= 9,v7 >= 1, v7 <= 9,v8 >= 1, v8 <= 9,v9 >= 1, v9 <= 9,v10 >= 1, v10 <= 9,v11 >= 1, v11 <= 9,v12 >= 1, v12 <= 9,v13 >= 1, v13 <= 9,26 * v0 == n3, 104 + n3 == n4, 11 + v1 == n7, n4 + n7 == n8, 26 * n8 == n9, 5 + v2 == n12, n9 + n12 == n13, 26 * n13 == n14, 11 + v3 == n16, n14 + n16 == n17, 4 + v4 == n22, If(n22 == v5, 1, 0) == n24, If(n24 == 0, 1, 0) == n26, 25 * n26 == n27, 1 + n27 == n28, n17 * n28 == n29, 7 + v5 == n31, n26 * n31 == n32, n29 + n32 == n33, 2 + v6 == n36, If(n36 == v7, 1, 0) == n38, If(n38 == 0, 1, 0) == n39, 25 * n39 == n40, 1 + n40 == n41, n33 * n41 == n42, 4 + v7 == n43, n39 * n43 == n44, n42 + n44 == n45, n45 / 26 == n46, n45 % 26 == n48, -3 + n48 == n49, If(n49 == v8, 1, 0) == n51, If(n51 == 0, 1, 0) == n52, 25 * n52 == n53, 1 + n53 == n54, n46 * n54 == n55, 6 + v8 == n57, n52 * n57 == n58, n55 + n58 == n59, If(v9 == v10, 1, 0) == n62, If(n62 == 0, 1, 0) == n63, 25 * n63 == n64, 1 + n64 == n65, n59 * n65 == n66, 9 + v10 == n68, n63 * n68 == n69, n66 + n69 == n70, n70 / 26 == n71, n70 % 26 == n73, -10 + n73 == n74, If(n74 == v11, 1, 0) == n76, If(n76 == 0, 1, 0) == n77, 25 * n77 == n78, 1 + n78 == n79, n71 * n79 == n80, 12 + v11 == n82, n77 * n82 == n83, n80 + n83 == n84, n84 / 26 == n85, n84 % 26 == n87, -4 + n87 == n88, If(n88 == v12, 1, 0) == n90, If(n90 == 0, 1, 0) == n91, 25 * n91 == n92, 1 + n92 == n93, n85 * n93 == n94, 14 + v12 == n96, n91 * n96 == n97, n94 + n97 == n98, n98 / 26 == n99, n98 % 26 == n101, -5 + n101 == n102, If(n102 == v13, 1, 0) == n104, If(n104 == 0, 1, 0) == n105, 25 * n105 == n106, 1 + n106 == n107, n99 * n107 == n108, 14 + v13 == n109, n105 * n109 == n110, n108 + n110 == n111, )
def opt(mode, solver, known_digits, next_low, next_high):
    if len(known_digits) == 14:
        print(f"Solved {''.join(str(s) for s in known_digits)}")
        return known_digits

    print(f"Current partial solution {mode} = {''.join(str(s) for s in known_digits)}[{next_low}-{next_high}]")
    # print(f"Finding optimal digit {len(known_digits)}, known range [{next_low}, {next_high}]")
    
    if next_low == next_high:
        # print(f"Digit {len(known_digits)} solved = {next_low}")
        next_known_digits = known_digits.copy()
        next_known_digits.append(next_low)
        return opt(mode, solver, next_known_digits, 1, 9)

    
    additional_constraints = []
    for i, val in enumerate(known_digits):
        additional_constraints.append(Int(f'v{i}') == val)

    midpoint = (next_low + next_high) // 2

    search_region = (midpoint+1, next_high)
    other_region = (next_low, midpoint)
    if mode == "min":
        search_region = (next_low, midpoint)
        other_region = (midpoint+1, next_high)

    additional_constraints.append(Int(f'v{len(known_digits)}') >= search_region[0])
    additional_constraints.append(Int(f'v{len(known_digits)}') <= search_region[1])

    # print("Searching with constraints", additional_constraints)

    solver.push()
    solver.add(additional_constraints)
    if solver.check() == CheckSatResult(Z3_L_TRUE):
        # print(f"Digit {len(known_digits)} in = {search_region[0]}, {search_region[1]}")
        # read out the solution found for this digit
        m = solver.model()
        solved_val = m[Int(f"v{len(known_digits)}")].as_long()
        solver.pop()
        return opt(mode, solver, known_digits, search_region[0], search_region[1])
    else:
        # print(f"Digit {len(known_digits)} in = {other_region[0]}, {other_region[1]}")
        solver.pop()
        return opt(mode, solver, known_digits, other_region[0], other_region[1])

s = Solver()
s.add(constraints)
print("Maximizing")
opt("max", s, [], 1, 9)
print("Minimizing")
opt("min", s, [], 1, 9)