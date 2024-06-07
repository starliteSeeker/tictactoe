#!/usr/bin/env python3

with open("graphics.pal", "rb") as f:
    with open("palettes.inc", "w") as g:
        g.write("; Generated from graphics.pal\n\n")
        g.write("palettes:\n")
        while (ls := f.read(3 * 16)):
            g.write("    .db ")
            # color format is 0bbbbbgg gggrrrrr
            lls = [(ls[i] & 0b11111000) >> 3 | (ls[i + 1] & 0b11111000) << 2 | (ls[i + 2] & 0b11111000) << 7 for i in range(0, len(ls), 3)]
            g.write(", ".join("${:02x}, ${:02x}".format(b & 0xff, b >> 8) for b in lls))
            g.write("\n")
        g.write("@end:\n")
