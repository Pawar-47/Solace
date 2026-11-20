/* Solace - lib/fragment_skybasic.glsl

The sky: a ray rebuilt per pixel from the projection inverse, the colour model from
lib/sky_model.glsl (theme, dimension override, night, dusk, stars), and - when
V_CLOUDS is 1 - a slab of procedural cloud marched through the sky, with no texture
and no extra pass.

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
vec4 cloudLayer(vec3 directionWorld) {
    vec3 d = normalize(directionWorld);
    float aboveClouds = CLOUD_HEIGHT - cameraPosition.y;
    if (d.y < 0.03 || aboveClouds <= 0.0) return vec4(0.0);

    float travel = aboveClouds / d.y;
    vec3 entry = vec3(cameraPosition.x, CLOUD_HEIGHT, cameraPosition.z) + d * travel;
    float stepLength = CLOUD_THICKNESS / float(CLOUD_STEPS);

    float density = 0.0;
    for (int i = 0; i < CLOUD_STEPS; i++) {
        vec3 at = entry + vec3(0.0, float(i) * stepLength - CLOUD_THICKNESS * 0.35, 0.0);
        vec2 drift = at.xz * 0.011 + vec2(frameTimeCounter * 0.0035, frameTimeCounter * 0.0022);
        float n = solFbm(drift + at.y * 0.0016);
        density += smoothstep(CLOUD_COVERAGE, CLOUD_COVERAGE + 0.20, n);
    }
    density /= float(CLOUD_STEPS);
    if (density < 0.002) return vec4(0.0);

    vec3 sunDir = mat3(gbufferModelViewInverse) * normalize(sunPosition);
    float lit = sat(dot(d, sunDir) * 0.5 + 0.5);
    vec3 cloudColour = mix(ambientColour() * 1.15, sunColour() * 1.25, lit * 0.80);
    cloudColour *= 0.65 + 0.55 * (1.0 - density);

    float fogAmount = 1.0 - exp(-travel * (1.1 * FOG_DENSITY) / max(far, 96.0));
    cloudColour = mix(cloudColour, fogColour(), sat(fogAmount));

    return vec4(cloudColour, sat(density * 1.6) * 0.92);
}
#endif

void main() {
    vec3 directionWorld = mat3(gbufferModelViewInverse) * normalize(skyViewRay());
    vec3 colour = skyColour(directionWorld);

    #if V_CLOUDS == 1
        vec4 cloud = cloudLayer(directionWorld);
        colour = mix(colour, cloud.rgb, cloud.a);
    #endif

    #if DITHER == 1
        colour += solDither(gl_FragCoord.xy) * (1.0 / 255.0);
    #endif

    gl_FragData[0] = vec4(colour, 1.0);
}

#endif
