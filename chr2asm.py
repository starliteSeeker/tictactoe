#!/usr/bin/env python3

with open("graphics.chr", "rb") as f:
    with open("tiles.inc", "w") as g:
        g.write("; Generated from graphics.chr\n\n")
        g.write("tiles:\n")
        count = 0
        while (ls := f.read(16)):
            g.write("    .db " + ", ".join("${:02x}".format(c) for c in ls) + "\n")
        g.write("@end:\n")
