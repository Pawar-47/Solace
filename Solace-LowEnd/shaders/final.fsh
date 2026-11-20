/* Solace - final.fsh

The last pass, and the one that knows where the picture currently lives:

  the geometry wrote colortex0. If the godray/exposure pass ran it moved the
  scene to colortex1. If the antialiasing/motion-blur pass ran it moved it back
  to colortex0. SCENE below is whichever of the two is current, decided by the
  same options that switched those passes on, so nothing is ever read from a
  buffer another pass is writing in the same frame.

Then, in order: depth of field, chromatic aberration, unsharp mask, ambient
occlusion, bloom, exposure (fixed, or the value the exposure pass left in
colortex6), tone curve, colour-blindness aid, saturation, contrast, dither.

Every effect compiles out when its option is 0, so the cheap configuration pays
one texture fetch for this whole pass.
*/

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/ssao.glsl"

#if AA_TYPE > 0 || MOTION_BLUR == 1
    #define SCENE colortex0
#elif VOL_LIGHT == 1 || AUTO_EXPOSURE == 1
    #define SCENE colortex1
#else
    #define SCENE colortex0
#endif

uniform sampler2D SCENE;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;

varying vec2 texcoord;

/* My own tone curve. Monotonic, 1.0 in gives about 0.73 out and 2.0 gives about
   0.93, so highlights roll off instead of clipping. */
vec3 toneCurve(vec3 x) {
    x = max(x, vec3(0.0));
    return (x * (2.0 + x)) / (x * (x + 1.5) + 1.6);
}

/* Colour-blindness aid: pull the picture towards the channels a red-weak,
   green-weak or blue-weak eye still separates, keeping the brightness. It is an
   aid, not a simulation of any particular deficiency. */
vec3 colourBlindAid(vec3 c) {
    float grey = luma(c);
    #if COLOR_BLIND_MODE == 1
        return mix(c, vec3(grey * 1.06, grey, grey * 0.90), 0.75);
    #elif COLOR_BLIND_MODE == 2
        return mix(c, vec3(grey * 0.95, grey * 1.03, grey * 0.88), 0.75);
    #elif COLOR_BLIND_MODE == 3
        return mix(c, vec3(grey * 0.92, grey * 1.05, grey), 0.75);
    #else
        return c;
    #endif
}

void main() {
    vec2 uv = texcoord;
    vec2 pixel = vec2(1.0 / viewWidth, 1.0 / viewHeight);

    vec3 colour;

    #if CHROMA_ABER == 1
        vec2 toEdge = uv - 0.5;
        vec2 split = toEdge * dot(toEdge, toEdge) * (CHROMA_STRENGTH * 0.06);
        colour.r = texture2D(SCENE, uv - split).r;
        colour.g = texture2D(SCENE, uv).g;
        colour.b = texture2D(SCENE, uv + split).b;
    #else
        colour = texture2D(SCENE, uv).rgb;
    #endif

    #if DOF == 1
        float centreDepth2 = texture2D(depthtex0, vec2(0.5, 0.5)).r;
        float hereDepth2 = texture2D(depthtex0, uv).r;
        float circle2 = sat(abs(hereDepth2 - centreDepth2) * DOF_STRENGTH * 90.0);
        if (circle2 > 0.004 && hereDepth2 < 0.99999) {
            vec3 ring = colour;
            for (int i = 1; i <= DOF_SAMPLES; i++) {
                float angle = float(i) * (6.28318530718 / float(DOF_SAMPLES));
                vec2 offset = vec2(cos(angle), sin(angle)) * (circle2 * 0.014);
                ring += texture2D(SCENE, clamp(uv + offset, vec2(0.0), vec2(1.0))).rgb;
            }
            colour = ring / float(DOF_SAMPLES + 1);
        }
    #endif

    #if IMAGE_SHARPENING == 1
        vec3 neighbours = texture2D(SCENE, uv + vec2(pixel.x, 0.0)).rgb
                        + texture2D(SCENE, uv - vec2(pixel.x, 0.0)).rgb
                        + texture2D(SCENE, uv + vec2(0.0, pixel.y)).rgb
                        + texture2D(SCENE, uv - vec2(0.0, pixel.y)).rgb;
        neighbours *= 0.25;
        colour += (colour - neighbours) * SHARPEN;
    #endif

    #if AO == 1
        colour *= screenSpaceAO(uv);
    #endif

    #if BLOOM == 1
        vec2 ring2 = vec2(BLOOM_RADIUS / viewWidth, BLOOM_RADIUS / viewHeight) * 3.0;
        vec3 threshold = vec3(0.62);
        vec3 glow = vec3(0.0);
        glow += max(texture2D(SCENE, uv + vec2( 1.0,  0.0) * ring2).rgb - threshold, vec3(0.0));
        glow += max(texture2D(SCENE, uv + vec2(-1.0,  0.0) * ring2).rgb - threshold, vec3(0.0));
        glow += max(texture2D(SCENE, uv + vec2( 0.0,  1.0) * ring2).rgb - threshold, vec3(0.0));
        glow += max(texture2D(SCENE, uv + vec2( 0.0, -1.0) * ring2).rgb - threshold, vec3(0.0));
        glow += max(texture2D(SCENE, uv + vec2( 0.7,  0.7) * ring2).rgb - threshold, vec3(0.0));
        glow += max(texture2D(SCENE, uv + vec2(-0.7,  0.7) * ring2).rgb - threshold, vec3(0.0));
        glow += max(texture2D(SCENE, uv + vec2( 0.7, -0.7) * ring2).rgb - threshold, vec3(0.0));
        glow += max(texture2D(SCENE, uv + vec2(-0.7, -0.7) * ring2).rgb - threshold, vec3(0.0));
        colour += glow * (BLOOM_STRENGTH * 0.125);
    #endif

    #if AUTO_EXPOSURE == 1
        colour *= texture2D(colortex6, vec2(0.5, 0.5)).r;
    #else
        colour *= EXPOSURE;
    #endif

    #if TONEMAP == 1
        colour = toneCurve(colour);
    #elif TONEMAP == 2
        colour = colour / (1.0 + colour);
    #else
        colour = sat(colour);
    #endif

    #if COLOR_BLINDNESS == 1
        colour = colourBlindAid(colour);
    #endif

    float grey = luma(colour);
    colour = mix(vec3(grey), colour, SATURATION);

    colour = (colour - 0.5) * CONTRAST + 0.5;
    colour = sat(colour);

    #if DITHER == 1
        colour += solDither(gl_FragCoord.xy) * (1.0 / 255.0);
    #endif

    gl_FragData[0] = vec4(colour, 1.0);
}
