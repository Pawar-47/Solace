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

varying vec2 texcoord;

vec3 skyViewRay() {
    vec4 ray = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, 1.0, 1.0);
    return ray.xyz / ray.w;
}

#if V_CLOUDS == 1
vec4 cloudLayer(vec3 directionWorld, float day, float dusk) {
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
        float n = solFbm(drift + at.y * 0.0016);
        density += smoothstep(CLOUD_COVERAGE, CLOUD_COVERAGE + 0.20, n);

        /* Early out: a saturated column needs no more samples. */
        if (density > float(CLOUD_STEPS) * 0.95) break;
    }
    density /= float(CLOUD_STEPS);
    if (density < 0.002) return vec4(0.0);

    vec3 cloudColour;

    #if SOLACE_DIM_END == 1
        /* The End has no sun to light its clouds from: they are a bright violet
           haze, lighter where they are thin, which is how the reference renders its
           own End cloud layer. */
        cloudColour = mix(horizonColour(day, dusk) * 2.20, vec3(0.98, 0.94, 1.00) * 1.60,
                          0.35);
        cloudColour = mix(cloudColour, cloudColour * 2.00, 1.0 - density);
        cloudColour = mix(cloudColour, vec3(1.0), 0.04);
    #else
        vec3 sunDir = mat3(gbufferModelViewInverse) * normalize(sunPosition);

        /* Rain flattens the lighting: no sunlit tops, no shadowed bases. The
           reference damps its cloud attenuation with rainStrength the same way. */
        float lit = sat(dot(d, sunDir) * 0.5 + 0.5);
        lit = mix(lit, 0.5, rainStrength * 0.6);

        cloudColour = mix(ambientColour(day, dusk) * 1.15, sunColour() * 1.25, lit * 0.80);

        /* Silver lining: thin cloud in front of the sun scatters, thick cloud does
           not, which is what keeps the edges of a deck bright and its body grey. */
        float lining = pow(sat(dot(d, sunDir)), 8.0) * (1.0 - density);
        cloudColour += sunColour() * lining * (1.0 - rainStrength) * 1.60;

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
    vec3 directionWorld = mat3(gbufferModelViewInverse) * normalize(skyViewRay());
    float day = dayFactor();
    float dusk = duskFactor();
    vec3 colour = skyColour(directionWorld);

    #if V_CLOUDS == 1
        vec4 cloud = cloudLayer(directionWorld, day, dusk);
        colour = mix(colour, cloud.rgb, cloud.a);
    #endif

    /* Underwater the dome is not the sky but the water surface seen from below:
       the reference tints it with its water colour and fades it as the eye looks
       up, which is what makes the surface overhead read as a ceiling. */
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
