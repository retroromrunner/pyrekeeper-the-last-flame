#!/usr/bin/env python3
"""Generate Atari 2600 data tables for PYREKEEPER: playfield text bitmaps + bar tables."""
import sys

FONT = {
 'A': [".XX.","X..X","XXXX","X..X","X..X","X..X"],
 'B': ["XXX.","X..X","XXX.","X..X","X..X","XXX."],
 'C': [".XXX","X...","X...","X...","X...",".XXX"],
 'D': ["XXX.","X..X","X..X","X..X","X..X","XXX."],
 'E': ["XXXX","X...","XXX.","X...","X...","XXXX"],
 'F': ["XXXX","X...","XXX.","X...","X...","X..."],
 'G': [".XXX","X...","X.XX","X..X","X..X",".XXX"],
 'H': ["X..X","X..X","XXXX","X..X","X..X","X..X"],
 'I': ["XXXX",".XX.",".XX.",".XX.",".XX.","XXXX"],
 'J': ["..XX","...X","...X","...X","X..X",".XX."],
 'K': ["X..X","X.X.","XX..","X.X.","X..X","X..X"],
 'L': ["X...","X...","X...","X...","X...","XXXX"],
 'M': ["X..X","XXXX","XXXX","X..X","X..X","X..X"],
 'N': ["X..X","XX.X","XX.X","X.XX","X.XX","X..X"],
 'O': [".XX.","X..X","X..X","X..X","X..X",".XX."],
 'P': ["XXX.","X..X","X..X","XXX.","X...","X..."],
 'Q': [".XX.","X..X","X..X","X..X","X.XX",".XXX"],
 'R': ["XXX.","X..X","X..X","XX..","X.X.","X..X"],
 'S': [".XXX","X...",".XX.","...X","...X","XXX."],
 'T': ["XXXX",".XX.",".XX.",".XX.",".XX.",".XX."],
 'U': ["X..X","X..X","X..X","X..X","X..X",".XX."],
 'V': ["X..X","X..X","X..X",".XX.",".XX.",".XX."],
 'W': ["X..X","X..X","X..X","XXXX","XXXX",".XX."],
 'X': ["X..X","X..X",".XX.",".XX.","X..X","X..X"],
 'Y': ["X..X","X..X",".XX.",".XX.",".XX.",".XX."],
 'Z': ["XXXX","...X","..X.",".X..","X...","XXXX"],
 ' ': ["....","....","....","....","....","...."],
}

def text_rows(s):
    """Return 12 rows (6px font doubled) of 6 playfield bytes for a 10-char string."""
    s = (s + " " * 10)[:10]
    out = []
    for r in range(6):
        px = []
        for ch in s:
            g = FONT.get(ch, FONT[' '])
            px += [1 if c == 'X' else 0 for c in g[r]]
        # px: 40 pixels. TIA order: PF0(D4 leftmost), PF1(D7 leftmost), PF2(D0 leftmost),
        # then repeated for right half (no reflect).
        def pf0(p):
            return (p[0] << 4) | (p[1] << 5) | (p[2] << 6) | (p[3] << 7)
        def pf1(p):
            return sum(p[i] << (7 - i) for i in range(8))
        def pf2(p):
            return sum(p[i] << i for i in range(8))
        left, right = px[:20], px[20:]
        row = [pf0(left[0:4]), pf1(left[4:12]), pf2(left[12:20]),
               pf2(right[0:8]), pf1(right[8:16]), pf0(right[16:20])]
        out.append(row)
        out.append(row)  # 2x vertical scale
    return out

def emit(name, rows):
    print(f"{name}:")
    for row in rows:
        print("    .byte " + ",".join(f"${b:02X}" for b in row))

def main():
    emit("TextPyre", text_rows("PYREKEEPER"))
    emit("TextPress", text_rows("PRESS FIRE"))
    emit("TextOver", text_rows("GAME OVER"))
    # Flame bar tables: width 0..16 -> PF1 byte (D7 leftmost), PF2 byte (D0 leftmost)
    pf1, pf2 = [], []
    for w in range(17):
        b1 = 0
        for i in range(min(w, 8)):
            b1 |= 1 << (7 - i)
        b2 = 0
        for i in range(max(0, w - 8)):
            b2 |= 1 << i
        pf1.append(b1)
        pf2.append(b2)
    print("BarPF1Tab:")
    print("    .byte " + ",".join(f"${b:02X}" for b in pf1))
    print("BarPF2Tab:")
    print("    .byte " + ",".join(f"${b:02X}" for b in pf2))

if __name__ == "__main__":
    main()
