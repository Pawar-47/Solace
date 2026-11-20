/* Solace - composite2.fsh

Temporal antialiasing, FXAA and motion blur, in one pass, because all three need
the picture as a whole.

  reprojection - each pixel's view position is rebuilt from depth, moved back to
                 where it was last frame with the previous camera matrix, and
                 projected with the previous projection. History is sampled there,
                 clamped to the neighbourhood of the current pixel so a moving
                 object cannot smear its colour across the screen.
  motion blur  - the same previous position, walked in MOTION_BLUR_SAMPLES steps.
  FXAA         - a luma-compared edge blend in the current frame, for AA_TYPE 2
                 and 3, and for whatever the temporal part leaves behind.

Reads the shaded scene from colortex1, writes the result to colortex0 and the new
history to colortex3, so nothing is read from the buffer being written.
*/

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"

/* DRAWBUFFERS:03 */

const int colortex3Format = RGBA16F;

uniform sampler2D colortex1;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;

varying vec2 texcoord;

vec4 viewPosition(vec2 uv, float depth) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * clip;
    return view / view.w;
}

/* Where this pixel was on the previous frame, or a negative coordinate when it
   was off screen (there is nothing to blend with then). */
vec2 previousUV(vec2 uv, float depth) {
    if (depth >= 1.0) return vec2(-1.0);

    vec3 playerPos = (gbufferModelViewInverse * viewPosition(uv, depth)).xyz;
    vec3 previousPlayerPos = playerPos + cameraPosition - previousCameraPosition;
    vec4 previousClip = gbufferPreviousProjection * (gbufferPreviousModelView * vec4(previousPlayerPos, 1.0));
    if (previousClip.w <= 0.0001) return vec2(-1.0);

    return (previousClip.xy / previousClip.w) * 0.5 + 0.5;
}

vec3 neighbourhoodClamp(vec3 history, vec2 uv) {
    vec2 texel = vec2(1.0 / viewWidth, 1.0 / viewHeight);
    vec3 low = history;
    vec3 high = history;
    vec3 a = texture2D(colortex1, uv + vec2( texel.x, 0.0)).rgb;
    vec3 b = texture2D(colortex1, uv + vec2(-texel.x, 0.0)).rgb;
    vec3 c = texture2D(colortex1, uv + vec2(0.0,  texel.y)).rgb;
    vec3 d = texture2D(colortex1, uv + vec2(0.0, -texel.y)).rgb;
    low = min(low, min(min(a, b), min(c, d)));
    high = max(high, max(max(a, b), max(c, d)));
    return clamp(history, low, high);
}

vec3 applyFxaa(vec2 uv) {
    vec2 texel = vec2(1.0 / viewWidth, 1.0 / viewHeight);
    vec3 centre = texture2D(colortex1, uv).rgb;
    float centreLuma = luma(centre);

    float lumaA = luma(texture2D(colortex1, uv + vec2( texel.x, 0.0)).rgb);
    float lumaB = luma(texture2D(colortex1, uv + vec2(-texel.x, 0.0)).rgb);
    float lumaC = luma(texture2D(colortex1, uv + vec2(0.0,  texel.y)).rgb);
    float lumaD = luma(texture2D(colortex1, uv + vec2(0.0, -texel.y)).rgb);

    float low = min(centreLuma, min(min(lumaA, lumaB), min(lumaC, lumaD)));
    float high = max(centreLuma, max(max(lumaA, lumaB), max(lumaC, lumaD)));
    float contrast = high - low;
    if (contrast < FXAA_EDGE) return centre;

    vec2 direction = vec2(-(lumaA - lumaB), lumaC - lumaD);
    float length_ = abs(direction.x) + abs(direction.y);
    if (length_ < 0.0001) return centre;
    direction = normalize(direction) * texel * 1.4;

    vec3 blended = texture2D(colortex1, uv + direction).rgb
                 + texture2D(colortex1, uv - direction).rgb;
    blended *= 0.5;

    return mix(centre, blended, sat(contrast * 2.5));
}

void main() {
    vec2 uv = texcoord;
    float depth = texture2D(depthtex0, uv).r;
    vec3 current = texture2D(colortex1, uv).rgb;
    vec2 previous = previousUV(uv, depth);

    vec3 result = current;

    #if MOTION_BLUR == 1
        if (previous.x >= 0.0 && previous.y >= 0.0 && depth < 1.0) {
            vec2 path = (previous - uv) * MOTION_BLUR_STRENGTH;
            vec3 blurred = current;
            for (int i = 1; i <= MOTION_BLUR_SAMPLES; i++) {
                vec2 probe = uv + path * (float(i) / float(MOTION_BLUR_SAMPLES));
                blurred += texture2D(colortex1, clamp(probe, vec2(0.0), vec2(1.0))).rgb;
            }
            result = blurred / float(MOTION_BLUR_SAMPLES + 1);
        }
    #endif

    #if AA_TYPE == 2 || AA_TYPE == 3
        result = applyFxaa(uv);
    #endif

    #if AA_TYPE == 1 || AA_TYPE == 2
        if (previous.x >= 0.0 && previous.y >= 0.0) {
            vec3 history = neighbourhoodClamp(texture2D(colortex3, previous).rgb, uv);
            result = mix(result, history, TAA_WEIGHT);
        }
    #endif

    gl_FragData[0] = vec4(result, 1.0);
    gl_FragData[1] = vec4(result, 1.0);
}
