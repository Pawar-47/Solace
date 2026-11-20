/* Solace - lib/shadowmap.glsl

Opt-in cast shadows, off by default: SHADOWS is 0 in lib/config.glsl, because a
second scene render is the single most expensive thing a pack can do and this pack
is written for an Intel HD 5500. Set it to 1 and the shadow pass runs and the
geometry programs scale their sun term by the lookup below; block light is never
shadowed.

Resolution and distance come from the two sliders, so re-enabling shadows can be
paid for at 512 px and 75 blocks instead of 2048 and 255.

No shadow distortion is applied, either when writing the map or when sampling it,
so both sides always agree about where a texel is.
*/

#ifndef SOLACE_SHADOWMAP
#define SOLACE_SHADOWMAP

#include "/lib/config.glsl"
#include "/lib/math.glsl"

#if SHADOWS == 1

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform sampler2D shadowtex1;

#if SHADOW_QTY_SLIDER == 1
    #define SOLACE_SHADOW_RESOLUTION 512
#elif SHADOW_QTY_SLIDER == 2
    #define SOLACE_SHADOW_RESOLUTION 1024
#else
    #define SOLACE_SHADOW_RESOLUTION 2048
#endif

#if SHADOW_DISTANCE_SLIDER == 0
    #define SOLACE_SHADOW_COVERAGE 75.0
#elif SHADOW_DISTANCE_SLIDER == 1
    #define SOLACE_SHADOW_COVERAGE 105.0
#else
    #define SOLACE_SHADOW_COVERAGE 255.0
#endif

const int shadowMapResolution = SOLACE_SHADOW_RESOLUTION;
const float shadowDistance = SOLACE_SHADOW_COVERAGE;
const float shadowDistanceRenderMul = 1.0;

/* Four taps with a bias that grows as the surface turns away from the sun, and a
   fade to lit at the edge of the map. Returns 1.0 for lit, 0.0 for shadowed.
   playerPosition is the camera-relative world position. */
float shadowFactor(vec3 playerPosition, float facing) {
    vec4 clip = shadowProjection * (shadowModelView * vec4(playerPosition, 1.0));
    vec3 coord = clip.xyz / clip.w;

    if (coord.z > 1.0 || coord.x < 0.0 || coord.x > 1.0
        || coord.y < 0.0 || coord.y > 1.0) {
        return 1.0;
    }

    float bias = 0.0012 + 0.0025 * (1.0 - facing);
    vec2 texel = vec2(SHADOW_BLUR / float(shadowMapResolution));

    float lit;
    #if SHADOW_SOFT == 1
        float sum = 0.0;
        sum += step(coord.z - bias, texture2D(shadowtex1, coord.xy + texel * vec2(-0.7, -0.7)).r);
        sum += step(coord.z - bias, texture2D(shadowtex1, coord.xy + texel * vec2( 0.7, -0.7)).r);
        sum += step(coord.z - bias, texture2D(shadowtex1, coord.xy + texel * vec2(-0.7,  0.7)).r);
        sum += step(coord.z - bias, texture2D(shadowtex1, coord.xy + texel * vec2( 0.7,  0.7)).r);
        lit = sum * 0.25;
    #else
        lit = step(coord.z - bias, texture2D(shadowtex1, coord.xy).r);
    #endif

    float dist = length(playerPosition);
    float fade = sat((shadowDistance - dist) / (shadowDistance * 0.20));

    return mix(1.0, lit, fade);
}

#endif

#endif
