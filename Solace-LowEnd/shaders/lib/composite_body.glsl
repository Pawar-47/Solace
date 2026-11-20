/* Solace - lib/composite_body.glsl

Light shafts and the exposure average, in one pass because both need the finished
scene:

  light shafts - march from the pixel towards the sun's screen position and count
                 how much open sky the ray passes; the count becomes sunlight on
                 surfaces only, so the sky itself is untouched.
  exposure     - nine taps give the average brightness, that becomes a target
                 exposure, and the target is mixed into the previous frame's value
                 kept in gaux3 (colortex6), which makes the change gradual.

Writes the shaded scene to colortex1 and the exposure value to colortex6.r, so the
buffer it reads (colortex0) is never written in the same pass.
*/

#ifndef SOLACE_COMPOSITE_BODY
#define SOLACE_COMPOSITE_BODY

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/sky_model.glsl"

/* DRAWBUFFERS:16 */

const int colortex6Format = R16F;

uniform sampler2D colortex0;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;

varying vec2 texcoord;

float openSkyTowardsSun(vec2 uv) {
    vec4 sunClip = gbufferProjection * vec4(normalize(sunPosition), 0.0);
    if (sunClip.w <= 0.0001) return 0.0;

    vec2 sunUV = (sunClip.xy / sunClip.w) * 0.5 + 0.5;
    vec2 stepUV = (sunUV - uv) / float(VOL_LIGHT_SAMPLES);

    float open = 0.0;
    vec2 probe = uv;
    for (int i = 0; i < VOL_LIGHT_SAMPLES; i++) {
        probe = clamp(probe + stepUV, vec2(0.0), vec2(1.0));
        float probeDepth = texture2D(depthtex0, probe).r;
        open += step(0.99999, probeDepth);
    }
    return open / float(VOL_LIGHT_SAMPLES);
}

void main() {
    vec2 uv = texcoord;
    vec4 scene = texture2D(colortex0, uv);
    vec3 colour = scene.rgb;

    #if VOL_LIGHT == 1
        float surfaceDepth = texture2D(depthtex0, uv).r;
        if (surfaceDepth < 0.99999) {
            float shafts = openSkyTowardsSun(uv);
            vec3 sunDir = mat3(gbufferModelViewInverse) * normalize(sunPosition);
            float towardsSun = sat(sunDir.y * 2.0);
            colour += sunColour() * shafts * towardsSun * (VOL_LIGHT_STRENGTH * 0.5);
        }
    #endif

    float exposure = 1.0;
    #if AUTO_EXPOSURE == 1
        vec3 taps = vec3(0.0);
        taps += texture2D(colortex0, vec2(0.5, 0.5)).rgb;
        taps += texture2D(colortex0, vec2(0.25, 0.25)).rgb;
        taps += texture2D(colortex0, vec2(0.75, 0.25)).rgb;
        taps += texture2D(colortex0, vec2(0.25, 0.75)).rgb;
        taps += texture2D(colortex0, vec2(0.75, 0.75)).rgb;
        taps += texture2D(colortex0, vec2(0.5, 0.2)).rgb;
        taps += texture2D(colortex0, vec2(0.5, 0.8)).rgb;
        taps += texture2D(colortex0, vec2(0.2, 0.5)).rgb;
        taps += texture2D(colortex0, vec2(0.8, 0.5)).rgb;
        float average = luma(taps / 9.0);

        float target = sat(0.20 / max(average, 0.0005));
        float previous = texture2D(colortex6, vec2(0.5)).r;
        if (previous <= 0.0) previous = target;
        exposure = clamp(mix(previous, target, AUTO_EXPOSURE_SPEED), 0.40, 4.0);
    #endif

    gl_FragData[0] = vec4(colour, 1.0);
    gl_FragData[1] = vec4(exposure, 0.0, 0.0, 1.0);
}

#endif
