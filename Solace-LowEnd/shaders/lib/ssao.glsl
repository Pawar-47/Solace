/* Solace - lib/ssao.glsl

Screen-space ambient occlusion in the final pass, built the way the reference builds
its `dbao`:

  * samples are taken in pairs, one each side of the centre, rotated by the golden
    ratio so consecutive taps never line up, which is what lets four or six taps
    cover a disc;
  * each pair adds an "angle" term (a neighbour in front of this surface) and a
    "distance" term, then the sum is clamped - occlusion, not just depth difference;
  * the result goes through a square root, as the reference's does, which keeps
    corners from going flat black;
  * the occlusion fades with distance, because at 60 blocks a depth difference says
    nothing about a corner.

AO_TAPS is four or six. Four is the cheap setting that keeps the effect on instead
of switching it off.
*/

#ifndef SOLACE_SSAO
#define SOLACE_SSAO

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"

#if AO == 1

uniform sampler2D depthtex0;

vec4 viewPositionAt(vec2 uv, float depth) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * clip;
    return view / view.w;
}

float occlusionAt(vec2 uv, float centreZ, float rangeScale) {
    float depth = texture2D(depthtex0, uv).r;
    if (depth >= 1.0) return 0.0;

    float neighbourZ = viewPositionAt(uv, depth).z;
    float difference = (centreZ - neighbourZ) * rangeScale;

    float angle = clamp(0.5 - difference, 0.0, 1.0);
    float dist = clamp(0.25 * difference - 1.0, 0.0, 1.0);
    return clamp(angle + dist, 0.0, 1.0);
}

float screenSpaceAO(vec2 uv) {
    float depth = texture2D(depthtex0, uv).r;
    if (depth >= 1.0) return 1.0;

    float centreZ = viewPositionAt(uv, depth).z;
    float distanceFade = sat(1.0 - (-centreZ) / AO_FADE);
    if (distanceFade <= 0.001) return 1.0;

    /* The reference scales its taps by fov and depth; this is the same idea without
       the extra uniforms: a fixed fraction of the screen, divided by depth. */
    float scale = AO_RADIUS / max(-centreZ, 1.0);
    vec2 scaleVec = vec2(scale / aspectRatio, scale);
    float rangeScale = 1.0 / max(AO_RADIUS * 12.0, 0.35);

    /* A rotating dither, so the four or six paired taps do not settle into the same
       ring pattern every frame. */
    float dither = solDitherShifted(gl_FragCoord.xy * 0.37,
                                    float(frameCounter % 64) * 0.015625);
    float occlusion = 0.0;

    #if AO_TAPS == 6
        float taps = 6.0;
    #else
        float taps = 4.0;
    #endif

    for (int i = 0; i < AO_TAPS; i++) {
        float turn = fract((float(i) + dither) * 1.6180339887) * 3.141592653589793;
        vec2 offset = vec2(cos(turn), sin(turn)) * (float(i) + 1.0) * 0.4 * scaleVec;

        occlusion += occlusionAt(uv + offset, centreZ, rangeScale);
        occlusion += occlusionAt(uv - offset, centreZ, rangeScale);
    }

    occlusion /= (taps * 2.0);

    /* The reference's curve: sqrt(occlusion * strength + (1 - strength)). */
    float curved = sqrt(clamp(occlusion * AO_STRENGTH + (1.0 - AO_STRENGTH), 0.0, 1.0));
    return mix(1.0, curved, distanceFade);
}

#endif

#endif
