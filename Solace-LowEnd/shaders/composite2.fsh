/* Solace - composite2.fsh

Temporal antialiasing and motion blur, in one pass, because both need the whole
picture and the previous frame's camera.

  reprojection - each pixel's view position is rebuilt from depthtex1 (the depth
                 that includes translucent geometry, so water reprojects correctly),
                 moved back to where it was last frame
                 with the previous camera matrix, and projected with the previous
                 projection. History is sampled there and clamped to the
                 neighbourhood of the current pixel, so a moving object cannot smear
                 its colour across the screen.
  motion blur  - the same previous position, walked in MOTION_BLUR_SAMPLES steps.

FXAA-only mode is not here: it needs no history and costs no extra pass, so it runs
in `final` instead, which needs no history.

Reads the shaded scene from colortex1, writes the result to colortex0 and the new
history to colortex3, so nothing is read from the buffer being written.
*/

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/buffers.glsl"

/* DRAWBUFFERS:03 */

uniform sampler2D colortex1;
uniform sampler2D colortex3;
uniform sampler2D depthtex1;

varying vec2 texcoord;

vec4 viewPosition(vec2 uv, float depth) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * clip;
    return view / view.w;
}

/* Where this pixel was on the previous frame, or a negative coordinate when it was
   off screen or in the sky (there is nothing to blend with then). */
vec2 previousUV(vec2 uv, float depth) {
    if (depth >= 1.0) return vec2(-1.0);

    vec3 playerPos = (gbufferModelViewInverse * viewPosition(uv, depth)).xyz;
    vec3 previousPlayerPos = playerPos + cameraPosition - previousCameraPosition;
    vec4 previousClip = gbufferPreviousProjection * (gbufferPreviousModelView * vec4(previousPlayerPos, 1.0));
    if (previousClip.w <= 0.0001) return vec2(-1.0);

    return (previousClip.xy / previousClip.w) * 0.5 + 0.5;
}

/* The history is clipped into the box the current 3x3 neighbourhood occupies when
   measured by its own mean and standard deviation. It is tighter than a plain min/max
   box: a thin edge through a flat area gets a narrow box, so an old ghost cannot
   survive beside it. The fourth component is the
   size of that box, which sets how much of the history is trusted. */
vec4 solHistoryBox(vec3 history, vec2 uv) {
    vec2 texel = vec2(1.0 / viewWidth, 1.0 / viewHeight);

    vec3 c = texture2D(colortex1, uv).rgb;
    vec3 l = texture2D(colortex1, uv - vec2(texel.x, 0.0)).rgb;
    vec3 r = texture2D(colortex1, uv + vec2(texel.x, 0.0)).rgb;
    vec3 d = texture2D(colortex1, uv - vec2(0.0, texel.y)).rgb;
    vec3 u = texture2D(colortex1, uv + vec2(0.0, texel.y)).rgb;
    vec3 dl = texture2D(colortex1, uv + vec2(-texel.x, -texel.y)).rgb;
    vec3 dr = texture2D(colortex1, uv + vec2(texel.x, -texel.y)).rgb;
    vec3 ul = texture2D(colortex1, uv + vec2(-texel.x, texel.y)).rgb;
    vec3 ur = texture2D(colortex1, uv + vec2(texel.x, texel.y)).rgb;

    vec3 sum = c + l + r + d + u + dl + dr + ul + ur;
    vec3 sumSquares = c * c + l * l + r * r + d * d + u * u
                    + dl * dl + dr * dr + ul * ul + ur * ur;

    vec3 mean = sum * (1.0 / 9.0);
    vec3 deviation = sqrt(abs(sumSquares * (1.0 / 9.0) - mean * mean));

    vec3 low = mean - deviation;
    vec3 high = mean + deviation;

    return vec4(clamp(history, low, high), length(high - low));
}

void main() {
    vec2 uv = texcoord;
    float depth = texture2D(depthtex1, uv).r;
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

    #if AA_TYPE == 1 || AA_TYPE == 2
        if (previous.x >= 0.0 && previous.y >= 0.0) {
            vec4 box = solHistoryBox(texture2D(colortex3, previous).rgb, uv);

            /* How far the history had to be moved to fit, against the size of the
               box: the busier the neighbourhood, the less of the old frame survives,
               which is what stops a fast edge from leaving a trail. */
            float moved = length(current - box.rgb);
            float ponderation = sat(moved / max(box.a, 0.0001));
            float weight = TAA_WEIGHT
                         * (1.0 - 0.34 * smoothstep(0.0, 1.0, ponderation));

            result = mix(result, box.rgb, weight);
        }
    #endif

    result = clamp(result, vec3(0.0), vec3(50.0));

    gl_FragData[0] = vec4(result, 1.0);
    gl_FragData[1] = vec4(result, 1.0);
}
