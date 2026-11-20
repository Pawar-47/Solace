/* Solace - lib/math.glsl

Small helpers. Nothing here needs a uniform, so this file can be included by
any stage, and it deliberately avoids tables and arrays to stay cheap.
*/

#ifndef SOLACE_MATH
#define SOLACE_MATH

#define PI_SOLACE 3.14159265358979
#define TAU_SOLACE 6.28318530717959

float sat(float x) {
    return clamp(x, 0.0, 1.0);
}

vec3 sat(vec3 x) {
    return clamp(x, vec3(0.0), vec3(1.0));
}

float luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

/* Small integer powers as multiplications. pow(x, 6.0) is a logarithm and an
   exponential on most drivers, and the lightmap candle curve is evaluated on every
   lit pixel, so this is not a micro-optimisation. */
float solPow4(float x) {
    float t = x * x;
    return t * t;
}

float solPow5(float x) {
    float t = x * x;
    return t * t * x;
}

float solPow6(float x) {
    float t = x * x;
    return t * t * t;
}

/* A hash that only needs two multiplies and a dot. Used for the water surface,
   for the stars and for the dither, where exactness does not matter. */
float solHash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

float solNoise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    vec2 w = f * f * (3.0 - 2.0 * f);
    float a = solHash(cell);
    float b = solHash(cell + vec2(1.0, 0.0));
    float c = solHash(cell + vec2(0.0, 1.0));
    float d = solHash(cell + vec2(1.0, 1.0));
    return mix(mix(a, b, w.x), mix(c, d, w.x), w.y);
}

/* Two octaves. */
float solFbm(vec2 p) {
    return solNoise(p) * 0.62 + solNoise(p * 2.13 + 17.0) * 0.38;
}

/* Three octaves, only for water, and only when WATER_WAVES is on. */
float solFbm3(vec2 p) {
    return solNoise(p) * 0.48
         + solNoise(p * 2.07 + 11.0) * 0.32
         + solNoise(p * 4.03 + 29.0) * 0.20;
}

/* Signed dither in units of one 8-bit step. */
float solDither(vec2 pixel) {
    return solHash(pixel) - 0.5;
}

/* A dithered sample position, in [0, 1), with a 2x2 tile flip: neighbouring tiles
   mirror each other, so the pattern the eye sees is far closer to noise than a
   single hash, which repeats visibly at large flat areas. The two constants are a
   low-discrepancy pair, which is what keeps consecutive taps from lining up. */
float solDitherBlue(vec2 pixel) {
    vec2 tile = floor(pixel * 0.25);
    float flip = mod(tile.x + tile.y, 2.0);
    vec2 q = mix(pixel, pixel.yx, flip);
    return fract(dot(vec2(0.7548776662466928, 0.56984029099805), q)
                 + solHash(tile) * 0.6180339887498949);
}

/* The same, rotated by the frame counter, for effects that gather samples over the
   screen: a still dither becomes a fixed pattern in the image, a moving one averages
   out over a few frames. shift is frameCounter % 64 moved into [0, 1). */
float solDitherShifted(vec2 pixel, float shift) {
    return fract(solDitherBlue(pixel + vec2(shift * 7.0, shift * 23.0)) + shift);
}

#endif
