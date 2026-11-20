#!/usr/bin/env python3
"""Generate the three textures this pack can read.

Run once, from this folder:

    python3 generate_textures.py

It writes noise.png, clouds.png and clouds_blocky.png beside itself, all tileable,
all generated here rather than copied from anywhere. Standard library only - no
Pillow, no numpy.

Why a script and not the files: a PNG is a binary, and the pack is built in an
environment that can only write text. The shaders work without these files (every
noise is computed in the shader); with them, and PACK_TEXTURES set to 1, the water
and the clouds read a texture instead of evaluating noise per pixel - two fetches
instead of six noise evaluations on the water, one instead of two octaves per cloud
sample. On an Intel HD 5500 that is the difference between the effects being free and
being felt.

    noise.png          256x256 RGB. R and G are the two ripple components the water
                       shader reads; B is left at 0.
    clouds.png         512x512 grey. Tileable fBm, the density the cloud march reads.
    clouds_blocky.png  512x512 grey. The same field with two octaves instead of five,
                       which reads as the flatter, more cartoon cloud.
"""

import math
import random
import struct
import zlib

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def write_png(path, width, height, channels, pixels):
    """Write an 8-bit PNG. channels is 1 (grey), 2 (grey+alpha), 3 (rgb) or 4 (rgba)."""
    colour_type = {1: 0, 2: 4, 3: 2, 4: 6}[channels]

    raw = bytearray()
    stride = width * channels
    for y in range(height):
        raw.append(0)  # filter type 0: none
        raw += pixels[y * stride:(y + 1) * stride]

    def chunk(tag, payload):
        out = struct.pack(">I", len(payload)) + tag + payload
        return out + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, colour_type, 0, 0, 0)
    with open(path, "wb") as handle:
        handle.write(PNG_SIGNATURE)
        handle.write(chunk(b"IHDR", header))
        handle.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        handle.write(chunk(b"IEND", b""))


def tileable_value_noise(size, cells, rng):
    """A value-noise lattice that wraps, so the texture tiles in both directions."""
    lattice = [[rng.random() for _ in range(cells)] for _ in range(cells)]

    def smooth(t):
        return t * t * (3.0 - 2.0 * t)

    field = [0.0] * (size * size)
    scale = cells / float(size)

    for y in range(size):
        fy = y * scale
        y0 = int(fy) % cells
        y1 = (y0 + 1) % cells
        ty = smooth(fy - int(fy))

        for x in range(size):
            fx = x * scale
            x0 = int(fx) % cells
            x1 = (x0 + 1) % cells
            tx = smooth(fx - int(fx))

            top = lattice[y0][x0] * (1.0 - tx) + lattice[y0][x1] * tx
            bottom = lattice[y1][x0] * (1.0 - tx) + lattice[y1][x1] * tx
            field[y * size + x] = top * (1.0 - ty) + bottom * ty

    return field


def fbm(size, base_cells, octaves, rng, gain=0.5):
    """Sum of tileable noise octaves, normalised to 0..1."""
    total = [0.0] * (size * size)
    amplitude = 1.0
    norm = 0.0
    cells = base_cells

    for _ in range(octaves):
        layer = tileable_value_noise(size, cells, rng)
        for i in range(size * size):
            total[i] += layer[i] * amplitude
        norm += amplitude
        amplitude *= gain
        cells = min(cells * 2, size)

    return [v / norm for v in total]


def main():
    rng = random.Random(9660)  # fixed seed: the same pack every run

    # Water: two independent ripple fields in R and G.
    size = 256
    ripple_a = fbm(size, 8, 4, rng)
    ripple_b = fbm(size, 16, 3, rng)

    pixels = bytearray(size * size * 3)
    for i in range(size * size):
        pixels[i * 3 + 0] = int(max(0.0, min(1.0, ripple_a[i])) * 255.0)
        pixels[i * 3 + 1] = int(max(0.0, min(1.0, ripple_b[i])) * 255.0)
        pixels[i * 3 + 2] = 0
    write_png("noise.png", size, size, 3, pixels)
    print("noise.png           %dx%d rgb" % (size, size))

    # Clouds: one grey field, smooth for the natural style.
    size = 512
    natural = fbm(size, 4, 5, rng, gain=0.55)
    grey = bytearray(size * size)
    for i in range(size * size):
        grey[i] = int(max(0.0, min(1.0, natural[i])) * 255.0)
    write_png("clouds.png", size, size, 1, grey)
    print("clouds.png          %dx%d grey" % (size, size))

    # Clouds, blocky style: two octaves and a harder curve.
    blocky = fbm(size, 4, 2, rng, gain=0.6)
    grey = bytearray(size * size)
    for i in range(size * size):
        # Slightly S-curved so the cover reads as plates rather than haze.
        v = blocky[i]
        v = v * v * (3.0 - 2.0 * v)
        grey[i] = int(max(0.0, min(1.0, v)) * 255.0)
    write_png("clouds_blocky.png", size, size, 1, grey)
    print("clouds_blocky.png   %dx%d grey" % (size, size))

    print("")
    print("Now set PACK_TEXTURES to 1 in lib/config.glsl, or leave it 0 to keep the")
    print("noise computed in the shader. Either way the pack works.")


if __name__ == "__main__":
    main()
