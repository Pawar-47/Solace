/* Solace - lib/fragment_water.glsl

The water surface: waves from two moving noise layers tilting the geometry normal,
the surface lit like any other block, the sky reflected by a fresnel curve, a sun or
moon highlight, fog, and two optional extras that both read the copy of the scene
the deferred pass leaves in gaux1:

  REFRACTION  the scene behind the surface is bent by the normal and darkened by the
              distance the light travels through water.
  WATER_SSR   the reflected ray is marched through that same copy, so water reflects
              the world and not only the sky; the sky remains the fallback when the
              march finds nothing.

WATER_TEXTURE and VANILLA_WATER choose where the base colour comes from.
*/

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/io_geometry.glsl"
#include "/lib/sky_model.glsl"

uniform sampler2D gcolor;
uniform sampler2D depthtex0;

#if REFRACTION == 1 || WATER_SSR == 1
uniform sampler2D gaux1;
#endif

void main() {
    vec4 albedo = texture2D(gcolor, texcoord) * tint;
    if (albedo.a < 0.05) discard;

    vec3 normal = normalize(normalView);

    #if WATER_WAVES == 1
        vec2 base = worldSpacePos.xz * (0.42 * WAVE_SCALE);
        float t = frameTimeCounter * WAVE_SPEED;
        vec2 p1 = base + vec2(t * 0.85, t * 0.55);
        vec2 p2 = base * 2.10 - vec2(t * 0.65, t * 0.95);

        float e = 0.08;
        float a0 = solFbm(p1);
        float ax = solFbm(p1 + vec2(e, 0.0));
        float az = solFbm(p1 + vec2(0.0, e));
        float b0 = solFbm3(p2);
        float bx = solFbm3(p2 + vec2(e, 0.0));
        float bz = solFbm3(p2 + vec2(0.0, e));

        vec2 slope = vec2(ax - a0, az - a0) * 4.0
                   + vec2(bx - b0, bz - b0) * 2.0;

        vec3 worldNormal = mat3(gbufferModelViewInverse) * normal;
        worldNormal = normalize(worldNormal + vec3(slope.x, 0.0, slope.y) * 0.45);
        normal = normalize(mat3(gbufferModelView) * worldNormal);
    #endif

    vec3 waterBase;
    #if WATER_TEXTURE == 1
        waterBase = albedo.rgb * tint.rgb;
    #else
        waterBase = mix(vec3(0.16, 0.34, 0.42), tint.rgb, 0.55);
    #endif
    #if VANILLA_WATER == 1
        waterBase = tint.rgb;
    #endif

    vec3 toEye = normalize(-viewSpacePos);
    float skyLight = lmcoord.y;
    float blockLight = lmcoord.x;
    float viewDist = length(viewSpacePos);

    vec3 light = ambientColour() * (skyLight * skyLight)
               + blockLightColour() * (blockLight * blockLight) * BLOCK_LIGHT;

    vec3 colour = waterBase * light;

    float fresnel = pow(1.0 - sat(dot(normal, toEye)), 5.0);
    float reflection = 0.0;

    #if WATER_REFLECTION == 1
        vec3 reflected = mat3(gbufferModelViewInverse) * reflect(-toEye, normal);
        vec3 skyReflection = skyColour(reflected);
        reflection = sat(0.08 + fresnel * 0.92);
        colour = mix(colour, skyReflection * 0.85, reflection);
    #endif

    #if WATER_SSR == 1
        vec3 reflectedWorld = mat3(gbufferModelViewInverse) * reflect(-toEye, normal);
        vec3 reflectedView = mat3(gbufferModelView) * reflectedWorld;
        bool found = false;
        vec3 foundColour = vec3(0.0);

        for (int i = 1; i <= SSR_STEPS; i++) {
            vec3 probe = viewSpacePos + reflectedView * (0.35 * float(i));
            vec4 clip = gbufferProjection * vec4(probe, 1.0);
            if (clip.w <= 0.0001) break;

            vec2 probeUV = clip.xy / clip.w * 0.5 + 0.5;
            if (probeUV.x < 0.0 || probeUV.x > 1.0 || probeUV.y < 0.0 || probeUV.y > 1.0) break;

            float sceneDepth = texture2D(depthtex0, probeUV).r;
            if (sceneDepth >= 0.99999) continue;

            vec4 sceneView = gbufferProjectionInverse
                           * vec4(probeUV * 2.0 - 1.0, sceneDepth * 2.0 - 1.0, 1.0);
            float sceneZ = sceneView.z / sceneView.w;

            if (probe.z < sceneZ) {
                found = true;
                foundColour = texture2D(gaux1, probeUV).rgb;
                break;
            }
        }

        if (found) {
            float strength = sat(0.15 + fresnel * 0.95);
            colour = mix(colour, foundColour, strength * 0.85);
            reflection = max(reflection, strength * 0.85);
        }
    #endif

    #if WATER_GLINT == 1
        float sunGlint = pow(sat(dot(normal, normalize(sunPosition))), 300.0);
        float moonGlint = pow(sat(dot(normal, normalize(moonPosition))), 300.0);
        colour += sunColour() * sunGlint * skyLight * 2.2;
        colour += moonColour() * moonGlint * skyLight * 2.0;
    #endif

    float alpha = sat(WATER_OPACITY * 0.80 + fresnel * 0.55 + reflection * 0.25);

    #if REFRACTION == 1
        vec2 bent = clamp(texcoord + normal.xy * 0.035, vec2(0.002), vec2(0.998));
        vec3 behind = texture2D(gaux1, bent).rgb;
        behind *= exp(-min(viewDist, 64.0) * WATER_ABSORPTION * 0.60);
        colour = mix(behind, colour, alpha);
        alpha = 1.0;
    #endif

    vec3 fogTint = fogColour();
    float fogAmount = 1.0 - exp(-viewDist * (2.2 * FOG_DENSITY) / max(far, 32.0));

    if (isEyeInWater == 1) {
        fogTint = vec3(0.050, 0.180, 0.240);
        fogAmount = 1.0 - exp(-viewDist * 0.09);
    }

    colour = mix(colour, fogTint, sat(fogAmount));

    gl_FragData[0] = vec4(colour, alpha);
}
