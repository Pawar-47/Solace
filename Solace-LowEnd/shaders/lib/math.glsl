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

#endif
