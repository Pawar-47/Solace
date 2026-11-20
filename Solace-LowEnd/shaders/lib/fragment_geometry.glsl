/* Solace - lib/fragment_geometry.glsl

Lighting for solid, textured geometry, following the reference's model step by step:

  1. the vanilla lightmap is de-biased, so the sky channel really runs 0 to 1 and a
     cave can reach zero (the reference: max(y - 0.065) * 1.0695);
  2. block light grows faster than linearly - x^1.5 + (1.17x)^6 - the reference's
     candle curve, which is what makes a torch pool read correctly;
  3. the direct term is the face angle to the sun by day and to the moon by night,
     and with no shadow map it is crushed by sky exposure to the tenth power, so
     sunlight cannot leak into caves or under a tree;
  4. leaves take a softened direct term, because a leaf block is not an opaque wall;
  5. ambient light has a floor, so a cave is dark but not black;
  6. then the damage tint, emissive blocks, the end portal, night vision, blindness,
     the lava and powder-snow views, and fog - which is only *mixed* here, because
     the amount came from the vertex stage.
*/

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/io_geometry.glsl"
#include "/lib/sky_model.glsl"
#include "/lib/shadowmap.glsl"

uniform sampler2D gcolor;

void main() {
    vec4 albedo = texture2D(gcolor, texcoord) * tint;
    if (albedo.a < 0.10) discard;

    #if defined SOLACE_WEATHER
        albedo.a *= 0.5;
    #endif

    #if ENTITY_TINT == 1
        albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
    #endif

    /* One sin() for the whole pixel, passed down to every colour function. */
    float day = dayFactor();
    float dusk = duskFactor();

    /* 1. De-biased lightmap. */
    float skyLight = sat(max(lmcoord.y - 0.065, 0.0) * 1.06951871657754);
    float rawBlock = lmcoord.x;

    #if UNDERWATER_FOG == 1
        if (isEyeInWater == 1) {
            skyLight = skyLight * 0.95 + 0.05;
        }
    #endif

    /* 2. Candle curve. */
    float blockCurve = rawBlock * sqrt(rawBlock) + solPow6(rawBlock * 1.17);
    vec3 candle = blockLightColour() * blockCurve * BLOCK_LIGHT;

    /* 3. Direct term: the sun by day, the moon by night. */
    vec3 astroDir = normalize(mix(moonPosition, sunPosition, day));
    float facing = dot(normalize(normalView), astroDir);

    /* 4. Leaves are not walls. */
    if (blockId == SOLACE_WAVE_LEAVES) {
        facing = (sat(facing) * 0.5 + 0.5) * 0.75;
    } else {
        facing = sat(facing);
    }

    #if SHADOWS == 1
        vec3 playerPosition = (gbufferModelViewInverse * vec4(viewSpacePos, 1.0)).xyz;
        facing *= shadowFactor(playerPosition, facing);
    #else
        /* No shadow map: sky exposure to the tenth power is the stand-in, as in
           the reference's fake shadows. Built from squares, no pow(). */
        float sky2 = skyLight * skyLight;
        float sky4 = sky2 * sky2;
        float sky8 = sky4 * sky4;
        facing *= (sky8 * sky2);
    #endif

    /* 5. Ambient: palette colour with a floor, so caves keep some light. */
    float ambientFloor = 0.045;
    vec3 ambient = ambientColour(day, dusk) * (ambientFloor + (1.0 - ambientFloor) * (skyLight * skyLight));

    vec3 light = ambient + candle;

    #if SUN_SHADING == 1
        vec3 astroColour = mix(moonColour() * 2.5, sunColour(), day);
        light += astroColour * facing * 0.85 * (1.0 - rainStrength * 0.75);
    #endif

    #if EYE_LIGHT == 1
        light += vec3(0.35, 0.45, 0.65) * nightVision * 0.45;
    #endif

    #if HAND_LIGHT == 1
        if (heldBlockLightValue > 0.5) {
            float nearness = sat(1.0 - length(viewSpacePos) / 6.0);
            light += blockLightColour() * nearness * (heldBlockLightValue / 15.0) * 0.80;
        }
    #endif

    vec3 colour = albedo.rgb * light;

    #if MATERIAL_GLOSS == 1
        float gloss = 0.0;
        if (blockId == SOLACE_GLOSS_METAL) {
            gloss = 0.85;
        } else if (blockId == SOLACE_GLOSS_POLISHED) {
            gloss = 0.45;
        } else if (blockId == SOLACE_GLOSS_FABRIC) {
            gloss = 0.16;
        }

        if (gloss > 0.0) {
            vec3 halfway = normalize(astroDir + normalize(-viewSpacePos));
            float highlight = pow(sat(dot(normalize(normalView), halfway)), 44.0);
            /* Rain kills the highlight, as it does in the reference's
               `material_gloss_fragment.glsl`, which multiplies by 1 - rainStrength. */
            colour += mix(moonColour() * 2.5, sunColour(), day)
                    * highlight * gloss * GLOSS_STRENGTH * facing * skyLight
                    * (1.0 - rainStrength);
        }
    #endif

    #if EMISSIVE_GLOW == 1
        if (blockId == SOLACE_EMISSIVE) {
            colour = max(colour, albedo.rgb * (0.90 + 0.35 * sat(rawBlock)));
        }
    #endif

    if (blockId == SOLACE_PORTAL) {
        /* The End portal as a stack of layers, each a finer grid than the one behind
           it, with the layers that are left nearly transparent drawn first. The
           reference builds it exactly this way; what was here before was a teal
           noise swirl, which is the wrong colour for a portal and had no depth.
           Six layers, not ten, with the fade stopping the loop early: past the
           fourth layer the remaining contribution is under one 8-bit step. */
        float t = frameTimeCounter;

        vec3 violet = vec3(0.500, 0.235, 0.500);
        vec3 blue = vec3(0.176, 0.286, 0.726);
        vec3 teal = vec3(0.161, 0.396, 0.494);

        float cycle = t * 0.67;
        vec3 layerColour = mix(violet, blue, sin(cycle) * 0.5 + 0.5);
        layerColour = mix(layerColour, teal, cos(cycle * 0.7) * 0.5 + 0.5);

        vec2 flow = vec2(0.618034) * (t * 0.20);
        vec2 base = worldSpacePos.xz + worldSpacePos.y * 1.96 + flow;

        vec3 portal = vec3(0.0);
        for (int i = 0; i < 6; i++) {
            float layer = float(i) / 6.0;
            float inverse = 1.0 - layer;

            vec2 grid = base * (5.0 * (1.0 + layer * 20.0));
            grid -= cameraPosition.xz * (layer * 50.0);
            grid += flow * (inverse * 10.0);

            float n = solHash(floor(grid));
            float n5 = n * n;
            n5 = n5 * n5 * n;
            float intensity = smoothstep(0.75, 1.0, n5);

            float fade = inverse * inverse;
            fade *= fade;

            portal += layerColour * intensity * fade * 3.0;
            if (fade < 0.01) break;
        }

        colour = portal;
    }

    #if EYE_LIGHT == 1
        colour = mix(colour, colour * vec3(NV_COLOR_R, NV_COLOR_G, NV_COLOR_B),
                     nightVision * 0.60);
    #endif

    /* Blindness and the Warden's darkness, as the reference handles them in its
       final colour step. A uniform the running version lacks reads 0. */
    float darkness = max(blindness, darknessFactor * darknessLightFactor);
    if (darkness > 0.01) {
        colour = mix(colour, vec3(0.0), sat(darkness * length(viewSpacePos) * 0.24));
    }

    /* Fog: the amount came from the vertex stage, only the colour is per pixel. */
    vec3 fogTint = fogColour(day, dusk);
    #if UNDERWATER_FOG == 1
        if (isEyeInWater == 1) {
            fogTint = vec3(0.050, 0.190, 0.250) * (0.35 + 0.65 * day);
        }
    #endif
    if (isEyeInWater == 2) {
        fogTint = vec3(0.55, 0.12, 0.02);      // lava
    } else if (isEyeInWater == 3) {
        fogTint = vec3(0.80, 0.86, 0.92);      // powder snow
    }

    colour = mix(colour, fogTint, isEyeInWater > 0 ? sat(fogFactor * 1.6) : fogFactor);

    /* The reference clamps every geometry write to 50, which is what keeps a stray
       highlight out of the bloom and the AA history. */
    gl_FragData[0] = vec4(clamp(colour, vec3(0.0), vec3(50.0)), albedo.a);
}
