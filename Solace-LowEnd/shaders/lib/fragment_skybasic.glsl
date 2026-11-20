/* Solace - lib/fragment_skybasic.glsl

The sky: a ray rebuilt per pixel from the projection inverse, the colour model from
lib/sky_model.glsl (theme, dimension override, night, dusk, stars), the underwater
tint when the camera is submerged, and - when V_CLOUDS is 1 - a slab of procedural
cloud marched through the sky, with no texture and no extra pass.

Kept in a library so the dimension folders can compile it with their own palette
without a second copy of any of it.
*/

#ifndef SOLACE_SKYBASIC
#define SOLACE_SKYBASIC

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/sky_model.glsl"
#include "/lib/pack_textures.glsl"

/* DRAWBUFFERS:0 */

varying vec2 texcoord;

/* The sky ray, interpolated from the vertex stage: one inverse projection per vertex
   instead of one per pixel. The map from screen position to ray is affine, so the
   interpolation reproduces it exactly and the fragment stage only normalises it. */
varying vec3 skyRay;

#if V_CLOUDS == 1
vec4 cloudLayer(vec3 directionWorld, float day, float dusk, vec3 sunColIn) {
    vec3 d = normalize(directionWorld);
    float aboveClouds = CLOUD_HEIGHT - cameraPosition.y;
    if (d.y < 0.02 || aboveClouds <= 0.0) return vec4(0.0);

    float travel = aboveClouds / d.y;
    vec3 entry = vec3(cameraPosition.x, CLOUD_HEIGHT, cameraPosition.z) + d * travel;
    float stepLength = CLOUD_THICKNESS / float(CLOUD_STEPS);

    /* The march starts at a dithered point inside the first step, so the four or
       six samples spread out instead of all landing on the same lattice. */
    float offset = solDitherShifted(gl_FragCoord.xy,
                                    float(frameCounter % 64) * 0.015625);

    float density = 0.0;
    for (int i = 0; i < CLOUD_STEPS; i++) {
        vec3 at = entry + vec3(0.0,
                               (float(i) + offset) * stepLength - CLOUD_THICKNESS * 0.35,
                               0.0);
        vec2 drift = at.xz * 0.011 + vec2(frameTimeCounter * 0.0035, frameTimeCounter * 0.0022);

        #if PACK_TEXTURES == 1
            /* One fetch from textures/clouds.png instead of two noise octaves, and the
               field is the one the generator made from the same kind of noise. */
            float n = texture2D(clouds,
                                at.xz * 0.0004
                                + vec2(frameTimeCounter * 0.0009,
                                       frameTimeCounter * 0.0006)).r;
        #else
            /* One octave per step, not two. With four steps in the march the second
               octave was being averaged away as noise, and it doubled the cost of
               every sky pixel while clouds are on. */
            float n = solNoise(drift + at.y * 0.0016);
        #endif

        density += smoothstep(CLOUD_COVERAGE, CLOUD_COVERAGE + 0.20, n);

        /* Early out: a saturated column needs no more samples. */
        if (density > float(CLOUD_STEPS) * 0.95) break;
    }
    density /= float(CLOUD_STEPS);
    if (density < 0.002) return vec4(0.0);

    vec3 cloudColour;

    #if SOLACE_DIM_END == 1
        /* The End has no sun to light its clouds from: they are a bright violet
           haze, lighter where they are thin, which is what an End sky looks like
           from inside. */
        cloudColour = mix(horizonColour(day, dusk) * 2.20, vec3(0.98, 0.94, 1.00) * 1.60,
                          0.35);
        cloudColour = mix(cloudColour, cloudColour * 2.00, 1.0 - density);
        cloudColour = mix(cloudColour, vec3(1.0), 0.04);
    #else
        vec3 sunDir = mat3(gbufferModelViewInverse) * normalize(sunPosition);

        /* Rain flattens the lighting: no sunlit tops, no shadowed bases. */
        float lit = sat(dot(d, sunDir) * 0.5 + 0.5);
        lit = mix(lit, 0.5, rainStrength * 0.6);

        cloudColour = mix(ambientColour(day, dusk) * 1.15, sunColIn * 1.25, lit * 0.80);

        /* Silver lining: thin cloud in front of the sun scatters, thick cloud does
           not, which is what keeps the edges of a deck bright and its body grey.
           The 8th power is three squarings, cheaper than the two special functions
           pow() is made of. */
        float towardsSun = sat(dot(d, sunDir));
        float towardsSun2 = towardsSun * towardsSun;
        float towardsSun4 = towardsSun2 * towardsSun2;
        float lining = towardsSun4 * towardsSun4 * (1.0 - density);
        cloudColour += sunColIn * lining * (1.0 - rainStrength) * 1.60;

        cloudColour *= 0.62 + 0.55 * (1.0 - density);
    #endif

    float fogAmount = 1.0 - exp(-travel * (1.1 * FOG_DENSITY) / max(far, 96.0));
    cloudColour = mix(cloudColour, fogColour(day, dusk), sat(fogAmount));

    /* A deck fades out towards the horizon rather than ending on a hard line. */
    float horizon = sat((d.y - 0.02) * 6.0);

    return vec4(cloudColour, sat(density * 1.6) * 0.92 * horizon);
}
#endif

void main() {
    vec3 directionWorld = mat3(gbufferModelViewInverse) * normalize(skyRay);
    float sunUp = sunHeight();
    float day = dayFrom(sunUp);
    float dusk = duskFrom(sunUp);
    vec3 sunCol = sunColourAt(sat(sunUp));
    vec3 colour = skyColour(directionWorld, day, dusk, sunCol);

    #if V_CLOUDS == 1
        vec4 cloud = cloudLayer(directionWorld, day, dusk, sunCol);
        colour = mix(colour, cloud.rgb, cloud.a);
    #endif

    /* Underwater the dome is not the sky but the water surface seen from below: it
       takes the water's colour and fades as the eye looks up, which is what makes the
       surface overhead read as a ceiling. */
    if (isEyeInWater == 1) {
        vec3 belowWater = vec3(0.030, 0.150, 0.210) * (0.35 + 0.65 * day);
        float up = sat(directionWorld.y - 0.10);
        colour = mix(belowWater, colour, up + rainStrength * (1.0 - up));
    }

    #if DITHER == 1
        colour += (solDitherBlue(gl_FragCoord.xy) - 0.5) * (1.0 / 255.0);
    #endif

    gl_FragData[0] = vec4(colour, 1.0);
}

#endif
