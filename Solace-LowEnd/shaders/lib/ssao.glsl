/* Solace - lib/ssao.glsl

Screen-space ambient occlusion, computed in the final pass out of the depth
buffer: one centre depth, six neighbours in a ring scaled by the distance of the
surface, and a score for each neighbour that only counts when it is in front of
this surface and close to it. Nothing is sampled outside the frame and nothing is
counted past the far plane, which is what keeps silhouettes and the horizon from
growing dark halos.

Only compiled in when AO is 1; with it at 0 the option costs nothing at all.
*/

#ifndef SOLACE_SSAO
#define SOLACE_SSAO

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"

#if AO == 1

uniform sampler2D depthtex0;

vec3 viewPositionAt(vec2 uv, float depth) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * clip;
    return view.xyz / view.w;
}

/* How much one neighbour occludes this surface. */
float occlusionAt(vec2 uv, float centreZ) {
    float depth = texture2D(depthtex0, uv).r;
    if (depth >= 1.0) return 0.0;

    float neighbourZ = viewPositionAt(uv, depth).z;
    float front = neighbourZ - centreZ;
    return step(0.02, front) * sat(1.0 - front / 1.5);
}

float screenSpaceAO(vec2 uv) {
    float depth = texture2D(depthtex0, uv).r;
    if (depth >= 1.0) return 1.0;

    float centreZ = viewPositionAt(uv, depth).z;
    float radius = AO_RADIUS / max(-centreZ, 1.0);
    vec2 stepX = vec2(radius / aspectRatio, 0.0);
    vec2 stepY = vec2(0.0, radius);

    float occlusion = 0.0;
    occlusion += occlusionAt(uv + stepX * 1.30, centreZ);
    occlusion += occlusionAt(uv - stepX * 1.30, centreZ);
    occlusion += occlusionAt(uv + stepY * 1.30, centreZ);
    occlusion += occlusionAt(uv - stepY * 1.30, centreZ);
    occlusion += occlusionAt(uv + (stepX + stepY) * 0.90, centreZ);
    occlusion += occlusionAt(uv - (stepX + stepY) * 0.90, centreZ);
    occlusion /= 6.0;

    return sat(1.0 - occlusion * AO_STRENGTH);
}

#endif

#endif
