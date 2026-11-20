#!/usr/bin/env python3
"""Run the pack's texture generator and check what it produced.

The three PNGs the pack can read are generated, not committed (a PNG is binary and
the pack is built where only text can be written). That makes the generator itself
part of the pack, so CI runs it and then verifies the output: a real PNG signature,
an IHDR, and the size the shader expects.

Exit code 0 means the generator ran and wrote three valid files.
"""

import os
import struct
import subprocess
import sys

EXPECTED = [
    ("noise.png", 256, 256),
    ("clouds.png", 512, 512),
    ("clouds_blocky.png", 512, 512),
]

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    textures = os.path.join(here, "..", "Solace-LowEnd", "shaders", "textures")
    textures = os.path.normpath(textures)

    if not os.path.isdir(textures):
        print("FAIL: no textures folder at %s" % textures)
        return 1

    script = os.path.join(textures, "generate_textures.py")
    if not os.path.isfile(script):
        print("FAIL: generate_textures.py is missing")
        return 1

    print("Running %s" % script)
    result = subprocess.run([sys.executable, "generate_textures.py"],
                            cwd=textures)
    if result.returncode != 0:
        print("FAIL: the generator returned %d" % result.returncode)
        return 1

    failures = 0
    for name, width, height in EXPECTED:
        path = os.path.join(textures, name)
        if not os.path.isfile(path):
            print("FAIL: %s was not written" % name)
            failures += 1
            continue

        size = os.path.getsize(path)
        with open(path, "rb") as handle:
            head = handle.read(33)

        if head[:8] != PNG_SIGNATURE:
            print("FAIL: %s is not a PNG" % name)
            failures += 1
            continue
        if head[12:16] != b"IHDR":
            print("FAIL: %s has no IHDR chunk" % name)
            failures += 1
            continue

        got_width, got_height = struct.unpack(">II", head[16:24])
        if (got_width, got_height) != (width, height):
            print("FAIL: %s is %dx%d, expected %dx%d"
                  % (name, got_width, got_height, width, height))
            failures += 1
            continue

        print("ok: %s %dx%d, %d bytes" % (name, got_width, got_height, size))

    if failures:
        print("FAIL: %d texture problem(s)" % failures)
        return 1

    print("OK: the generator produced all three textures")
    return 0


if __name__ == "__main__":
    sys.exit(main())
